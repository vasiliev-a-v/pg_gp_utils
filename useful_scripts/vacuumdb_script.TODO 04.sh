#!/bin/bash
# скрипт:
# - запускает vacuumdb с параметром verbose
# - записывает в журнал каждый шаг, выставляя точное время ОС


# TODO: хотел переписать скрипт с использованием psql вместо vacuumdb.
# TODO: при этом добавить опции 
# SET debug_appendonly_print_compaction = on;
# SET debug_appendonly_print_segfile_choice = on;
# TODO: добавить опционально gplogfilter для сбора лога о вакууме
# ```
# dbname=gpadmin
# table=public.test_ao_table
# b=$(date '+%Y-%m-%dT%H:%M')
# echo "SET debug_appendonly_print_compaction = on; SET debug_appendonly_print_segfile_choice = on; SELECT now() VACUUM_BEGIN; VACUUM (VERBOSE) $table; SELECT now() VACUUM_END" | psql -d $dbname -U gpadmin --echo-queries 2>&1 | tee > /tmp/vacuum_debug.log
# e=$(date -d '+1 minute' '+%Y-%m-%dT%H:%M')
# gplogfilter -b $b -e $e -o /tmp/vacuum_debug_pg_log.csv.gz $MASTER_DATA_DIRECTORY/pg_log/gpdb-$(date '+%Y-%m-%d')*
# ```




## Defining global variables ---------------------------------------- ##

script_version=0.4                    # script version
script=$(readlink -f $0)              # full path to script
current_path=$(dirname $script)       # directory where scrit is located
module="$(basename $script)"          # scripts file name
script_name=${module%".sh"}           # scriptname without .sh
declare -a argv=( $* )                # puts argues from CLI into array

## BEGIN: Default Settings ------------------------------------------ ##
dbname=adb
work_dir=/home/gpadmin/gpAdminLogs
## END: Default Settings -------------------------------------------- ##
## END: Defining global variables ----------------------------------- ##


func_main() {         # main function
  func_get_arguments  # writes argues from CLI into variables
  func_make_vacuum    # executes vacuum
}


func_show_help(){  # shows using help:
  [[ $table == "" ]] && table=arenadata_toolkit.db_files_current

  echo "
    Program $module version: $script_version
    Usage:                                            - Current setting:
    --dbname   - database name to vacuum              - $dbname
    --table    - (optional) for particulal table.
                 in format: schema.table              - $table
    
    --work_dir - path to directory for log file       - $work_dir
                 by default: standart log directory for GP utilites.
    --version  - current version                      - $script_version
    --help     - show this help

    Example:
    $module --dbname $dbname
    # make vacuum for particular table
    $module --dbname $dbname --table $table
  "
  exit 0
}


func_get_arguments() {  # writes argues from CLI into variables
  # if no argues, then show help and exit
  [[ ${#argv[@]} < 1 ]] && argv[0]="--help"

  for (( i = 0; i < ${#argv[@]}; i++ )); do
    case ${argv[$i]} in
    "--dbname" )                if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  dbname="${argv[$i+1]}"
                                fi;;
    "--table" )                 if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  table="${argv[$i+1]}"
                                fi;;
    "--work_dir" )              if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  work_dir="${argv[$i+1]}"
                                fi;;
    "-v" | "--version" )        echo $script_version; exit 0;;
    "--help" )                  func_show_help; exit 0;;
    esac
  done
}


func_make_vacuum() {  # executes vacuum
  if [[ $table == "" ]]; then
    t_in_log=""
    t_argue=""
  else
    t_in_log=".$table"
    t_argue="--table=$table"
  fi

  if $(which vacuumdb 1>/dev/null); then
    v_path=vacuumdb
  else  # there is no path to vacuumdb utility in the $PATH
    v_path=/usr/lib/gpdb/bin/vacuumdb
  fi

    
  # log_file_name="${work_dir}/vacuumdb_${dbname}${t_in_log}_$(date +%Y%m%d).log"
  log_file_name="${work_dir}/vacuumdb_$(date +%Y%m%d).log"
  echo "tail -f $log_file_name"

  echo "$(date '+%Y-%m-%d %H:%M:%S.%N') - START: $script ${argv[*]}" >> \
    $log_file_name

  $v_path --dbname=$dbname $t_argue --echo --verbose 2>&1 | \
    while read line; do
      echo "$(date '+%Y-%m-%d %H:%M:%S.%N') - $line" >> \
        $log_file_name
    done

  echo "$(date '+%Y-%m-%d %H:%M:%S.%N') - END: $script ${argv[*]}
  " >> $log_file_name
}


func_main
exit 0
