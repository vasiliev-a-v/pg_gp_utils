#!/bin/bash
# adbmt_pg_log.sh
# Сбор логов ADB из pg_log на удалённом сегменте за временной период
# Функционал:
# - параметр -gpseg (master/primary/mirror),
# - поиск по номеру сегмента имени хоста и pg_log_path,
# - сжатие csv-файлов при копировании,
# - оценка объёма скачивания,
# - --dry-run

set -euo pipefail   # чат предложил поставить такую хрень

## ------------ Глобальные переменные (по умолчанию пустые) ----------------- ##
START_STR=""
END_STR=""
ADBMT_DIR=""
gpseg_opt=""                # -1 | N | pN | mN
free_spc="10"               # free space on disk in percents
DRY_RUN="0"                 # if --dry-run is 1 - means do not copy files

# Файл с хостами кластера СУБД:
PATH_ARENADATA_CONFIGS="${PATH_ARENADATA_CONFIGS:-}"
all_hosts="${PATH_ARENADATA_CONFIGS}/arenadata_all_hosts.hosts"

# Вычисляемые параметры:
ROLE=""                     # master|primary|mirror
GPSEG=""                    # -1 для master, иначе gpseg >= 0
SEG_HOST=""                 # имя хоста на котором расположен сегмент
PG_LOG_PATH=""              # полный путь к pg_log сегмента

# Массивы и счётчики:
FILES=()
STARTS=()
ENDS=()
SELECTED=()
EST_RATIO_NUM=""
EST_RATIO_DEN=""
ESTIMATED_GZ_TOTAL=""
PLANNED_BYTES=""
TOTAL_SRC_BYTES=0
TOTAL_GZ_BYTES=0

## --------------------------- Вспомогательные ------------------------------ ##
DEBUG="${DEBUG:-0}"  # 1 = подробная отладка


## --------- Функции вывода сообщений на экран ------------------------------ ##
func_log_ts()  { date +'%F %T'; }

func_dbg() {                      # видно только с --debug
  if [[ $DEBUG == 1 ]]; then
    echo "DEBUG: $*"
  fi
}


func_prt_inf() {               # всегда видно, даже без --debug
  echo "INFO: $*"
}


func_prt_err() {
  echo "ERROR: $*"
}
## --------- Конец: Функции вывода сообщений на экран ----------------------- ##



func_print_usage() {
  cat <<EOF
Использование:
  $0 START END ADBMT_DIR -gpseg <N|pN|mN|-1> [-free-space PCT] [--dry-run]

Где:
  START/END     : YYYY-MM-DD_HH:MM (HH=00..23, MM=00..59)
  ADBMT_DIR     : локальный каталог назначения
  -gpseg        : -1 (master) | N/pN (primary) | mN (mirror), где N>=0
  -free-space   : порог доли свободного места в % (по умолчанию 10)
  --dry-run     : только расчёт и список, без сжатия и копирования
EOF
}


func_validate_datetime_strict() {  # $1="YYYY-MM-DD_HH:MM"
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}$ ]] || return 1
  local ds="${1/_/ }"
  local p
  p="$(date -d "${ds}:00" +"%Y-%m-%d_%H:%M" 2>/dev/null)" || return 1
  [[ "$p" == "$1" ]]
}


func_epoch_from_minute() {  # $1="YYYY-MM-DD_HH:MM" -> echo epoch (sec)
  date -d "${1/_/ }":00 +%s
}


func_df_avail_and_target() {  # echo "<bytes> <mount>"
  local path="$1"
  if df -B1 --output=avail,target "$path" >/dev/null 2>&1; then
     df -B1 --output=avail,target "$path" | awk 'NR==2{print $1, $2}'
  else
     df -P -B1 "$path" | awk 'NR==2{print $4, $6}'
  fi
}


func_get_arguments() {  # writes into variables argues from CLI
  if (( $# < 4 )); then func_print_usage; exit 1; fi

  START_STR="$1"; END_STR="$2"; ADBMT_DIR="$3"; shift 3

  while (( $# )); do
    case "$1" in
      -gpseg|--gpseg)           shift; gpseg_opt="${1:-}";;
      -free-space|--free-space) shift; free_spc="${1:-}";;
      -all-hosts|--all-hosts)   shift; all_hosts="${1:-}";;
      -dry-run|--dry-run)       DRY_RUN="1";;
      -h|--help)                func_print_usage; exit 0;;
      -debug|--debug)           DEBUG="1";;
      *) func_prt_err "Unknown option: $1"; func_print_usage; exit 1;;
    esac
    shift || true
  done

  func_check_args
}


func_check_args() {  # проверить входные аргументы -------------------------- ##
  if [[ ! -n "$gpseg_opt" ]]; then
    func_prt_err "Option -gpseg is necessary"
    exit 1
  fi
  if [[ ! "$free_spc" =~ ^([0-9]+)(\.[0-9]+)?$ ]]; then
    func_prt_err "-free-space must be numeric"
    exit 1
  fi
  if ! func_validate_datetime_strict "$START_STR"; then
    func_prt_err "Incorrect start: $START_STR"
    exit 1
  fi
  if ! func_validate_datetime_strict "$END_STR"; then
    func_prt_err "Incorrect end: $END_STR"
    exit 1
  fi
  if [[ ! -r "$all_hosts" ]]; then
    func_prt_err "DBMS cluster hosts file not found: $all_hosts"
    exit 1
  fi
}


func_parse_gpseg() {  ## Разбор -gpseg на ROLE и номер сегмента ------------- ##
  local s="$gpseg_opt"

  if [[ "$s" =~ ^-?[0-9]+$ ]]; then
    if [[ "$s" == "-1" ]]; then
      ROLE="master"
    else
      ROLE="primary"
    fi
    GPSEG="$s"
  elif [[ "$s" =~ ^[Pp]([0-9]+)$ ]]; then
    ROLE="primary"
    GPSEG="${BASH_REMATCH[1]}"
  elif [[ "$s" =~ ^[Mm]([0-9]+)$ ]]; then
    ROLE="mirror"
    GPSEG="${BASH_REMATCH[1]}"
  else
    func_prt_err "Incorrect -gpseg: $s (expected -1 | N | pN | mN)"
    exit 1
  fi

  if [[ "$ROLE" != "master" ]]; then
    [[ "$GPSEG" =~ ^[0-9]+$ ]] || \
      { func_prt_err "gpseg must be >=0"; exit 1; }
  else
    [[ "$GPSEG" == "-1" ]] || \
    { func_prt_err "For master-node use options -gpseg -1"; exit 1; }
  fi
}


func_debug_remote_probe() {  # быстрая проверка удалённо
  ((DEBUG == 1)) || return 0
  func_dbg "Check ls/stat on ${SEG_HOST}:${PG_LOG_PATH}"
  ssh "$SEG_HOST" "set -e; printf 'REMOTE whoami: '; whoami; \
     printf 'REMOTE shell : '; echo \"\$SHELL\"; \
     printf 'REMOTE find : '; command -v find || true; \
     printf 'REMOTE dir  : '; ls -ld -- '""$PG_LOG_PATH""' || true; \
     printf 'CSV.gz count: '; find '""$PG_LOG_PATH""' -maxdepth 1 -type f -name 'gpdb-*.csv.gz' | wc -l; \
     printf 'CSV    count: '; find '""$PG_LOG_PATH""' -maxdepth 1 -type f -name 'gpdb-*.csv'    | wc -l; \
     printf 'CSV.gz head :\n'; find '""$PG_LOG_PATH""' -maxdepth 1 -type f -name 'gpdb-*.csv.gz' -printf '%f\n' | head -5 | sed -n '1,5p'; \
     true"
}


func_resolve_seg_host_and_path() {  ## Определение SEG_HOST и PG_LOG_PATH --- ##
  # ищем путь вида */<role>/gpseg<GPSEG>/pg_log
  local cmd="find / -xdev \( -path /proc -o -path /sys -o -path /run -o -path /dev \) -prune -o -regextype posix-extended -regex '.*/(${ROLE})/gpseg(${GPSEG})/pg_log' -print 2>/dev/null"

  # берем первую найденную строку
  local line
  line="$(gpssh -f "$all_hosts" "$cmd" 2>/dev/null | grep "/${ROLE}/gpseg${GPSEG}/pg_log" | head -n1 || true)"

  # УБИРАЕМ CR/LF и лишние табы/пробелы
  line="$(printf '%s' "$line" | tr -d '\r' )"
  line="${line//$'\t'/ }"
  line="${line%$'\n'}"

  # Формат gpssh: [host.name] /path/to/.../pg_log
  SEG_HOST="$(sed -n 's/^\[\([^]]\+\)\].*/\1/p' <<<"$line")"
  PG_LOG_PATH="$(awk '{print $2}' <<<"$line")"

  # ещё раз подчистим на всякий случай
  SEG_HOST="$(printf '%s' "$SEG_HOST" | tr -d '\r\n')"
  PG_LOG_PATH="$(printf '%s' "$PG_LOG_PATH" | tr -d '\r\n')"

  [[ -n "$SEG_HOST" && -n "$PG_LOG_PATH" ]] || { \
      func_prt_err "Не удалось распарсить seg_host/PG_LOG_PATH из gpssh"
      exit 1
    }

  func_prt_inf "Определены для скачивания:"
  func_prt_inf "Хост: host=${SEG_HOST}"
  func_prt_inf "Путь: pg_log_path=${PG_LOG_PATH}"

  if ((DEBUG == 1)); then  # показать "HEX" пути, чтобы сразу видно было хвосты
    printf '%s - DEBUG: PG_LOG_PATH HEX: ' "$(func_log_ts)"
    printf '%s' "$PG_LOG_PATH" | od -An -t x1
    # Если и тут NO_DIR - значит путь ещё грязный
    func_dbg "Проверяю доступность каталога на удалённом хосте"
    ssh "$SEG_HOST" "ls -ld -- '$PG_LOG_PATH' || echo 'NO_DIR'"
  fi
}


func_remote_scan_and_build_intervals() {  ## Сканирование файлов на удалённом хосте + интервалы - ##
  local -a files_raw=()
  local -a entries=()

  # 1) Сырой список имён (две find без скобок, сортировка на удалённой стороне)
  func_dbg "Запрашиваю список файлов по ssh ..."
  mapfile -t files_raw < <(
    ssh "$SEG_HOST" "{ \
        LC_ALL=C find '""$PG_LOG_PATH""' -maxdepth 1 -type f -name 'gpdb-*.csv'    -printf '%f\n'; \
        LC_ALL=C find '""$PG_LOG_PATH""' -maxdepth 1 -type f -name 'gpdb-*.csv.gz' -printf '%f\n'; \
      } 2>/dev/null | LC_ALL=C sort" \
    | tr -d $'\r'
  ) || true

  func_dbg "Получено строк: ${#files_raw[@]}"
  if ((DEBUG == 1)); then
    printf '%s - DEBUG: RAW[1..5]:\n  %s\n  %s\n  %s\n  %s\n  %s\n' \
      "$(func_log_ts)" "${files_raw[0]:-}" "${files_raw[1]:-}" "${files_raw[2]:-}" "${files_raw[3]:-}" "${files_raw[4]:-}"
  fi

  if ((${#files_raw[@]}==0)); then
    func_prt_inf "В $SEG_HOST:$PG_LOG_PATH нет файлов gpdb-*.csv(.gz)"
    exit 2
  fi

  # 2) Преобразуем в (epoch\tfile), сортируем по времени
  mapfile -t entries < <(
    for f in "${files_raw[@]}"; do
      f="${f%$'\r'}"; f="${f//$'\n'/}"
      ts="${f#gpdb-}"
      ts="${ts%.csv.gz}"; ts="${ts%.csv}"
      date_part="${ts%_*}"; hms="${ts#*_}"
      [[ ${#hms} -eq 6 ]] || \
        { func_dbg "Пропуск «$f» (hms='${hms}', len=${#hms})"; continue; }
      hh=${hms:0:2}; mm=${hms:2:2}; ss=${hms:4:2}
      ep="$(date -d "${date_part} ${hh}:${mm}:${ss}" +%s 2>/dev/null)" || \
        { func_dbg "date не распарсил «$f»"; continue; }
      printf "%s\t%s\n" "$ep" "$f"
    done | LC_ALL=C sort -n
  ) || true

  func_dbg "Валидных записей после парсинга: ${#entries[@]}"

  if ((${#entries[@]}==0)); then
    func_prt_inf "В $SEG_HOST:$PG_LOG_PATH нет корректных файлов (имя не распозналось)"
    exit 2
  fi

  FILES=()
  STARTS=()
  ENDS=()

  for line in "${entries[@]}"; do
    STARTS+=( "${line%%$'\t'*}" )
    FILES+=(  "${line#*$'\t'}" )
  done

  for ((i=0; i<${#FILES[@]}; i++)); do
    if (( i+1 < ${#FILES[@]} )); then
      ENDS[i]="${STARTS[i+1]}"
    else
      ENDS[i]=$(date -d '2100-01-01 00:00:00' +%s)
    fi
    func_dbg "INTVL ${FILES[i]}: $(date -d @${STARTS[i]} +'%F %T') .. $(date -d @${ENDS[i]} +'%F %T')"
  done
}


func_select_files_by_range() {  ## Отбор по интервалу ----------------------- ##
  local start_epoch end_epoch
  start_epoch="$(func_epoch_from_minute "$START_STR")"
  end_epoch=$(( $(func_epoch_from_minute "$END_STR") + 59 ))
  (( start_epoch <= end_epoch )) || \
    { func_prt_err "start > end"; exit 1; }

  SELECTED=()
  for ((i=0; i<${#FILES[@]}; i++)); do
    local si="${STARTS[i]}" ei="${ENDS[i]}"
    if (( si <= end_epoch && ei >= start_epoch )); then
      SELECTED+=( "${FILES[i]}" )
    fi
  done
  ((${#SELECTED[@]})) || \
    { func_prt_inf "Не найдено файлов, пересекающихся с интервалом [$START_STR .. $END_STR]."; exit 3; }
}


func_pick_sample_and_estimate_ratio() {  ## Оценщик степени сжатия csv.gz --- ##
  smpl_bytes=$((32 * 1024 * 1024))  # 32 MiB in bytes for sample
  EST_RATIO_NUM=""
  EST_RATIO_DEN=""
  local sample=""
  local size=0
  local osz

  for f in "${SELECTED[@]}"; do
    [[ "$f" == *.csv ]] || continue
    osz="$(ssh "$SEG_HOST" "stat -c%s -- '$PG_LOG_PATH/$f'" | tr -d '[:space:]' || true)"
    [[ "$osz" =~ ^[0-9]+$ ]] || continue
    sample="$f"; size="$osz"; break  # достаточно любого csv
  done

  if [[ -n "$sample" ]]; then
    local take="$size"; (( take > smpl_bytes )) && take="$smpl_bytes"
    local comp_sample
    comp_sample="$(ssh "$SEG_HOST" "head -c $take -- '$PG_LOG_PATH/$sample' | gzip -c | wc -c" | tr -d '[:space:]')"
    EST_RATIO_NUM="$comp_sample"; EST_RATIO_DEN="$take"
    local pct factor
    pct=$(awk -v n="$EST_RATIO_NUM" -v d="$EST_RATIO_DEN" 'BEGIN{printf "%.1f", 100*n/d}')
    factor=$(awk -v n="$EST_RATIO_NUM" -v d="$EST_RATIO_DEN" 'BEGIN{printf "%.2f", d/n}')
    func_dbg "Оценка сжатия по образцу: ${SEG_HOST}:${PG_LOG_PATH}/${sample}"
    func_dbg "Использовано выборки для оценщика: $take байт из $size"
    func_dbg "Оценочное отношение: ~${pct}% от исходного (≈${factor}x меньше)"
  else
    func_prt_inf "Оценка: среди выбранных файлов нет несжатых csv - пропускаю оценщик."
  fi
}


func_estimate_planned_bytes() { ## Оценка планируемого объёма лог-файлов ---- ##
  local est_total=0
  TOTAL_SRC_BYTES=0

  for f in "${SELECTED[@]}"; do
    local src="$PG_LOG_PATH/$f"
    local osz
    # берём размер удалённого файла
    osz="$(ssh -T "$SEG_HOST" "stat -c%s -- '$src'" 2>/dev/null | tr -d '[:space:]')"
    [[ "$osz" =~ ^[0-9]+$ ]] || osz=0

    TOTAL_SRC_BYTES=$((TOTAL_SRC_BYTES + osz))

    if [[ "$f" == *.csv.gz ]]; then
      est_total=$((est_total + osz))       # уже сжатый - берём как есть
    else
      if [[ -n "$EST_RATIO_NUM" && -n "$EST_RATIO_DEN" ]]; then
        est_total=$(( est_total + $(awk -v os="$osz" -v n="$EST_RATIO_NUM" -v d="$EST_RATIO_DEN" 'BEGIN{printf "%.0f", os*n/d}') ))
      else
        est_total=$((est_total + osz))     # нет образца - консервативно
      fi
    fi
  done

  ESTIMATED_GZ_TOTAL="$est_total"
  PLANNED_BYTES="$est_total"
}


func_check_free_space() {  ## Проверка свободного места --------------------- ##
  mkdir -p -- "$ADBMT_DIR"
  read -r avail_bytes mount_path < <(func_df_avail_and_target "$ADBMT_DIR")
  local percent_of_free
  percent_of_free=$(awk -v y="$PLANNED_BYTES" -v x="$avail_bytes" 'BEGIN{ if (x==0){print "inf"} else {printf "%.2f", 100*y/x} }')

  local exceed=0
  if [[ "$percent_of_free" == "inf" ]]; then
    exceed=1
  else
    awk -v p="$percent_of_free" -v f="$free_spc" 'BEGIN{ if (p>f) exit 0; else exit 1 }' && exceed=1 || exceed=0
  fi

  if (( exceed )); then
    echo "На разделе \"${mount_path}\" для каталога $ADBMT_DIR имеется ${avail_bytes} байт свободного места."
    echo "Необходимо скачать ${PLANNED_BYTES} байт лог-файлов."
    echo "Это ${percent_of_free}% от объёма свободного места на разделе \"${mount_path}\", что превышает установленное значение -free-space в ${free_spc} процентов."
    echo "Необходимо либо увеличить значение -free-space, либо уменьшить объем выборки логов."
    exit 10
  fi
}


func_copy_with_compression() {  ## Копирование сжатых/несжатых файлов ------- ##
  mkdir -p -- "$ADBMT_DIR"
  TOTAL_GZ_BYTES=0

  for f in "${SELECTED[@]}"; do
    local src="$PG_LOG_PATH/$f"
    local base="${f%.csv.gz}"; base="${base%.csv}"
    local dest="$ADBMT_DIR/${base}.csv.gz"

    if [[ "$f" == *.csv.gz ]]; then
      scp -q "$SEG_HOST:$src" "$dest"
    else
      ssh -q "$SEG_HOST" "gzip -c -- '$src'" > "$dest"
    fi

    local gzsz; gzsz=$(stat -c%s -- "$dest")
    TOTAL_GZ_BYTES=$((TOTAL_GZ_BYTES + gzsz))
  done
}


func_print_summary() {  ## Итоговая сводка ---------------------------------- ##
  func_prt_inf "Каталог назначения на выгрузку лог-файлов: $ADBMT_DIR"
  func_prt_inf "Число лог-файлов для копирования: ${#SELECTED[@]}"
  # func_prt_inf "Суммарный размер лог-файлов: ${TOTAL_SRC_BYTES} байт, $((TOTAL_SRC_BYTES/1024/1024)) мегабайт"  # что-то ересь какая-то, отключил как ненужную.
  func_prt_inf "Оценочный размер лог-файлов: ${ESTIMATED_GZ_TOTAL} байт, $((ESTIMATED_GZ_TOTAL/1024/1024)) мегабайт"
  if (( DRY_RUN != 1 )); then
    func_prt_inf "Фактический размер лог-файлов: ${TOTAL_GZ_BYTES} байт, $((TOTAL_GZ_BYTES/1024/1024)) мегабайт"
  else
    func_prt_inf "Опция --dry-run - сжатие и копирование не выполнялись."
  fi
  func_prt_inf "Список файлов:"
  printf '  %s\n' "${SELECTED[@]}"
}


func_main() {  ## Главная функция ------------------------------------------- ##
  func_get_arguments "$@"
  func_parse_gpseg
  func_resolve_seg_host_and_path
  func_debug_remote_probe
  func_remote_scan_and_build_intervals
  func_select_files_by_range
  func_pick_sample_and_estimate_ratio
  func_estimate_planned_bytes
  func_check_free_space

  if (( DRY_RUN != 1 )); then
    func_copy_with_compression
  fi
  func_print_summary
}


func_main "$@"  ## Точка входа ---------------------------------------------- ##
exit 0





