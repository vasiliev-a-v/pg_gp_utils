#!/bin/bash


# DESCRIPTION -------------------------------------------------------- #
# adbmt_exec upload script on master node and executes adbmt.sh

host=avas-cdwm1
ssh_user=avas
scr_dir=/p/pg_gp_utils/useful_scripts

func_main() {  # main function
  ssh $ssh_user@$host -q -T << EOF
  sudo su -
  mkdir -p /tmp/adbmt
  chmod -R 777 /tmp/adbmt
EOF

  mv $scr_dir/adbmt.tar.gz $scr_dir/adbmt.tar.gz.old
  tar Pcfz $scr_dir/adbmt.tar.gz -C $scr_dir --exclude=adbmt/draft adbmt

  scp $scr_dir/adbmt.tar.gz $ssh_user@$host:/tmp
  ssh $ssh_user@$host -q -T << EOF
  sudo su -
    whoami
    tar Pxfz /tmp/adbmt.tar.gz -C /tmp
    chown -R gpadmin:gpadmin /tmp/adbmt
    ls -ld /tmp/adbmt
    # exit 0
    # exit 0
    sudo -iu gpadmin
      # whoami
      # bash /tmp/adbmt/adbmt.sh gp_log_collector -g -1 -start 2025-08-01_00:00 -end 2025-08-16_22:00 -free-space 1 -all-hosts $PATH_ARENADATA_CONFIGS/arenadata_all_hosts.hosts
      # bash /tmp/adbmt/adbmt.sh gp_log_collector -g m0 -start 2025-08-16_00:00 -end 2025-08-16_22:00 
      # bash /tmp/adbmt/adbmt.sh gp_log_collector
      # bash /tmp/adbmt/adbmt.sh   \
         # gp_log_collector        \
         # -gpseg -1               \
        # -start 2025-08-16_00:00  \
        # -end   2025-08-16_22:00  \
        # -dir /tmp/test_adbmt_dir \
        # -all_hosts /tmp/t

      bash /tmp/adbmt/adbmt.sh -help | less

      # bash /tmp/adbmt/adbmt.sh gp_log_collector -gpperfmon -pxf -adbmon -t_audit_top -db inc0025383 -start 2025-07-21_00:01 -end 2025-07-21_13:59
      # bash /tmp/adbmt/adbmt.sh gp_log_collector -gpseg m1 -start 2025-07-21_00:01 -end 2025-07-21_13:59

      # TODO: проверить:
      # bash /tmp/adbmt/adbmt.sh gp_log_collector -t_audit_top \
        -db inc0025383 -start 2025-07-20_00:01 -end 2025-07-22_13:59
EOF
}

# 2025-07-21 00:01
# 2025-07-21 13:59


func_main  # from this point script starts running
exit 0






# Код учитывает, что путь до master, primary, mirror может быть любым:
# gpssh -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts "find / -xdev \
  # \( -path /proc -o -path /sys -o -path /run -o -path /dev \) -prune -o \
  # -type d -regextype posix-extended \
  # -regex '.*/(master|mirror|primary)/gpseg[^/]*' \
  # -print 2>/dev/null"


# TODO: сделать сбор от root (??): сложность - заморочка с root
# - sar
# - /var/log messages, kern.log, syslog

# TODO: для опции сбора core-файлов проверять то, что:
# lsof, strace, pstack, gcore, gdb must be installed on all all hosts.
# Если не установлены - то сообщать в логах!
# сбор core-dump процесса, сбор packcore, сбор strace


# lsof, strace, pstack, gcore, gdb must be installed on all $all_hosts.
# https://techdocs.broadcom.com/us/en/vmware-tanzu/data-solutions/tanzu-greenplum/6/greenplum-database/utility_guide-ref-gpmt.html

# gpmt analyze_session
# https://techdocs.broadcom.com/us/en/vmware-tanzu/data-solutions/tanzu-greenplum/6/greenplum-database/utility_guide-ref-gpmt-analyze_session.html


