#!/bin/bash

# скрипт gplogfilter_all_cluster.sh собирает журналы сообщений СУБД
# за заданный период за сутки
# c master, standby-master, и primary-сегментов
# Если нужно больше чем за сутки,
# то нужно запустить два отдельных скрипта gplogfilter_all_cluster.sh
# Примерное расположение скрипта:
# /home/gpadmin/arenadata_configs/gplogfilter_all_cluster.sh
# Вызов скрипта без опций вызовет функцию func_show_help с пояснениями.
# TODO: подумать об опциональной возможности сбора миррор-сегментов

## Defining global variables ---------------------------------------- ##

script_version=0.3                    # script version
script=$(readlink -f $0)              # full path to script
current_path=$(dirname $script)       # directory where scrit is located
module="$(basename $script)"          # scripts file name
script_name=${module%".sh"}           # scriptname without .sh
declare -a argv=( $* )                # puts argues from CLI into array
LOGFILE=/home/gpadmin/gpAdminLogs/${module}_$(date +%Y%m%d).log

# Перенаправляем stdout и stderr в лог-файл:
exec > >(tee -a "$LOGFILE") 2>&1

## BEGIN: Default Settings ------------------------------------------ ##
PSQL="psql -d template1 -U gpadmin -Atq "
tmp_path=/tmp/$script_name
declare -a segno
declare -a hosts
declare -a paths
log_dir=/tmp/gplog  # log_dir default value
## END: Default Settings -------------------------------------------- ##
## END: Defining global variables ----------------------------------- ##


func_main() {          # main function
  echo $(date)" - Запуск скрипта ${script}"
  func_get_arguments   # write arguments from CLI into variables
  func_prepare         # подготовка
  func_get_arrays      # получение массивов переменных
  func_ssh             # gets logs from segments via ssh
  func_compress        # сжимаем логи в архив
  echo $(date)" - Завершаем работу ${script}"
  echo
}


func_show_help(){  # show using help
  echo "
    Program $module version: $script_version
    Usage:                                            - Current setting:
    -b, --date_beg - date and time in format:         - $date_beg
                     YYYY-MM-DDTHH:MM
    -e, --date_end - date and time in format:         - $date_end
                     YYYY-MM-DDTHH:MM
    -l, --log_dir  - OS path for output files         - $log_dir
    -v, --version  - current version                  - $script_version
    -h, --help     - show this help

    Example:
    $script -b 2025-01-01T01:00 -e 2025-01-01T01:10
    The work log is saved to the path:
    /home/gpadmin/gpAdminLogs/${module}_$(date +%Y%m%d).log
  "
}


func_get_arguments() {  # write arguments from CLI into variables
  # if no argues, then show help and exit
  [[ ${#argv[@]} < 1 ]] && argv[0]="--help"

  for (( i = 0; i < ${#argv[@]}; i++ )); do
    case ${argv[$i]} in
    "-b" | "--date_beg" )       if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  date_beg="${argv[$i+1]}"
                                fi;;
    "-e" | "--date_end" )       if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  date_end="${argv[$i+1]}"
                                fi;;
    "-l" | "--log_dir" )        if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  log_dir="${argv[$i+1]}"
                                fi;;

    "-v" | "--version" )        echo $script_version; exit 0;;
    "-h" | "--help" )           func_show_help; exit 0;;
    esac
  done
  func_check_date
}


func_check_date() {  # проверяет дату начала и дату завершения:
  date1=$(echo -n $date_beg | grep -oE "[0-9]{4}-[0,1][0-9]-[0-3][0-9]")
  date2=$(echo -n $date_end | grep -oE "[0-9]{4}-[0,1][0-9]-[0-3][0-9]")
  echo "date_beg = $date1"
  echo "date_end = $date2"
  
  if [[ $date1 != $date2 ]]; then
    echo "Даты должны совпадать!"
    echo "Утилита $module может собирать логи только за одни сутки"
    exit 1
  else
    date=$date1
  fi
}


func_prepare() {     # подготовка
  mkdir -p $log_dir
  mkdir -p $tmp_path
  echo "Каталог для временных файлов:"
  ls -ld $tmp_path
}


func_get_arrays() {  # получение массивов переменных
  query1="SELECT content
            FROM gp_segment_configuration
           WHERE role = 'p'
           ORDER BY content"
  query2="SELECT datadir||'/pg_log'
            FROM gp_segment_configuration
           WHERE role = 'p'
           ORDER BY content"
  query3="SELECT hostname
            FROM gp_segment_configuration
           WHERE role = 'p'
           ORDER BY content"

  segno=( $($PSQL -c "$query1") );
  paths=( $($PSQL -c "$query2") );
  hosts=( $($PSQL -c "$query3") );
}


func_ssh() {  # gets logs from segments via ssh
  for (( i = 0; i < ${#hosts[@]}; i++ )); do
    output_path=/tmp/gplog_${hosts[$i]}_seg${segno[$i]}-${date}.csv.gz
    echo "  ---"
    echo "Собираем лог с хоста ${hosts[$i]} сегмент gpseg${segno[$i]}:"
    ssh ${hosts[$i]} -p 22 -q -T << EOF
      source /usr/lib/gpdb/greenplum_path.sh;
      gplogfilter -b "${date_beg}" -e "${date_end}" \
      -o $output_path \
      ${paths[$i]}/gpdb-${date}*
EOF
    echo "  ---"
    echo "Копируем с хоста ${hosts[$i]}:"
    echo "сегмент gpseg${segno[$i]} на мастер в ${tmp_path}."
    gpscp -h ${hosts[$i]} \
      =:$output_path ${tmp_path}
  done
  echo "  ---"
  echo "Удалим с сегментов собранные временные файлы логов:"
  gpssh -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts \
    "rm -f /tmp/gplog_*"
}


func_compress() {  # сжимаем логи в архив
  echo "Список собранных логов:"
  ls -l ${tmp_path}
  echo log_dir=${log_dir}
  echo script_name=${script_name}
  echo tmp_path=${tmp_path}
  echo "tar cfz ${log_dir}/${script_name}.tar.gz ${tmp_path}"
  tar Pcfz ${log_dir}/${script_name}.tar.gz ${tmp_path} && \
    rm -rf ${tmp_path}
  chmod 0666 ${log_dir}/${script_name}.tar.gz
  echo "  ---"
  echo "Архивный файл с логами:"
  ls -1l ${log_dir}/${script_name}.tar.gz
}


func_main
exit 0
