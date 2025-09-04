#!/bin/bash

# DESCRIPTION -------------------------------------------------------- #
# adbmt is an analogue of the gpmt utility

## Defining global variables ---------------------------------------- ##

script_version=0.3                    # script version
script=$(readlink -f $0)              # full path to script
current_path=$(dirname $script)       # catalog where script is located
module="$(basename $script)"          # scripts file name
scrpt_fn=${module%".sh"}              # scriptname without .sh
declare -a argv=( $* )                # puts argues from CLI into array
LOG_FILE=$current_path/$scrpt_fn.log  # path to directory log filename

# TODO: отрегулировать различные exit. Если внутри функции - то return.

func_make_dtm() {  # add date time to every line in $LOG_FILE
  while IFS= read -r line; do
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $line"
  done
}


## BEGIN: Default Settings ------------------------------------------ ##
dbname=adb
dbuser=gpadmin
PATH_ARENADATA_CONFIGS="${PATH_ARENADATA_CONFIGS:-}"
all_hosts=$PATH_ARENADATA_CONFIGS/arenadata_all_hosts.hosts
master_host=$(hostname -f)
start=$(date -d '1 hour ago' '+%Y-%m-%d_%H:%M')
end=$(date '+%Y-%m-%d_%H:%M')
free_spc=10
adbmt_tmp=/tmp

## END: Default Settings -------------------------------------------- ##
## END: Defining global variables ----------------------------------- ##


func_main() {  # main function: invokes another functions
  func_get_arguments
  func_check_arguments
  func_prepare
  func_check_ssh
  func_start_tool
  func_pack_to_tar_gz
}


func_show_help(){  # show using help
  eval "echo \"$(< $current_path/adbmt.ru.help)\""
  exit 0
}


func_get_arguments() {  # writes into variables argues from CLI
  [[ ${#argv[@]} < 1 ]] && argv[0]="-help"  # if no argues, then show help

  for (( i = 0; i < ${#argv[@]}; i++ )); do
    case ${argv[$i]} in

    # tools:
    gp_log_collector )          tool="${argv[$i]}";;
    # "analyze_session" )         tool="${argv[$i]}";; # not ready et

    # arguments:
    -dir )                      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  adbmt_tmp="${argv[$i+1]}"
                                fi;;
    -log )                      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  LOG_FILE="${argv[$i+1]}"
                                fi;;
    -start )                    if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  start="${argv[$i+1]}"
                                fi;;
    -end )                      if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  end="${argv[$i+1]}"
                                fi;;
    -all-hosts)                 if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  all_hosts="${argv[$i+1]}"
                                fi;;
    -gpseg )                    if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  gpseg="${argv[$i+1]}"
                                fi;;
    -1 )                        gpseg=-1;;
    -free-space )               if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  free_spc="${argv[$i+1]}"
                                fi;;
    -pxf )                      pxf=true;;
    -gpperfmon )                gpperfmon=true;;
    -adbmon )                   adbmon=true;;
    -t_audit_top )              t_audit_top=true;;
    -db )                       if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  dbname="${argv[$i+1]}"
                                fi;;
    -dbuser )                   if [[ ${argv[$i+1]:0:1} != "-" ]]; then
                                  dbuser="${argv[$i+1]}"
                                fi;;
    version )                   echo $script_version; exit 0;;
    -help | --help )            func_show_help; exit 0;;
    esac
  done
}


func_check_arguments() {  # check correctness the choice of options
  if [[ -n $gpseg ]]; then
    func_parse_gpseg
  fi

  # По умолчанию база данных $dbname определена как adb
  # if [[ $adbmon == "true" ]] || [[ $t_audit_top == "true" ]]; then
      # if [ -z "$dbname" ]; then
          # echo "ERROR: -dbname option is not defined"
          # echo "You need determine the database where adbmon schema is located."
          # exit 5
      # fi
  # fi

  func_start_end_validation  # $start and $end validation

  if [[ ! -f $all_hosts ]]; then  # check all_hosts file validation
    echo "ERROR: No such file, defined in -all-hosts option:"
    echo "$all_hosts"
    echo "HINT: define option -all-hosts <FILENAME>
    Full path to a file listing all Arenadata DB cluster hostnames.
    If the file is not specified, the default file is:
    /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts"
    if [ -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts ]; then
      hostfile=/home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts
      echo "Your cluster has this file here:"
      echo $hostfile
    fi
    exit 5
  fi

}


func_parse_gpseg() {  # Get from $gpseg values for $seg_role and $seg_num
  local s="$gpseg"

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
    echo "ERROR: Incorrect -gpseg: $s (expected -1 | N | pN | mN)"
    exit 1
  fi

  if [[ "$seg_role" != "master" ]]; then
    if [[ ! "$seg_num" =~ ^[0-9]+$ ]]; then
      echo "ERROR: for primary/mirror -gpseg must be >= 0"
    fi
  else
    if [[ ! "$seg_num" == "-1" ]]; then
      echo "ERROR: For master-node use value -gpseg -1"
    fi
  fi
}


func_start_end_validation() {  # $start and $end validation
  echo "--- Check dtm format validation ---"
  fmt='^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])_([01][0-9]|2[0-3]):[0-5][0-9]$'

  for v in start end; do
    val=${!v}
    # if [[ $val =~ $fmt ]] && [[ $(date -d "${val/_/ }" '+%F_%T' 2>/dev/null) == "$val" ]]; then
    if [[ $val =~ $fmt ]] && \
       [[ $(date -d "${val/_/ }" '+%Y-%m-%d_%H:%M' 2>/dev/null) == "$val" ]];
    then
      true  # format OK.
    else
      echo "Incorrect format: $v='$val'"
      exit 5
    fi
  done

  s=$(date -d "${start/_/ }" +%s); e=$(date -d "${end/_/ }" +%s)
  if (( s < e )); then
    echo 'OK: time format is correct: "start" is before "end"'
    echo "start: $start"
    echo "end: $end"
  else
    echo 'ERROR: "start" must be before "end"'
    echo "start: $start"
    echo "end: $end"
    exit 5
  fi
}


func_prepare() {  # prepare before getting data
  # redirect script standart output to log file:
  [[ ${#argv[@]} < 1 ]] || exec > >(func_make_dtm | tee -a "$LOG_FILE") 2>&1
  echo "--- START LOG ---"
  echo "Starting $module with args:"
  echo "$script ${argv[*]}"
  echo "Script version: $script_version"
  echo "Log file:"
  echo $LOG_FILE

  start_date=$(date +%Y-%m-%d_%H-%M-%S)
  if [[ -n $gpseg ]]; then
    adbmt_dir="${adbmt_tmp}/$scrpt_fn/${seg_role}_gpseg${seg_num}"
  else
    adbmt_dir="${adbmt_tmp}/$scrpt_fn/$start_date"
  fi

  # check that current user is match the DBMS Cluster owner
  if [[ $MASTER_DATA_DIRECTORY == "" ]]; then
    echo "ERROR: variable \$MASTER_DATA_DIRECTORY is empty"
    echo "The current user is: " $USER
    echo "The DBMS user is: " $dbms_user
    exit 42
  fi
  dbms_user=$(ls -ld $MASTER_DATA_DIRECTORY | awk '{print $3}')
  if [[ $USER != $dbms_user ]]; then
    echo "ERROR: The current user does not match the DBMS system owner user!"
    echo "The current user is: " $USER
    echo "The DBMS user is: " $dbms_user
    exit 42
  fi

  mkdir -p $adbmt_dir
  if [[ $? == 0 ]]; then
    echo "Directory for collected information: "$adbmt_dir
  else
    echo "Can not create directory: "$adbmt_dir
    exit 127
  fi

  echo -n > $adbmt_dir/available_hosts.hosts && \
    echo "File created: $adbmt_dir/available_hosts.hosts"

  # if psql_exit_code is not zero - we have no connections to ADB.
  # Therefore, we will not collect files that require a psql session.
  echo "--- Testing psql connection to Database: ---"

  result=$(
           psql "
                 dbname=template1           \
                 user=$dbuser               \
                 application_name=$scrpt_fn \
                 connect_timeout=10         \
                 options='
                          -c gp_resource_group_bypass=true          \
                          -c gp_resource_group_queuing_timeout=1min \
                          -c statement_timeout=1min                 \
                          -c gp_interconnect_type=tcp               \
                         ' \
                "          \
                -t 2>&1    \
                -f $current_path/adbmt_queue.sql
  )

  psql_exit_code=$?
  if [[ $psql_exit_code == 0 ]]; then
    echo "Connection to DBMS is OK."
    echo -ne "$result"
    echo "---"
  else
    echo "Connection to DBMS failed with an error:"
    echo "$result"
  fi
  echo "psql exit code: $psql_exit_code"
}


func_check_ssh() { # check SSH to hosts from file $all_hosts
  SSH_TIMEOUT="${SSH_TIMEOUT:-5}"     # ssh connection timeout in sec
  SSH_PORT="${SSH_PORT:-22}"          # SSH port
  SSH_OPTS=(
    -p "$SSH_PORT"
    -o BatchMode=yes
    -o ConnectTimeout="$SSH_TIMEOUT"
    -o ConnectionAttempts=1
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
  )
  local fail=0
  hsts_arr=( $(cat $all_hosts) )

  echo "--- Testing SSH-connection to DBMS hosts: ---"
  for (( i = 0; i < ${#hsts_arr[@]}; i++ )); do
    if func_run_ssh ${hsts_arr[$i]}; then
      printf 'SSH-connection is OK to host: %s\n' "${hsts_arr[$i]}"
      echo "${hsts_arr[$i]}" >> $adbmt_dir/available_hosts.hosts
    else
      printf 'FAIL: no ssh-connection to host: %s\n' "${hsts_arr[$i]}"
      echo "${hsts_arr[$i]}" >> $adbmt_dir/unavailable_hosts.hosts
      ((fail++))
    fi
  done

  all_hosts=$adbmt_dir/available_hosts.hosts
  echo "--- File contents $adbmt_dir/available_hosts.hosts ---"
  cat $adbmt_dir/available_hosts.hosts
  echo "---"
}


func_run_ssh() {  # run ssh session with segment host
  local host="$1"

  if command -v timeout >/dev/null 2>&1; then
    timeout "$((SSH_TIMEOUT + 3))"s \
      ssh -q "${SSH_OPTS[@]}" "$host" true </dev/null
  else
    ssh -q "${SSH_OPTS[@]}" "$host" true </dev/null
  fi
}


func_start_tool() {  # start function from "tool" argument:
  if [[ $tool != "" ]]; then
    local exec_func="func_${tool}"
  else
    local exec_func="func_gp_log_collector"
  fi
  echo "--- Executing tool ${tool}... ---"
  $exec_func
}


func_gp_log_collector() {  # gp_log_collector tool

  if [[ -n $gpseg ]]; then

    # get log-files from master or from segment
    bash ${current_path}/adbmt_pg_log.sh $start $end ${adbmt_dir} \
      -gpseg $gpseg -free-space $free_spc -all-hosts $all_hosts
    pg_log_result=$?
    echo "Script adbmt_pg_log.sh finished."
    if (( pg_log_result != 0 )); then
      echo "Errors occurred while copying log files, check file: "$LOG_FILE
      exit 10
    fi

  else

    # get basic diagnostics: OS-utilities out, config-files and logs
    func_get_dynamic_data 1         # 1 snapshot of dynamic data
    func_get_static_data            # get static data
    if [[ $pxf == "true" ]]; then
      if [[ -d $PXF_HOME ]]; then
        func_get_pxf_logs             # get pxf logs from all cluster
        func_get_pxf_conf             # get pxf conf from all cluster
      else
        echo "The directory \$PXF_HOME is missing."
        echo "PXF logs and configs have not collected."
      fi
    fi
    if [[ $adbmon = "true" ]] || [[ $t_audit_top = "true" ]]; then
      func_get_adbmon               # get data from adbmon
    fi
    if [[ $gpperfmon = "true" ]]; then
      func_get_gpperfmon            # get info from gpperfmon database tables
    fi

    func_get_dynamic_data 2         # 2 snapshot of dynamic data

  fi
}


func_get_dynamic_data() {  # dynamic data gathering
  local dtm=$(date +%Y-%m-%d_%H-%M-%S)
  local snp=$1

  echo "--- Getting dynamic data. Snapshot: ${snp}, dtm: ${dtm} ---"
  func_get_ps        $snp $dtm
  func_get_ifconfig  $snp $dtm
  func_get_netstat_s $snp $dtm
  if [[ $psql_exit_code == 0 ]]; then   # psql-scripts execution:
    echo "--- Getting dynamic SQL-queries ---"
    psql "
          dbname=$dbname             \
          user=$dbuser               \
          application_name=$scrpt_fn \
          connect_timeout=10         \
          options='
                   -c gp_resource_group_queuing_timeout=1min \
                   -c statement_timeout=1min                 \
                   -c gp_interconnect_type=tcp               \
                  ' \
         "          \
         -v adbmt_dir="${adbmt_dir}" \
         -v snp="${snp}" \
         -f $current_path/adbmt_psql_dynamic.sql

    # psql "dbname=$dbname user=$dbuser application_name=$scrpt_fn" \
         # -v adbmt_dir="${adbmt_dir}" -v snp="${snp}" \
         # -f $current_path/adbmt_psql_dynamic.sql
  fi
}


func_get_static_data() {  # static data gathering
  echo "--- Getting static data ---"
  if [[ $psql_exit_code == 0 ]]; then   # psql-scripts execution:
    echo "--- Getting static SQL-queries ---"
    psql "
          dbname=$dbname             \
          user=$dbuser               \
          application_name=$scrpt_fn \
          connect_timeout=10         \
          options='
                   -c gp_resource_group_queuing_timeout=1min \
                   -c statement_timeout=1min                 \
                   -c gp_interconnect_type=tcp               \
                  ' \
         "          \
         -v adbmt_dir="${adbmt_dir}" \
         -f $current_path/adbmt_psql_static.sql

    # psql "dbname=$dbname user=$dbuser application_name=$scrpt_fn" \
         # -v adbmt_dir="${adbmt_dir}" \
         # -f $current_path/adbmt_psql_static.sql

  fi
  func_get_adb_service_logs             # get some different service logs
  func_get_different_os_files           # os-release, sysctl, etc
  func_get_startup                      # get startup.log from all cluster
  func_get_sar                          # get sar files from all cluster
  func_mtu_9000                         # test MTU 9000 Packet throughput
  func_get_postgresql_conf              # get postgresql.conf
}


func_mtu_9000() {  # test MTU 9000 packet throughput
  local host
  local mtu=9000

  echo "Getting Packet throughput from segments to master:"
  gpssh -f $all_hosts \
    "echo \"--- FROM \$(hostname):\"; \
     date; \
     ping -c 10 -i 0.2 -M do -s $((mtu - 28)) $(hostname); \
     echo ---" | \
    gzip -f > ${adbmt_dir}/test_ping_to_master.log.gz
  echo "Result file:"
  ls -1d ${adbmt_dir}/test_ping_to_master.log.gz

  echo "Getting Packet throughput from master to segments:"
  for host in $(cat $all_hosts); do
    (
     date;
     ping -c 10 -i 0.2 -M do -s $((mtu - 28)) $host 2>&1;
     echo ---
    ) | \
      gzip -f >> ${adbmt_dir}/test_ping_from_master.log.gz
  done
  echo "Result file:"
  ls -1d ${adbmt_dir}/test_ping_from_master.log.gz
}


func_get_ps() {  # get "ps axuww" from all cluster to csv
  local snp=$1     # snapshot
  local fn_dtm=$2  # date and time
  local path=${adbmt_dir}/${snp}.ps_axuww_${fn_dtm}.csv

  echo "Getting ps axuww to ${path}.gz"
  gpscp -f $all_hosts $current_path/ps_axuww.sh =:/tmp/
  gpssh -f $all_hosts "bash /tmp/ps_axuww.sh" > ${path}
  sed -i 's/^\[\([^]]*\)\] \(.*\)/"\1",\2/'     ${path}
  gzip -f ${path}
  gpssh -f $all_hosts "rm /tmp/ps_axuww.sh && \
    echo 'Temp file /tmp/ps_axuww.sh was successfully deleted.'"

  echo "Result file:"
  ls -1d ${path}.gz
}


func_get_ifconfig() {  # get ifconfig from all cluster
  local snp=$1         # snapshot
  local fn_dtm=$2      # date and time
  local path=${adbmt_dir}/${snp}.ifconfig_${fn_dtm}.log.gz

  echo "Getting ifconfig to $path"
  gpssh -s -f $all_hosts \
    "hostname; /sbin/ifconfig" 2>&1 | \
    cut -d' ' -f2- | \
    gzip -f > $path

  echo "Result file:"
  ls -1 $path
}


func_get_netstat_s() {  # get "netstat -s" from all cluster
  # Explanation:
  # In case of "interconnect error" errors,
  # it makes sense to request UDP and TCP statistics for errors:
  # TCP and UDP errors will increase dynamically.

  local snp=$1          # snapshot
  local fn_dtm=$2       # date and time
  local path=${adbmt_dir}/${snp}.netstat-s_${fn_dtm}.log.gz

  echo "Getting netstat -s to $path"
  gpssh -f $all_hosts "netstat -s" | \
    gzip -f > $path

  echo "Result file:"
  ls -1 $path
}


func_get_adb_service_logs() {  # get some different service logs
  echo "Getting adb_collected_info diagnostic:"
  bash $PATH_ARENADATA_CONFIGS/adb_collect_info.sh
  gzip -f /tmp/adb_collected_info.txt
  mv /tmp/adb_collected_info.txt.gz ${adbmt_dir}

  echo "Getting gpAdminLogs from master for the last 7 days and all gpconfig_*:"
  echo "${adbmt_dir}/gpAdminLogs_$(date +%Y%m%d).tar.gz"
  cd /home/gpadmin
  { # get all files for last 7 days *.log + all gpconfig_*
    find gpAdminLogs -type f -name "*.log" -mtime -7
    find gpAdminLogs -type f -name "gpconfig_*"
  } | tar cfz "${adbmt_dir}/gpAdminLogs_$(date +%Y%m%d).tar.gz" \
          -C /home/gpadmin --files-from=-
  cd - 1>/dev/null

  echo "Getting operation_log:"
  echo "${adbmt_dir}/operation_log.tar.gz"
  tar cfz ${adbmt_dir}/operation_log.tar.gz \
    -C $PATH_ARENADATA_CONFIGS operation_log

  echo "Getting analyzedb working log from master data dir:"
  echo "${adbmt_dir}/db_analyze.tar.gz"
  tar Pcfz ${adbmt_dir}/db_analyze.tar.gz \
    -C $MASTER_DATA_DIRECTORY db_analyze
}


func_get_startup() {  # get startup.log from all cluster
  local tar_dir=startup_${start_date}
  mkdir -p /tmp/${tar_dir}

  # This terrible code below "sed" utility makes line within scp
  # in order to send startup.log file from segments to coordinator.
  # scp command line will be like this, for example:
  # scp /data1/primary/gpseg0/pg_log/startup.log master_hostname:/tmp/tar_directory/segment_hostname.primary.gpseg0.startup.log

  echo "--- Getting startup.log files from all cluster ---"
  gpssh -f $all_hosts -s << EOF
    find / -xdev \
    \( -path /proc -o -path /sys -o -path /run -o -path /dev \) -prune -o \
    -type f -regextype posix-extended \
    -regex '.*/(master|mirror|primary)/gpseg-?[0-9]+/pg_log/startup\.log' \
    -print 2>/dev/null | \
    sed "s/^/\$(hostname):/" | \
    sed -E "s#([^:]+):(/(.+)/(master|primary|mirror)/gpseg[-]?([0-9]+)/pg_log/(startup.log))#scp \2 ${master_host}:/tmp/${tar_dir}/\1.\4.\5.\6#" | \
    while read cmd; do eval "\$cmd"; done
EOF

  func_make_tar_and_del_tmp_dir ${tar_dir}
}


func_get_pxf_logs() {  # get pxf logs from all cluster
  local tar_dir=pxf_logs_${start_date}
  mkdir -p /tmp/${tar_dir}

  echo "--- Getting PXF logs from all cluster ---"
  gpssh -f $all_hosts \
    "tar cfz /tmp/${tar_dir}_\$(hostname).tar.gz -C \$PXF_BASE logs"
  gpscp -f $all_hosts =:/tmp/${tar_dir}*.tar.gz /tmp/${tar_dir}

  func_make_tar_and_del_tmp_dir ${tar_dir}

  gpssh -f $all_hosts "rm /tmp/pxf_logs_*.tar.gz && \
    echo 'The temp archives pxf_logs_*.tar.gz was successfully removed.'"
}


func_get_pxf_conf() {  # get pxf conf from all cluster
  local tar_dir=pxf_conf_${start_date}
  mkdir -p /tmp/${tar_dir}

  echo "--- Getting PXF conf files from all cluster ---"
  gpssh -f $all_hosts \
    "tar cfz /tmp/${tar_dir}_\$(hostname).tar.gz -C \$PXF_BASE conf"
  gpscp -f $all_hosts =:/tmp/${tar_dir}*.tar.gz /tmp/${tar_dir}

  func_make_tar_and_del_tmp_dir ${tar_dir}

  echo "Removing temporary files:"
  gpssh -f $all_hosts "rm /tmp/pxf_conf_*.tar.gz && \
    echo 'The temp archives pxf_conf_*.tar.gz was successfully removed.'"
}


func_get_sar() {  # get sar files from all cluster
  local tar_dir=sar_$start_date
  mkdir -p /tmp/$tar_dir

  echo "--- Getting sar files from all cluster ---"
  # Variable to get on a specific date of the month. For example:
  day="sa*"  # in order to get on the 5th, set "sa05"

  # Find sar directory:
  # In CentOS variable SA_DIR will be empty
  SA_DIR=$(grep SA_DIR /etc/sysconfig/sysstat 2>/dev/null || \
    grep SA_DIR /etc/sysstat/sysstat 2>/dev/null)
  SA_DIR="${SA_DIR//SA_DIR=/}"

  # set value for CentOS:
  if [[ $SA_DIR == "" ]]; then
    if [[ -d /var/log/sa ]]; then
      SA_DIR=/var/log/sa
    else
      echo "sar's directory not found" && return 127
    fi
  fi

  echo "sar directory is: "$SA_DIR

  gpssh -f $all_hosts \
    "tar Pcfz /tmp/sar_\$(hostname).tar.gz $SA_DIR/${day}; \
    ls -1 /tmp/sar_\$(hostname).tar.gz"

  gpscp -f $all_hosts =:/tmp/sar_*.tar.gz /tmp/$tar_dir

  tar Pcfz $adbmt_dir/$tar_dir.tar.gz /tmp/$tar_dir
  echo "Removing temp files:"
  gpssh -f $all_hosts "rm -rf /tmp/sar_*.tar.gz && \
    echo 'Temp file /tmp/sar_*.tar.gz was successfully removed.'"
  echo "Result file:"
  ls -1d $adbmt_dir/$tar_dir.tar.gz
}


func_get_different_os_files() {  # os-release, sysctl, utilites, etc
  echo "Getting OS version to ${adbmt_dir}/os-release.log.gz"
  gpssh -f $all_hosts "tail -n +1 -v /etc/*{-release,_version}" | \
    gzip -f > ${adbmt_dir}/os-release.log.gz
  echo "Getting limits.conf to ${adbmt_dir}/limits_conf.log.gz"
  gpssh -f $all_hosts "cat /etc/security/limits.conf" | \
    gzip -f > ${adbmt_dir}/limits_conf.log.gz
  echo "Getting sysctl.conf to ${adbmt_dir}/sysctl_conf.log.gz"
  gpssh -f $all_hosts "cat /etc/sysctl.conf" | \
    gzip -f > ${adbmt_dir}/sysctl_conf.log.gz
  echo "Getting sysctl -a to ${adbmt_dir}/sysctl-a.log.gz"
  gpssh -f $all_hosts "sysctl -a"   | gzip -f > ${adbmt_dir}/sysctl-a.log.gz
  echo "Getting netstat -rn to ${adbmt_dir}/netstat-rn.log.gz"
  gpssh -f $all_hosts "netstat -rn" | gzip -f > ${adbmt_dir}/netstat-rn.log.gz
  echo "Getting netstat -i to ${adbmt_dir}/netstat-i.log.gz"
  gpssh -f $all_hosts "netstat -i"  | gzip -f > ${adbmt_dir}/netstat-i.log.gz
  echo "Getting uname -a to ${adbmt_dir}/uname-a.log.gz"
  gpssh -f $all_hosts "uname -a"    | gzip -f > ${adbmt_dir}/uname-a.log.gz
  echo "Getting dmesg -T to ${adbmt_dir}/dmesg-T.log.gz"
  gpssh -f $all_hosts "dmesg -T"    | gzip -f > ${adbmt_dir}/dmesg-T.log.gz
  echo "Getting last-adFwx to ${adbmt_dir}/last-adFwx.log.gz"
  gpssh -f $all_hosts "last -adFwx" | gzip -f > ${adbmt_dir}/last-adFwx.log.gz
  echo "Getting hostnamectl to ${adbmt_dir}/hostnamectl.log.gz"
  gpssh -f $all_hosts "(hostname; hostnamectl; echo)" | \
    gzip -f > ${adbmt_dir}/hostnamectl.log.gz

  echo "Getting pg_controldata information from master node to file:"
  echo "${adbmt_dir}/pg_controldata.log"
  pg_controldata $MASTER_DATA_DIRECTORY > ${adbmt_dir}/pg_controldata.log

  echo "Getting initial configuration ADB file to file:"
  echo "${adbmt_dir}/init_config.conf"
  echo "Init-file from: $PATH_ARENADATA_CONFIGS/init_config.conf"
  cp $PATH_ARENADATA_CONFIGS/init_config.conf ${adbmt_dir}

  echo "Getting stat about postmaster.pid files to file:"
  echo "${adbmt_dir}/postmaster_pid_stat.log.gz"
  (
    gpssh -f $all_hosts << EOF
    find / -xdev \
      \( -path /proc -o -path /sys -o -path /run -o -path /dev \)\
      -prune -o -type f -regextype posix-extended \
      -regex ".*/(master|mirror|primary)/gpseg-?[0-9]+/postmaster\.pid" \
      -print0 2>/dev/null | xargs -0 stat
EOF
  ) 2>&1 | tr -d '\r' | gzip -f >${adbmt_dir}/postmaster_pid_stat.log.gz
}


func_get_postgresql_conf() {  # get postgresql.conf files from all cluster
  local tar_dir=postgresql_conf_${start_date}
  mkdir -p /tmp/${tar_dir}

  echo "--- Getting postgresql.conf files from all segments ---"
  gpssh -f $all_hosts -s << EOF
    find / -xdev \
    \( -path /proc -o -path /sys -o -path /run -o -path /dev \) -prune -o \
    -type f -regextype posix-extended \
    -regex '.*/(master|mirror|primary)/gpseg-?[0-9]+/postgresql\.conf' \
    -print 2>/dev/null | \
    sed "s/^/\$(hostname):/" | \
    sed -E "s#([^:]+):(/(.+)/(master|primary|mirror)/gpseg[-]?([0-9]+)/(postgresql.conf))#scp \2 ${master_host}:/tmp/${tar_dir}/\1.\4.\5.\6#" | \
    while read cmd; do eval "\$cmd"; done
EOF

  func_make_tar_and_del_tmp_dir ${tar_dir}
}


func_make_tar_and_del_tmp_dir() {  # make tar-file and delete obsolete directory
  local tar_dir="$1"

  tar Pcfz ${adbmt_dir}/${tar_dir}.tar.gz -C /tmp ${tar_dir} && \
    echo "Result tar-file was created:" && \
    ls -1d ${adbmt_dir}/${tar_dir}.tar.gz
  rm -rf /tmp/${tar_dir} && \
    echo "The temporary directory /tmp/${tar_dir} was successfully removed."
}


func_get_gpperfmon() {  # get info from gpperfmon database tables
  echo "--- Getting info from gpperfmon database tables ---"

  psql "
        dbname=gpperfmon           \
        user=$dbuser               \
        application_name=$scrpt_fn \
        connect_timeout=10         \
        options='
                 -c gp_resource_group_queuing_timeout=1min \
                 -c statement_timeout=1min                 \
                 -c gp_interconnect_type=tcp               \
                ' \
       "          \
       -v adbmt_dir="${adbmt_dir}" \
       -f $current_path/adbmt_gpperfmon.sql \
       -v begin="$start" \
       -v end="$end"

  # psql "dbname=gpperfmon user=$dbuser application_name=$scrpt_fn" \
       # -f $current_path/adbmt_gpperfmon.sql \
       # -v adbmt_dir="${adbmt_dir}" \
       # -v begin="$start" \
       # -v end="$end"

}


func_get_adbmon() {  # get adbmon quieries from adbmon schema
  echo "--- Getting adbmon-schema tables ---"

  psql "
        dbname=$dbname             \
        user=$dbuser               \
        application_name=$scrpt_fn \
        connect_timeout=10         \
        options='
                 -c gp_resource_group_queuing_timeout=1min \
                 -c statement_timeout=5min                 \
                 -c gp_interconnect_type=tcp               \
                ' \
       "          \
       -v adbmt_dir="${adbmt_dir}" \
       -f $current_path/adbmon_queries.sql \
       -v begin="$start" \
       -v end="$end"

  # psql "dbname=$dbname user=$dbuser application_name=$scrpt_fn" \
       # -f $current_path/adbmon_queries.sql \
       # -v adbmt_dir="${adbmt_dir}" \
       # -v begin="$start" \
       # -v end="$end"

  if [[ $t_audit_top == "true" ]]; then  # get t_audit_top
    echo "--- Getting adbmon.t_audit_top table ---"

    psql "
          dbname=$dbname             \
          user=$dbuser               \
          application_name=$scrpt_fn \
          connect_timeout=10         \
          options='
                   -c gp_resource_group_queuing_timeout=1min \
                   -c statement_timeout=5min                 \
                   -c gp_interconnect_type=tcp               \
                  ' \
         "          \
         -v adbmt_dir="${adbmt_dir}" \
         -f $current_path/adbmon_t_audit_top.sql \
         -v begin="$start" \
         -v end="$end"

     # psql "dbname=$dbname user=$dbuser application_name=$scrpt_fn" \
          # -f $current_path/adbmon_t_audit_top.sql \
          # -v adbmt_dir="${adbmt_dir}" \
          # -v begin="$start" \
          # -v end="$end"
  fi
}


func_pack_to_tar_gz() {  # pack diagnostic data to tar.gz archive
  if [[ -n $gpseg ]]; then
    tar_fn=${scrpt_fn}_${seg_role}_gpseg${seg_num}  # packing logs from pg_log
  else
    tar_fn=${scrpt_fn}_${start_date}                # packing diagnostic data
  fi

  echo "--- Packing diagnostic data to tar.gz ---"
  echo "File: ${adbmt_tmp}/${tar_fn}.tar.gz"

  sleep 1
  cp $LOG_FILE ${adbmt_dir}  # copying adbmt log-file to diagnostic pack

  cd ${adbmt_dir}
  tar Pcfz "${adbmt_tmp}/${tar_fn}.tar.gz" *
  result=$?
  cd - 1>/dev/null

  echo "tar utility exit code: "$result
  if [[ $result == 0 ]]; then
    echo "The resulting tar-file was successfully created:"
    echo "${adbmt_tmp}/${tar_fn}.tar.gz"
    ls -lh "${adbmt_tmp}/${tar_fn}.tar.gz"
    rm -rf $adbmt_dir
    if [[ $? == 0 ]]; then
      echo "Temp directory $adbmt_dir was successfully removed."
    else
      echo "Failed to delete directory: "$adbmt_dir
    fi
  fi
  echo "${module} script execution log-file:"
  echo $LOG_FILE
  echo "--- END LOG ---"
}


func_main  # from this point script starts running
exit 0



2025-08-26 - version 0.2.: Added several checks:
  - for strange clusters
  - without -all-hosts
  - check for the case when the script is started not under the ADB owner
    (for example, under root).

2025-09-02 - version 0.3.: Added queue check in psql-file: adbmt_queue.sql


# TODO: проверить на убунту выгрузку с мастера
# TODO: проверить на убунту выгрузку с сегмента
# TODO: проверить на Альт выгрузку с мастера и сегмента
# TODO: если в all_hosts менее трех нод, то останавливаем выгрузку.

