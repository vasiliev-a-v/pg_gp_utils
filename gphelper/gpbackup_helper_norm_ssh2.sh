#!/bin/bash
# Данные скрипты для восстановления через ddboost gpbackup
# скрипт запускающий ssh

#~ chmod 0666 /tmp/gpbackup_helper.tar.gz
#~ chmod 0666 /tmp/gpbackup_${date}.log

## ОПРЕДЕЛЕНИЕ ГЛОБАЛЬНЫХ ПЕРЕМЕННЫХ -------------------------------- ##

script_version=1.7                  # Версия скрипта
script=$(readlink -f $0)            # полный путь к файлу скрипта
current_path=$(dirname $script)     # каталог с файлом скрипта
module="$(basename $script)"        # имя программы с расширением .sh
script_name=$(echo $module | cut -f1 -d '.')  # имя программы без расширения
declare -a argv=( $* )     # записываем аргументы командной строки в массив argv

## НАСТРОЙКИ -------------------------------------------------------- ##

## КОНЕЦ: НАСТРОЙКИ ------------------------------------------------- ##


date=20240325
ticket=INC0019294
tst_host=avas-dwm1
#~ tst_db=gpadmin
tst_user=avas
#~ tst_schema=$ticket
path=/a/INC/$ticket


func_main() {  #~ основная функция
  func_get_arguments                 # записывает в переменные аргументы
  func_common_actions
  func_helper
  func_gpbackup_log
  func_start_table
  func_stop_table
  func_tables_create
  func_tables_insert
  #~ func_report_backup
}


func_show_help(){  # отображает подсказку пользователю
  echo "
    Программа $module версия: $script_version
    Использование:                                   - Текущее значение:
    --date     - дата создания backup                - $date
    --ticket   - номер тикета в Simpleone            - $ticket
    --path     - путь к файлам хелперов и backup_log - $path

    Настройки подключения к СУБД:
    --host     - имя сервера СУБД                    - $tst_host
    --user     - пользователь на ssh-сервер          - $tst_user

    --version  - текущая версия программы            - $script_version
    --help     - вызов подсказки по использованию
  "
}

func_get_arguments() {  # записывает в переменные аргументы из CLI
  # если аргументов нет, то программа выведет help и завершится
  #[[ ${#argv[@]} < 1 ]] && argv[0]="--help"
  for (( i = 0; i < ${#argv[@]}; i++ )); do
    case ${argv[$i]} in
    "--date" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        date="${argv[$i+1]}"
      fi
      ;;
    "--ticket" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        ticket="${argv[$i+1]}"
      fi
      ;;
    "--host" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        tst_host="${argv[$i+1]}"
      fi
      ;;
    "--user" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        tst_user="${argv[$i+1]}"
      fi
      ;;
    "--path" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        path="${argv[$i+1]}"
      fi
      ;;
    "--help" )
      func_show_help; exit 0
      ;;
    "-v" | "--version" )
      echo $script_version; exit 0
      ;;
    esac
  done
}


func_common_actions() {  #~ _
  # прокидываем переменные для скрипта - в файл
  # для того, чтобы пользователь gpadmin получить переменные
  echo "
  date=$date
  ticket=$ticket
  path=$path
  host=$tst_host
  user=$tst_user
  script_version=$script_version
  " > /tmp/helper_upload.conf
  sudo -iu gpadmin
  source /tmp/helper_upload.conf
  echo $date
  exit 0
  exit 0
  createdb $ticket
  tst_db=$ticket
}


func_helper() {  #~ _

echo "CREATE TABLE helper_log_${date}"
echo "
CREATE TABLE IF NOT EXISTS $tst_schema.helper_log_${date}
  (number int, line text)
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 3
       )
  DISTRIBUTED BY (number);
" | psql -d ${tst_db}

echo "copy to helper_log_${date}"
cd /tmp/
tar tf gpbackup_helper.tar.gz | \
  grep 'tar.gz' | \
  grep ${date} | \
  xargs -i -n1 -I {} \
  sh -c "tar xf gpbackup_helper.tar.gz {} -O | \
  tar xz -O" | \
  nl | \
  psql -d ${tst_db} -c "\copy helper_log_${date} from stdin"
}


func_gpbackup_log() {  #~ _
echo "
\echo CREATE TABLE gpbackup_log_${date}
CREATE TABLE IF NOT EXISTS $tst_schema.gpbackup_log_${date} (line text) 
  WITH (
        appendonly=true,
        orientation=column,
        compresstype=zstd,
        compresslevel=1
       )
  DISTRIBUTED RANDOMLY;
" | psql -d ${tst_db}

cat /tmp/gpbackup_${date}.log | \
  psql -d ${tst_db} -c "\copy gpbackup_log_${date} from stdin with (FORMAT text, DELIMITER \"^\")"
}


func_start_table() {  #~ _
echo "
\echo DROP TABLE starts_${date}
DROP TABLE IF EXISTS starts_${date};

\echo CREATE TABLE starts_${date}
CREATE TABLE starts_${date} WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 3
       )
  AS SELECT (sizes[1] || ' ' || sizes[2])::timestamp AS start,   -- время начала копирования
             sizes[3]::int AS content, -- сегмент
             sizes[4]::int AS oid,     -- oid таблицы
             sizes[5]::int as gpid     -- PID gpbackup
  FROM (
         SELECT
                regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:\S+:\S+:\d+-\[\w+\]:-Segment (\d+): Oid (\d+): Backing up table with pipe /\S+/gpbackup_\d+_\d+_pipe_(\d+)') sizes
           FROM helper_log_${date}
          WHERE line LIKE '%: Backing up table with pipe%'
       ) AS s
    DISTRIBUTED BY (oid);
" | psql -d ${tst_db}
}


func_stop_table() {  #~ _
echo "
\echo DROP TABLE stops_${date}
DROP TABLE IF EXISTS stops_${date};
\echo CREATE TABLE stops_${date}
CREATE TABLE stops_${date} AS SELECT (
    sizes[1] || ' ' || sizes[2])::timestamp as finish, -- время окончания копирования
    sizes[3] as host,
    sizes[4]::int as content, -- сегмент
    sizes[5]::int as oid,     -- oid таблицы
    sizes[6]::bigint as size, -- размер скопированных разжатых данных в байтах
    row_number() over(partition by sizes[4]::int order by number
   ) as number -- сортировка по номеру сегмента?
  FROM (
        SELECT
          regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:\S+:(\S+):\d+-\[\w+\]:-Segment (\d+): Oid (\d+): Read (\d+) bytes') sizes, number
          FROM helper_log_${date}
         WHERE line LIKE '%: Read%'
  ) s 
  DISTRIBUTED BY (oid);
" | psql -d ${tst_db}
}


func_tables_create() {  #~ _
echo "
\echo CREATE TABLE IF NOT EXISTS tables_${date}
CREATE TABLE IF NOT EXISTS tables_${date} (
      oid integer,
      tbl text,
      gpid integer
    )
  DISTRIBUTED BY (oid);
" | psql -d ${tst_db}
}

func_tables_insert() {  #~ _
echo "
\echo INSERT INTO tables_${date}
INSERT INTO tables_${date} SELECT
             sizes[3]::int as oid, -- oid таблицы
             sizes[2] as table,    -- схема и имя таблицы
             sizes[1]::int as gpid -- PID gpbackup
  FROM (
        SELECT regexp_matches(line, '^\d+:\d{2}:\d{2}:\d{2} \S+:(\d+)-\[\w+\]:-\S+ \d+: COPY (\S+.\S+) TO PROGRAM \S+ \S+ \S+_pipe_\d+_(\d+)') sizes
  FROM gpbackup_log_${date} WHERE line LIKE '%: COPY % TO PROGRAM%'
  ) s
;
" | psql -d ${tst_db}
}


func_report_backup() {  #~ _
psql -d $tst_db << EOF
SET  search_path TO ${ticket};
SHOW search_path;
with
strs_cte as (select strs.oid as oid_start, min(strs.start) as bkp_start_min, max(strs.start) as bkp_start_max from starts_${date} strs group by strs.oid),
stps_cte as (select stps.oid as oid_stop, min(stps.finish) as bkp_stop_min, max(stps.finish) as bkp_stop_max, sum(stps.size) as bkp_size from stops_${date} stps group by stps.oid)
select
tables.table as schema_table_name, -- схема и имя таблицы
  strs_cte.oid_start as oid, -- oid таблицы
  strs_cte.bkp_start_min as bkp_start_min, -- минимальное время начала копирования на сегменте
  strs_cte.bkp_start_max as bkp_start_max, -- максимальное время начала копирования на сегменте
  strs_cte.bkp_start_max - strs_cte.bkp_start_min as wait_start, -- разница между действиями start
  stps_cte.bkp_stop_min as bkp_stop_min, -- минимальное время окончания копирования на сегменте
  stps_cte.bkp_stop_max as bkp_stop_max, -- максимальное время окончания копирования на сегменте
  stps_cte.bkp_stop_max - stps_cte.bkp_stop_min as wait_stop, -- разница между действиями stop
  stps_cte.bkp_stop_max - strs_cte.bkp_start_min as execute, -- разница между максимальное время окончания копирования и минимальное время начала копирования
  stps_cte.bkp_size as sum_size_byte, -- размер скопированных разжатых данных в байтах
  pg_size_pretty(stps_cte.bkp_size) as sum_size_human -- размер скопированных разжатых данных
from strs_cte
join stps_cte on strs_cte.oid_start = stps_cte.oid_stop
join tables_${date} tables on strs_cte.oid_start = tables.oid
where tables.gpid = ${gpid} -- при необходимости указать PID gpbackup
order by strs_cte.bkp_start_min;
EOF
}

func_main
exit 0
