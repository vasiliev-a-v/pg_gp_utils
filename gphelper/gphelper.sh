#!/bin/bash
# This script is used for analyze gpbackup helper (ddboost)
# Это самый последний актуальный скрипт


## Defining global variables ---------------------------------------- ##

script_version=0.2                  # Версия скрипта
script=$(readlink -f $0)            # полный путь к файлу скрипта
current_path=$(dirname $script)     # каталог с файлом скрипта
module="$(basename $script)"        # имя программы с расширением .sh
declare -a argv=( $* )              # записываем аргументы 
                                    # командной строки в массив argv
# имя программы без расширения
script_name=$(echo $module | cut -f1 -d '.')
tst_db=postgres                     # БД, в которой будут таблицы

# /p/gphelper/gphelper1.sh --date 20240325 --ticket INC0019294 --path /a/INC/INC0019294 --bkp_log gpbackup_20240325.log --host avas-dwm1 --user avas

## BEGIN: Settings -------------------------------------------------- ##
# date=20240325
# ticket=INC0019294
# host=avas-dwm1
# user=avas
# path=/a/INC/$ticket
# bkp_log=gpbackup_$date.log
## END: Settings ---------------------------------------------------- ##


func_main() {                 # main function
  func_get_arguments          # записывает в переменные аргументы
  func_upload_files_to_host   # upload bkp and helpers to ADB host
  func_create_gp_schema       # create schema for gphelper-tables
  func_helper                 # make helper table
  func_gpbackup_log           # make gpbackup_log table
  func_start_table            # make starts table
  func_stop_table             # make stops table
  func_tables_create          # make "tables" table
  func_tables_insert          # insert into "tables" table
  func_report_backup          # make report for backup
  func_last_actions           # make last actions
}


func_show_help(){  # отображает подсказку пользователю
  echo "
    Программа $module версия: $script_version
    Использование:                                   - Текущее значение:
    --date     - дата создания backup                - $date
    --ticket   - номер тикета в Simpleone            - $ticket
    --path     - путь к файлам хелперов и backup_log - $path
    --bkp_log  - имя файла backup_log                - $bkp_log

    Настройки подключения к СУБД:
    --host     - имя сервера СУБД                    - $host
    --user     - пользователь на мастер по ssh       - $user

    --version  - текущая версия программы            - $script_version
    --help     - вызов подсказки по использованию

    Example:
    $module --date 20240308 --ticket INC0012345 --path /a/INC/INC0012345 --bkp_log gpbackup_20240308.log --host a-dwm1 --user avas
  "
}


func_get_arguments() {  # записывает в переменные аргументы из CLI
  # если аргументов нет, то программа выведет help и завершится
  [[ ${#argv[@]} < 1 ]] && argv[0]="--help"
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
    "--path" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        path="${argv[$i+1]}"
      fi
      ;;
    "--bkp_log" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        bkp_log="${argv[$i+1]}"
      fi
      ;;
    "--host" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        host="${argv[$i+1]}"
      fi
      ;;
    "--user" )
      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
        user="${argv[$i+1]}"
      fi
      ;;
    "-v" | "--version" )
      echo $script_version; exit 0
      ;;
    "--help" )
      func_show_help; exit 0
      ;;
    esac
  done

  # дополнительные преобразования:
  ticket="$(echo $ticket | tr [:upper:] [:lower:])"
  # Схема, в которой будут создаваться таблицы:
  gp_schema=$ticket
}


func_upload_files_to_host() {  # upload bkp and helpers to ADB host
# скопировать со своего компьютера на свой тестовый кластер ADB:
scp $path/gpbackup_helper.tar.gz $user@$host:/tmp
scp $path/$bkp_log               $user@$host:/tmp

ssh $user@$host -T << EOF
  set -x  # Включить вывод команд
  chmod 0666 /tmp/gpbackup_helper.tar.gz
  chmod 0666 /tmp/$bkp_log
EOF
}


func_create_gp_schema() {  # create schema for gphelper-tables
ssh $user@$host -T << EOF
  set -x  # Включить вывод команд
  sudo -iu gpadmin
    set -x  # Включить вывод команд в gpadmin
    psql -d $tst_db -Atc "CREATE SCHEMA IF NOT EXISTS ${gp_schema}"
EOF
}


func_helper() {  # make helper table
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin
echo "$LINENO: CREATE TABLE ${gp_schema}.helper_log_${date}"
echo "
CREATE TABLE IF NOT EXISTS ${gp_schema}.helper_log_${date}
  (number int, line text)
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED BY (number);
" | psql -d ${tst_db}

echo "$LINENO: copy to ${gp_schema}.helper_log_${date}"
cd /tmp/
tar tf gpbackup_helper.tar.gz | \
  grep 'tar.gz' | \
  grep ${date} | \
  xargs -i -n1 -I {} \
  sh -c "tar xf gpbackup_helper.tar.gz {} -O | \
  tar xz -O" | \
  nl | \
  PGOPTIONS='-c gp_interconnect_type=tcp' \
  psql -d ${tst_db} -c "\copy ${gp_schema}.helper_log_${date} from stdin"
EOF
}


func_gpbackup_log() {  # make gpbackup_log table
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin
echo "$LINENO: CREATE TABLE ${gp_schema}.gpbackup_log_${date}"
echo "
CREATE TABLE IF NOT EXISTS ${gp_schema}.gpbackup_log_${date}
  (line text)
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY;
" | psql -d ${tst_db}

cat /tmp/$bkp_log | \
  PGOPTIONS='-c gp_interconnect_type=tcp' \
  psql -d ${tst_db} -c "\copy ${gp_schema}.gpbackup_log_${date} from stdin with (FORMAT text, DELIMITER \"^\")"
EOF
}


func_start_table() {  # make starts table
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin
echo "
\echo $LINENO: DROP TABLE ${gp_schema}.starts_${date}
DROP TABLE IF EXISTS ${gp_schema}.starts_${date};
\echo $LINENO: CREATE TABLE ${gp_schema}.starts_${date}
CREATE TABLE ${gp_schema}.starts_${date} WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  AS SELECT 
             -- время начала копирования
            (sizes[1] || ' ' || sizes[2])::timestamp AS start,
             sizes[3]::int AS content, -- сегмент
             sizes[4]::int AS oid,     -- oid таблицы
             sizes[5]::int as gpid     -- PID gpbackup
  FROM (
         SELECT
                regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:\S+:\S+:\d+-\[\w+\]:-Segment (\d+): Oid (\d+): Backing up table with pipe /\S+/gpbackup_\d+_\d+_pipe_(\d+)') sizes
           FROM ${gp_schema}.helper_log_${date}
          WHERE line LIKE '%: Backing up table with pipe%'
       ) AS s
    DISTRIBUTED BY (oid);
" | PGOPTIONS='-c gp_interconnect_type=tcp' psql -d ${tst_db}
EOF
}


func_stop_table() {  # make stops table
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin
echo "
\echo $LINENO: DROP TABLE ${gp_schema}.stops_${date}
DROP TABLE IF EXISTS ${gp_schema}.stops_${date};
\echo $LINENO: CREATE TABLE ${gp_schema}.stops_${date}
CREATE TABLE ${gp_schema}.stops_${date} AS
  SELECT
    -- время окончания копирования
   (sizes[1] || ' ' || sizes[2])::timestamp as finish,
    sizes[3] as host,
    sizes[4]::int as content, -- сегмент
    sizes[5]::int as oid,     -- oid таблицы
    sizes[6]::bigint as size, -- размер скопированных разжатых данных в байтах
    row_number() over(partition by sizes[4]::int order by number
   ) as number -- сортировка по номеру сегмента?
  FROM (
        SELECT
          regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:\S+:(\S+):\d+-\[\w+\]:-Segment (\d+): Oid (\d+): Read (\d+) bytes') sizes, number
          FROM ${gp_schema}.helper_log_${date}
         WHERE line LIKE '%: Read%'
  ) s 
  DISTRIBUTED BY (oid);
" | PGOPTIONS='-c gp_interconnect_type=tcp' psql -d ${tst_db}
EOF
}


func_tables_create() {  # make "tables" table
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin
echo "
\echo $LINENO: CREATE TABLE IF NOT EXISTS ${gp_schema}.tables_${date}
CREATE TABLE IF NOT EXISTS ${gp_schema}.tables_${date} (
         oid integer,
         tbl text,
        gpid integer
    )
  DISTRIBUTED BY (oid);
" | PGOPTIONS='-c gp_interconnect_type=tcp' psql -d ${tst_db}
EOF
}


func_tables_insert() {  # insert into "tables" table
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin

echo "
\echo $LINENO: INSERT INTO ${gp_schema}.tables_${date}

INSERT INTO tables_${date} SELECT
       sizes[3]::int as oid, -- oid таблицы
       sizes[2] as table,    -- схема и имя таблицы
       sizes[1]::int as gpid -- PID gpbackup
  FROM (
        SELECT regexp_matches(line, '^\d+:\d{2}:\d{2}:\d{2} \S+:(\d+)-\[\w+\]:-\S+ \d+: COPY (\S+.\S+) TO PROGRAM \S+ \S+ \S+_pipe_\d+_(\d+)') sizes
  FROM ${gp_schema}.gpbackup_log_${date} WHERE line LIKE '%: COPY % TO PROGRAM%'
  ) s
;
" | PGOPTIONS='-c gp_interconnect_type=tcp' psql -d ${tst_db}

EOF
}


# TODO: сделать вместо SQL-запроса - вызов отдельного SQL-файла
func_report_backup() {  # make report for backup
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
set -x  # Включить вывод команд в gpadmin
echo "$(cat $current_path/gphelper_common.sql)" | \
PGOPTIONS='-c gp_interconnect_type=tcp' psql -d ${tst_db} \
  -v date=${date} \
  -v gp_schema=${gp_schema}
EOF
}


func_last_actions() {  # make last actions
ssh $user@$host -T << EOF
set -x  # Включить вывод команд
sudo -iu gpadmin
  set -x  # Включить вывод команд в gpadmin
  echo "$LINENO: make VACUUM"
  vacuumdb --dbname ${tst_db} --analyze
  logout

# Удаляем загруженные ранее файлы хелперов и бэкапа
rm -f /tmp/gpbackup_helper.tar.gz
rm -f /tmp/$bkp_log
EOF
}


func_main
exit 0
