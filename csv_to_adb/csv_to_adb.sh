#!/bin/bash


# Second part of csv to ADB scripts.
# This script creates a table and uploads CSV to ADB.
# CSV-file must be in /tmp directory.
# Download:
# scp -r /p/csv_to_adb/ avas@avas-cdwm1:/tmp


## Defining global variables ---------------------------------------- ##

script_version=0.1                    # script version
script=$(readlink -f $0)              # full path to script
current_path=$(dirname $script)       # directory where scrit is located
module="$(basename $script)"          # scripts file name
script_name=${module%".sh"}           # scriptname without .sh
declare -a argv=( $* )                # put argues from CLI into array


## BEGIN: Default Settings ------------------------------------------ ##
ticket=INC1010101
file=gp_resgroup_config.csv.gz
template="template_common.sql"
schema=pg_catalog
#~ schema=gp_toolkit
#~ schema=arenadata_toolkit
## END: Default Settings -------------------------------------------- ##


func_main() {  #~ main function
  func_get_arguments  # записывает в переменные аргументы из CLI
  func_prepare_file   # unzip file csv.gz
  func_createdb       # create DB from dbname var
  func_make_table     # create table, copy to it, vacuum and analyze
}


func_show_help(){  # show using help
  echo "
    Program $module version: $script_version
    Usage:                                            - Current setting:
    --ticket   - ticket number in Simpleone.          - $ticket
                 Script creates a DB based on the ticket name.
    --file     - filename.csv.gz with a table         - $file
                 You can use filename without gz.
    --table    - table name to upload                 - $table
                 If table is not defined,
                 then the value will de derived from filename.
    --template - SQL-template file to CREATE TABLE    - $template
                 If SQL-template is not used,
                 then using CREATE TABLE $table (LIKE \$table).
                 SQL-template file must be located in scripts directory.
    --schema   - original table schema name, such     - $schema
                 pg_catalog in pg_stat_activity.
                 if you are using (LIKE \$table) clause.
    --version  - current version                      - $script_version
    --help     - show this help

    Example:
    $script --ticket INC1010101 --file pg_proc.csv.gz --table pg_proc --schema pg_catalog
    $script --ticket INC1010101 --file pg_class.csv.gz --table pg_class --template template_pg_class.sql
  "
}


func_get_arguments() {  # write argues from CLI into variables
  # if no argues, then show help and exit
  [[ ${#argv[@]} < 1 ]] && argv[0]="--help"

  for (( i = 0; i < ${#argv[@]}; i++ )); do
    case ${argv[$i]} in
    "--ticket" )                if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  ticket="${argv[$i+1]}"
                                fi;;
    "--file" )                  if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  file="${argv[$i+1]}"
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
  # undefined variables:
  [[ $table == "" ]] && table=$(echo $file | cut -f1 -d '.')
}


func_prepare_file() {  # unpack file csv.gz if it archived
  # extract file extension from filename
  file_extension=$( expr match "$file" '.*\(\.[a-zA-Z0-9]*\)' )
  if [[ $file_extension == ".gz" ]]; then
#~ TODO: надо сделать, чтобы проверял старый файл и удалял его!
    #~ new_file=${file%".gz"}
    #~ # if previous file exists, then remove it:
    #~ [[ -f /tmp/"$new_file" ]] && rm -f /tmp/"$new_file" && echo REMOVE /tmp/$new_file
    gzip --force -d /tmp/"$file"
  fi

  # remove file extension .gz clause from filename
  file=${file%".gz"}
}


func_createdb() {  # create DB from dbname var
  echo "$LINENO: createdb $dbname"

  # create DB if it not created yet
  if psql -Atc "SELECT datname FROM pg_database" | grep -q $dbname;
  then
    echo "Database $dbname is already exists"
  else
    echo "Creating database: $dbname"
    createdb $ticket
  fi
}


func_make_table() {  # create table, copy to it, vacuum and analyze
  if [[ $template == "template_common.sql" ]]; then
    template=$current_path/template_common.sql
  else
    template=$current_path/$template
  fi
  echo "Using: $template"

  create_table=$(sed -e "s/\$table/$table/g" -e "s/\$schema/$schema/g" $template)
  echo "$create_table"
  echo "База данных: $dbname"
  psql -d $dbname -c "${create_table}"
  psql -d $dbname -c "COPY public.$table FROM '/tmp/$file' (FORMAT CSV, HEADER)"
  psql -d $dbname -c "VACUUM ANALYZE public.$table"
}


func_main  # main function
exit 0

