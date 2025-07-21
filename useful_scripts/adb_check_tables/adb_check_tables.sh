#!/bin/bash

# скрипт производит чтение всех таблиц базы данных через COPY.
# Данное действие необходимо для принудительного чтения всех блоков таблиц.
# Ошибки, проявившиеся при чтении таблиц, покажут наличие таблиц со сбойными блоками.
# Такие таблицы необходимо будет пересоздать.


## BEGIN: Defining global variables --------------------------------- ##

script_version=0.1                    # script version
script=$(readlink -f $0)              # full path to script
current_path=$(dirname $script)       # directory where scrit is located
module="$(basename $script)"          # scripts file name
script_name=${module%".sh"}           # scriptname without .sh
declare -a argv=( $* )                # puts argues from CLI into array

## END: Defining global variables ----------------------------------- ##


## BEGIN: Default Settings ------------------------------------------ ##
dbname=gpadmin              # имя базы данных
dbuser=gpadmin              # пользователь СУБД
dbhost=avas-cdwm1           # имя мастер-хоста СУБД ADB
dir=/tmp/adb_check_tables   # домашняя директория для файлов
## END: Default Settings -------------------------------------------- ##


# Каталоги и файлы для работы скрипта:
mkdir -p $dir
tbl_log=$dir/tables_list.log  # tl - tables list
err_log=$dir/copy_tables_err.log
std_log=$dir/copy_tables_out.log


func_main() {  # основная функция
  func_get_tables_list
  func_copy_tables
}


func_psql() {  # выполняет psql-запрос
  local query=$1
  local attrb=$2
  psql $attrb -d $dbname -U $dbuser -h $dbhost << EOF
    ${query}
EOF
}


func_get_tables_list() {  # собираем список таблиц в файл
  query="
SELECT n.nspname || '.' || c.relname
  FROM pg_class c
  JOIN pg_namespace n
    ON c.relnamespace = n.oid
 WHERE relpersistence = 'p'  -- p = heap or append-optimized table
   -- AND relkind ~ 'r|'  -- 
   AND relkind !~ 'i|S|v|c|f|u'  -- 
   AND relstorage ~ 'a|c|h'   -- v = virtual, x = external table
"
  func_psql "$query" "-Atq" > $tbl_log

  # записать список таблиц в массив
  tl_arr=( $(cat $tbl_log) )
}


func_copy_tables() {  # вычитывает таблицы в /dev/null
  local line1
  local line2

# set gp_resource_group_bypass = on;
# BYPASS=PGOPTIONS="-c gp_resource_group_bypass=true -c application_name='${script_name}'"
# BYPASS=(env PGOPTIONS="-c gp_resource_group_bypass=false -c application_name=\"${script_name}\"")
BYPASS=(env PGOPTIONS="-c gp_resource_group_bypass=on")

  for (( i = 0; i < ${#tl_arr[@]}; i++ )); do
    # $BYPASS psql -At -d $dbname -U $dbuser -h $dbhost
    "${BYPASS[@]}" psql -At -d "$dbname" -U "$dbuser" -h "$dbhost" \
      2> >(while IFS= read -r line2; do
            echo "$(date '+%Y-%m-%d %H:%M:%S'), $line2"
            done >> $err_log) \
      -Xc "SET application_name = 'adb_check_tables.sh'" \
      -c "SHOW application_name; SHOW gp_resource_group_bypass;" \
      -c "SELECT '$((i + 1)), ${tl_arr[$i]}, start copy: ' || now()" \
      -c "COPY (SELECT * FROM ${tl_arr[$i]})
            TO '/dev/null'
          WITH (FORMAT csv)" \
      -c "SELECT '$((i + 1)), ${tl_arr[$i]}, end copy: ' || now()" \
      | tee -a $std_log
    exit 0
  done
}


func_main
exit 0



exit 0
ERROR:  read beyond eof in table "tb_aocs_test" file "base/17019/25143.1", read position 0 (small offset 10), actual read length 0 (large read length 65536) (cdbbufferedread.c:211)  (seg0 slice1 10.92.35.199:10000 pid=3080) (cdbbufferedread.c:211)
