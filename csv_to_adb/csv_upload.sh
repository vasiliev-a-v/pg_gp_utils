#!/bin/bash

# First part of csv to ADB scripts.
# This script uploads csv table to ADB cluster

#~ TODO: проверить загрузку db_files_current, db_files_history
#~ TODO: проверить новый синтаксис csv_to_adb.sh без опций table и так далее.
#~ TODO: проверить gp_toolkit.gp_resgroup_config (таблицы с точкой)
#~ TODO: отработать все известные шаблоны
#~ TODO: подготовить шаблоны загрузки для заказчика


## Defining global variables ---------------------------------------- ##

script_version=0.1                  # script version
script=$(readlink -f $0)            # full path to script
current_path=$(dirname $script)     # directory where scrit is located
module="$(basename $script)"        # scripts file name
script_name=${module%".sh"}         # scriptname without .sh
declare -a argv=( $* )              # put argues from CLI into array

# FULL COMMAND
#~ /p/csv_to_adb/csv_upload.sh --file check_data_skew20240314.csv --path /downloads --host avas-dwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0019026 --table check_data_skew20240314 --template template_check_data_skew.sql

# /p/csv_to_adb/csv_upload.sh --file a_cd_customer_account.a.csv.gz --path /a/INC/INC0020133/tar1 --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0020133 --table locks_a_cd_customer_account --template template_t_audit_locks_usage.sql


## BEGIN: Default Settings ------------------------------------------ ##
# file=gp_resgroup_config.csv.gz
# path=/a/INC/INC0019026/logs
# host=avas-cdwm1
# user=avas
template="template_common.sql"
schema=pg_catalog
## END: Default Settings -------------------------------------------- ##


func_main() {  #~ main function
  func_get_arguments
  # func_upload
  # func_csv_to_adb
  func_remove_csv
}


func_show_help(){  # show using help
  echo "
    Program $module version: $script_version
    Usage:                                            - Current setting:
    --path     - local full path to filename.csv.gz   - $path
                 or filename.csv
    Settings to DBMS:
    --host     - DBMS master (coordinator) hostname   - $host
    --user     - remote ssh-user in DBMS-host for scp - $user


    --csv_to_adb - csv_to_adb script path in cluster  - $csv_to_adb

    If you define --csv_to_adb option,
    then you also need to define these settings:
    --ticket   - ticket number in Simpleone.          - $ticket
                 Script creates a DB based on the ticket name.
    --table    - table name to upload                 - $table
                 If table is not defined,
                 then the value will de derived from filename.
    --template - SQL-template file to CREATE TABLE    - $template
                 If SQL-template is not used,
                 then using CREATE TABLE $table (LIKE \$table).
                 SQL-template file must be located in scripts directory.
    --schema   - original table schema name, such as  - $schema
                 pg_catalog in pg_stat_activity,
                 or arenadata_toolkit.
                 if you are using (LIKE \$table) clause.


    --version  - current version                      - $script_version
    --help     - show this help
    Example 1:
    $module --path /downloads/pg_class.csv.gz --host adb-dwm1 --user adm
    Example 2 (with --csv_to_adb option):
    $module --path /downloads/pg_class.csv.gz --host adb-dwm1 --user adm --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC1010101 --table pg_class --template template_pg_class.sql
  "
}


func_get_arguments() {  # write argues from CLI into variables
  # if no argues, then show help and exit
  [[ ${#argv[@]} < 1 ]] && argv[0]="--help"

  for (( i = 0; i < ${#argv[@]}; i++ )); do
    case ${argv[$i]} in
    "--path" )                  if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  path="${argv[$i+1]}"
                                fi;;
    "--host" )                  if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  host="${argv[$i+1]}"
                                fi;;
    "--user" )                  if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  user="${argv[$i+1]}"
                                fi;;

    "--csv_to_adb" )            if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  csv_to_adb="${argv[$i+1]}"
                                fi;;
    "--ticket" )                if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  ticket="${argv[$i+1]}"
                                fi;;
    "--table" )                 if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  table="${argv[$i+1]}"
                                fi;;
    "--template" )              if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  template="${argv[$i+1]}"
                                fi;;
    "--schema" )                if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  schema="${argv[$i+1]}"
                                fi;;

    "-v" | "--version" )        echo $script_version; exit 0;;
    "--help" )                  func_show_help; exit 0;;
    esac
  done

  # additional conversions:
  ticket="$(echo $ticket | tr [:upper:] [:lower:])"
  dbname=$ticket
  file="$(basename ${path})"

  # undefined variables:
  [[ $table == "" ]] && table=$(echo $file | cut -f1 -d '.')
}


func_upload() {  #~ upload to ADB cluster
  scp ${path} $user@$host:/tmp
  ssh -C $user@$host chmod 0666 /tmp/$file
}


func_csv_to_adb() {  #~ csv to ADB
  # if csv_to_adb procedure is not defined, then go out from function:
  [[ $csv_to_adb == "" ]] && return 0

  # Upload csv_to_adb script:
  echo "Upload csv_to_adb script onto $host cluster:"
  scp -r $current_path $user@$host:/tmp
  echo "bash ${csv_to_adb} --ticket $ticket --file $file --schema $schema --table $table --template $template" | ssh -C $user@$host sudo -iu gpadmin
}


func_remove_csv() {  # delete csv file after uploading
  if echo $file | grep ".gz"; then
    f_csv=${file%".gz"}
  fi
  echo "Удаляем загруженный файл."
  ssh -C $user@$host "echo "До удаления:"; ls -1 /tmp/$f_csv; rm -f /tmp/$f_csv; echo "После удаления:"; ls -1 /tmp/$f_csv"
}




func_main
exit 0


