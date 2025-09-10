#!/bin/bash

# DESCRIPTION -------------------------------------------------------- #
# adbmt_pg_log.sh
# Collect ADB server logs from a remote host for a specified period of time

## Defining global variables ---------------------------------------- ##
# Options:
start_str=""
end_str=""
adbmt_tmp=""
gpseg_opt=""                # -1 | N | pN | mN
free_spc="10"               # free space on disk in percents
dry_run="0"                 # if --dry-run is 1 - means do not copy files

# list of host files in DBMS cluster
PATH_ARENADATA_CONFIGS="${PATH_ARENADATA_CONFIGS:-}"
all_hosts="${PATH_ARENADATA_CONFIGS}/arenadata_all_hosts.hosts"

seg_role=""                 # master|primary|mirror
seg_num=""                  # -1 for master, otherwise must be gpseg >= 0
seg_host=""                 # hostname, which segment is located
seg_path=""                 # full path to segment's pg_log

DEBUG="${DEBUG:-0}"         # value 1 is for debug

# Arrays:
FILES=()
STARTS=()
ENDS=()
SELECTED=()
# Counters:
EST_RATIO_NUM=""
EST_RATIO_DEN=""
est_gz_total=""
EST_RATIO_NUM=""
total_src_bytes=0
total_gz_bytes=0


# set -Eeuo pipefail


func_main() {  # main function: invokes another functions
  func_get_arguments "$@"
  func_parse_gpseg
  func_resolve_seg_host_and_path
  func_debug_remote_probe
  func_remote_scan_and_build_intervals
  func_select_files_by_range
  func_pick_sample_and_estimate_ratio
  func_estimate_planned_bytes
  func_check_free_space

  if (( dry_run != 1 )); then
    func_copy_with_compression
  fi
  func_print_summary
}


f_prt() {  # writes to stdout errors, debug or info messages
  case $1 in
  err ) echo "ERROR: "$2;;
  dbg ) ((DEBUG == 1)) && echo "DEBUG: "$2;;
  *   ) echo $1;;
  esac
}


func_show_help() {
  cat <<EOF
Использование:
  $0 start end adbmt_tmp -gpseg <N|pN|mN|-1> [-free-space PCT] [--dry-run]

Где:
  start/end     : YYYY-MM-DD_HH:MM (HH=00..23, MM=00..59)
  adbmt_tmp     : локальный каталог назначения
  -gpseg        : -1 (master) | N/pN (primary) | mN (mirror), где N>=0
  -free-space   : порог доли свободного места в % (по умолчанию 10)
  --dry-run     : только расчёт и список - без сжатия и копирования
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
  if (( $# < 4 )); then func_show_help; exit 1; fi

  start_str="$1"; end_str="$2"; adbmt_tmp="$3"; shift 3

  while (( $# )); do
    case "$1" in
      -gpseg|--gpseg)               shift; gpseg_opt="${1:-}";;
      -free-space|--free-space)     shift; free_spc="${1:-}" ;;
      -all-hosts|--all-hosts)       shift; all_hosts="${1:-}";;
      -dry-run|--dry-run)           dry_run=1;;
      -h|--help)                    func_show_help; exit 0;;
      -debug|--debug)               DEBUG=1;;
      *)                            f_prt err "Unknown option: $1";
                                    func_show_help; exit 1;;
    esac
    shift || true
  done

  func_check_args
}


func_check_args() {  # check input arguments
  if [[ ! -n "$gpseg_opt" ]]; then
    f_prt err "Option -gpseg is necessary"
    exit 1
  fi
  if [[ ! "$free_spc" =~ ^([0-9]+)(\.[0-9]+)?$ ]]; then
    f_prt err "-free-space must be numeric"
    exit 1
  fi
  if ! func_validate_datetime_strict "$start_str"; then
    f_prt err "Incorrect start: $start_str"
    exit 1
  fi
  if ! func_validate_datetime_strict "$end_str"; then
    f_prt err "Incorrect end: $end_str"
    exit 1
  fi
  if [[ ! -r "$all_hosts" ]]; then
    f_prt err "DBMS cluster hosts file not found: $all_hosts"
    exit 1
  fi
}


func_parse_gpseg() {  # Parsing -gpseg into role and segment_number
  local s="$gpseg_opt"

  if [[ "$s" =~ ^-?[0-9]+$ ]]; then
    if [[ "$s" == "-1" ]]; then
      seg_role="master"
    else
      seg_role="primary"
    fi
    seg_num="$s"
  elif [[ "$s" =~ ^[Pp]([0-9]+)$ ]]; then
    seg_role="primary"
    seg_num="${BASH_REMATCH[1]}"
  elif [[ "$s" =~ ^[Mm]([0-9]+)$ ]]; then
    seg_role="mirror"
    seg_num="${BASH_REMATCH[1]}"
  else
    f_prt err "Incorrect -gpseg: $s (expected -1 | N | pN | mN)"
    exit 1
  fi

  if [[ "$seg_role" != "master" ]]; then
    [[ "$seg_num" =~ ^[0-9]+$ ]] || \
      { f_prt err "gpseg must be >=0"; exit 1; }
  else
    [[ "$seg_num" == "-1" ]] ||     \
      { f_prt err "For master-node use options -gpseg -1"; exit 1; }
  fi
}


func_debug_remote_probe() {  # fast debug check
  ((DEBUG == 1)) || return 0
  f_prt dbg "Check ls/stat on ${seg_host}:${seg_path}"
  ssh "$seg_host" "set -e; printf 'REMOTE whoami: '; whoami;           \
     printf 'REMOTE shell : '; echo \"\$SHELL\";                       \
     printf 'REMOTE find : ';  command -v find || true;                \
     printf 'REMOTE dir  : ';  ls -ld -- '""$seg_path""' || true;      \
     printf 'CSV.gz count: ';  find '""$seg_path""'                    \
            -maxdepth 1 -type f -name 'gpdb-*.csv.gz' | wc -l;         \
     printf 'CSV    count: ';  find '""$seg_path""'                    \
            -maxdepth 1 -type f -name 'gpdb-*.csv'    | wc -l;         \
     printf 'CSV.gz head :\n'; find '""$seg_path""'                    \
            -maxdepth 1 -type f -name 'gpdb-*.csv.gz' -printf '%f\n' | \
              head -5 | sed -n '1,5p'; true
    "
}


func_resolve_seg_host_and_path() {  # search seg_host и seg_path
  # find path like */<role>/gpseg<seg_num>/pg_log
  local cmd="find / -xdev \( \
    -path /proc -o -path /sys -o -path /run -o -path /dev \) \
    -prune -o -regextype posix-extended                      \
    -regex '.*/(${seg_role})/gpseg(${seg_num})/pg_log'       \
    -print 2>/dev/null"

  echo "seg_role="${seg_role}
  echo "seg_num="${seg_num}
  echo "all_hosts="${all_hosts}

  if ((seg_num == -1)); then
    hosts_clause="-h $(hostname)"  # line for master
  else
    hosts_clause="-f $all_hosts"   # line for segment
  fi
  local line  # get fist founded line
  line="$(gpssh ${hosts_clause} "$cmd" 2>/dev/null | \
            grep "/${seg_role}/gpseg${seg_num}/pg_log" | head -n1 || true)"

  # remove symbols CR/LF and redundant tab and spaces
  line="$(printf '%s' "$line" | tr -d '\r' )"
  line="${line//$'\t'/ }"
  line="${line%$'\n'}"
  echo line=$line

  # Usually gpssh format is: [host.name] /path/to/.../pg_log
  # But sometimes format is: [ host.name] /path/to/.../pg_log
  seg_host="$(echo ${line} | \
    sed -nE 's/^\[[[:space:]]*([^[:space:]]+)[[:space:]]*].*/\1/p')"
  seg_path="$(echo ${line} | cut -d ']' -f 2 | tr -d ' ')"
  echo seg_host=$seg_host
  echo seg_path=$seg_path

  # Let's clean it up again just in case
  seg_host="$(printf '%s' "$seg_host" | tr -d '\r\n')"
  seg_path="$(printf '%s' "$seg_path" | tr -d '\r\n')"

  [[ -n "$seg_host" && -n "$seg_path" ]] || { \
      f_prt err "Failed to parse seg_host/seg_path from gpssh out"
      exit 1
    }

  f_prt "--- Defined for download ---"
  f_prt "HOST: host=${seg_host}"
  f_prt "PATH: seg_path=${seg_path}"
}


func_remote_scan_and_build_intervals() {  # Scan files on host via ssh
  local -a files_raw=()
  local -a entries=()

  # 1) Raw list of names
  f_prt dbg "Запрашиваю список файлов по ssh ..."
  mapfile -t files_raw < <(
    ssh "$seg_host" "{ \
        LC_ALL=C find '""$seg_path""' -maxdepth 1 -type f                   \
                                      -name 'gpdb-*.csv' -printf '%f\n';    \
        LC_ALL=C find '""$seg_path""' -maxdepth 1 -type f                   \
                                      -name 'gpdb-*.csv.gz' -printf '%f\n'; \
      } 2>/dev/null | LC_ALL=C sort" \
    | tr -d $'\r'
  ) || true

  f_prt dbg "Получено строк: ${#files_raw[@]}"
  if ((DEBUG == 1)); then
    printf '%s - DEBUG: RAW[1..5]:\n  %s\n  %s\n  %s\n  %s\n  %s\n' \
      "$(date +'%F %T')" "${files_raw[0]:-}" "${files_raw[1]:-}"    \
      "${files_raw[2]:-}" "${files_raw[3]:-}" "${files_raw[4]:-}"
  fi

  if ((${#files_raw[@]}==0)); then
    f_prt "В $seg_host:$seg_path нет файлов gpdb-*.csv(.gz)"
    exit 2
  fi

  # 2) Convert list to "epoch\tfile", sort by time
  mapfile -t entries < <(
    for f in "${files_raw[@]}"; do
      f="${f%$'\r'}"; f="${f//$'\n'/}"
      ts="${f#gpdb-}"
      ts="${ts%.csv.gz}"; ts="${ts%.csv}"
      date_part="${ts%_*}"; hms="${ts#*_}"
      [[ ${#hms} -eq 6 ]] || \
        { f_prt dbg "Пропуск $f (hms='${hms}', len=${#hms})"; continue; }
      hh=${hms:0:2}; mm=${hms:2:2}; ss=${hms:4:2}
      ep="$(date -d "${date_part} ${hh}:${mm}:${ss}" +%s 2>/dev/null)" || \
        { f_prt dbg "date не распарсил $f"; continue; }
      printf "%s\t%s\n" "$ep" "$f"
    done | LC_ALL=C sort -n
  ) || true

  f_prt dbg "Валидных записей после парсинга: ${#entries[@]}"

  if ((${#entries[@]}==0)); then
    f_prt "В $seg_host:$seg_path нет корректных файлов (имя не распозналось)"
    exit 2
  fi

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
    f_prt dbg "INTVL ${FILES[i]}: $(date -d @${STARTS[i]} +'%F %T') .. $(date -d @${ENDS[i]} +'%F %T')"
  done
}


func_select_files_by_range() {  # Selection by time range
  local start_epoch end_epoch
  start_epoch="$(func_epoch_from_minute "$start_str")"
  end_epoch=$(( $(func_epoch_from_minute "$end_str") + 59 ))
  SELECTED=()

  (( start_epoch <= end_epoch )) || \
    { f_prt err "start > end"; exit 1; }

  for ((i=0; i<${#FILES[@]}; i++)); do
    local si="${STARTS[i]}" ei="${ENDS[i]}"
    if (( si <= end_epoch && ei >= start_epoch )); then
      SELECTED+=( "${FILES[i]}" )
    fi
  done
  ((${#SELECTED[@]})) || \
    { f_prt "Не найдено файлов, пересекающихся с интервалом [$start_str .. $end_str]."; exit 3; }
}


func_pick_sample_and_estimate_ratio() {  # csv.gz Compression Ratio Evaluator
  smpl_bytes=$((32 * 1024 * 1024))       # 32 MiB in bytes for sample
  EST_RATIO_NUM=""
  EST_RATIO_DEN=""
  local sample=""
  local size=0
  local osz

  for f in "${SELECTED[@]}"; do
    [[ "$f" == *.csv ]] || continue
    osz="$(ssh "$seg_host" "stat -c%s -- '$seg_path/$f'" | \
           tr -d '[:space:]' || true)"
    [[ "$osz" =~ ^[0-9]+$ ]] || continue
    sample="$f"; size="$osz"; break
  done

  if [[ -n "$sample" ]]; then
    local take="$size"; (( take > smpl_bytes )) && take="$smpl_bytes"
    local comp_sample
    comp_sample="$(ssh "$seg_host" "head -c $take -- '$seg_path/$sample' | \
                     gzip -c | wc -c" | tr -d '[:space:]')"
    EST_RATIO_NUM="$comp_sample"; EST_RATIO_DEN="$take"
    local pct factor
    pct=$(awk -v n="$EST_RATIO_NUM"    \
              -v d="$EST_RATIO_DEN"    \
              'BEGIN{printf "%.1f", 100*n/d}')
    factor=$(awk -v n="$EST_RATIO_NUM" \
                 -v d="$EST_RATIO_DEN" \
                 'BEGIN{printf "%.2f", d/n}')
    f_prt dbg "Оценка сжатия по образцу: ${seg_host}:${seg_path}/${sample}"
    f_prt dbg "Использовано выборки для оценщика: $take байт из $size"
    f_prt dbg "Оценочное отношение: ~${pct}% от исходного (~${factor}x меньше)"
  else
    f_prt "Оценка: среди выбранных файлов нет несжатых csv - пропускаю оценщик."
  fi
}


func_estimate_planned_bytes() { # Evaluation of the planned volume of log files
  local est_total=0
  total_src_bytes=0

  for f in "${SELECTED[@]}"; do
    local src="$seg_path/$f"
    local osz
    # take size of file
    osz="$(ssh -T "$seg_host" "stat -c%s -- '$src'" 2>/dev/null | \
           tr -d '[:space:]')"
    [[ "$osz" =~ ^[0-9]+$ ]] || osz=0

    total_src_bytes=$((total_src_bytes + osz))

    if [[ "$f" == *.csv.gz ]]; then
      est_total=$((est_total + osz))
    else
      if [[ -n "$EST_RATIO_NUM" && -n "$EST_RATIO_DEN" ]]; then
        est_total=$(( est_total +     \
          $(awk -v os="$osz"          \
                -v n="$EST_RATIO_NUM" \
                -v d="$EST_RATIO_DEN" \
                'BEGIN{printf "%.0f", os*n/d}') ))
      else
        est_total=$((est_total + osz))
      fi
    fi
  done

  est_gz_total="$est_total"
  EST_RATIO_NUM="$est_total"
}


func_check_free_space() {  # Checking free space
  local free_perc
  local exceed=0

  mkdir -p -- "$adbmt_tmp"
  read -r avail_bytes mnt_path < <(func_df_avail_and_target "$adbmt_tmp")

  free_perc=$(
              awk -v y="$EST_RATIO_NUM"                 \
                  -v x="$avail_bytes"                   \
                  'BEGIN {                              \
                          if (x==0) {print "inf"}       \
                          else {printf "%.2f", 100*y/x} \
                         }'
             )

  if [[ "$free_perc" == "inf" ]]; then
    exceed=1
  else
    awk -v p="$free_perc" \
        -v f="$free_spc"        \
        'BEGIN{ if (p>f) exit 0; else exit 1 }' && \
      exceed=1 || exceed=0
  fi

  if ((exceed == 1)); then
    f_prt "На разделе ${mnt_path} для каталога $adbmt_tmp"
    f_prt "имеется ${avail_bytes} байт свободного места."
    f_prt "Необходимо скачать ${EST_RATIO_NUM} байт лог-файлов."
    f_prt "Это ${free_perc}% от свободного места на разделе ${mnt_path},"
    f_prt "что превышает установленное в -free-space ${free_spc} процентов."
    f_prt "Необходимо либо увеличить значение -free-space,"
    f_prt "либо уменьшить объем выборки логов."
    exit 10
  fi
}


func_copy_with_compression() {  # Copying csv-files
  mkdir -p -- "$adbmt_tmp"
  total_gz_bytes=0

  for f in "${SELECTED[@]}"; do
    local src="$seg_path/$f"
    local base="${f%.csv.gz}"; base="${base%.csv}"
    local dest="$adbmt_tmp/${base}.csv.gz"

    if [[ "$f" == *.csv.gz ]]; then
      scp -q "$seg_host:$src" "$dest"
    else
      ssh -q "$seg_host" "gzip -c -- '$src'" > "$dest"
    fi

    local gzsz; gzsz=$(stat -c%s -- "$dest")
    total_gz_bytes=$((total_gz_bytes + gzsz))
  done
}


func_print_summary() {  # print final summary to stdout
  f_prt "Каталог назначения на выгрузку лог-файлов: $adbmt_tmp"
  f_prt "Число лог-файлов для копирования: ${#SELECTED[@]}"
  f_prt "Оценочный размер лог-файлов:"
  f_prt "${est_gz_total} байт, $((est_gz_total/1024/1024)) мегабайт"
  if (( dry_run != 1 )); then
    f_prt "Фактический размер лог-файлов:"
    f_prt "${total_gz_bytes} байт, $((total_gz_bytes/1024/1024)) мегабайт"
  else
    f_prt "Опция --dry-run - сжатие и копирование не выполнялись."
  fi
  f_prt "Список файлов:"
  printf '%s\n' "${SELECTED[@]}"
}


func_main "$@"  # from this point script starts running
exit 0





