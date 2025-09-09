# adbmt (Arenadata DB Magic Tool)

The adbmt utility (Arenadata DB Magic Tool) provides a set of tools for collecting diagnostic information required by Arenadata support.  
The adbmt utility is a approximate analogue of the gpmt utility.

## INSTALLATION:
Copy the adbmt.tar.gz file to the /tmp directory on the master node.  
Unpack the tar.gz archive with the utility using the commands:
```
tar Pxfz /tmp/adbmt.tar.gz -C /tmp
chown -R gpadmin:gpadmin /tmp/adbmt
ls -ld /tmp/adbmt
```

## USAGE:
/tmp/adbmt.sh \<TOOL\> [<TOOL_OPTIONS> ...]

### TOOL:
gp_log_collector  
This is a tool for collecting logs and parameters, necessary for DBMS diagnostics.

## DESCRIPTION:
The gp_log_collector tool can be launched in one of three ways:
  1. collecting DBMS message logs from the master.
  2. collecting DBMS message logs from the segment: primary or mirror.
  3. collecting diagnostic information.  

### More details about these three options:
#### 1. collecting DBMS message logs from the master.  
When collecting DBMS message logs, the utility collects the corresponding files for the period specified by the -start and -end parameters into the working directory on the master node.  
The working directory can be overridden with the -dir parameter.  
By default, this is /tmp.  
When copying, the utility adbmt compresses uncompressed csv-files into a gz-archive.  
When forming a list of files to copy, the "Evaluator" is used.  
The "Evaluator" calculates the required copying volume.  
The list of log-files to copy can take up a significant amount of space.  
The -free-space parameter is used for this.  
The -free-space parameter specifies the threshold percentage of disk space that log-files can occupy.  
If the file's size exceeds this percentage, then the "Evaluator" reports that the threshold has been exceeded, and copying does not occur.  
By default, the -free-space threshold is set to 10%.  
After collecting log-files on the master node, the adbmt utility generates the final tar.gz.  
The name of the resulting tar.gz file will be displayed in the standard output and in the adbmt utility log file.  
For example:
```
/tmp/adbmt_master_gpseg-1.tar.gz
```
To collect DBMS server log files from master, you must specify the -gpseg parameter and set the number to -1.  
Command example:
```
bash /tmp/adbmt/adbmt.sh gp_log_collector -gpseg -1 -start 2015-11-25_09:00 -end 2015-11-25_18:00
```
The current host, where this script is launched considered as master (not standby master).  
If you need get data from standby master, then you need to launch this script on standby master.  

#### 2. выгрузка журналов сообщений СУБД с сегмента: primary или mirror.  
Выгрузка журналов с сегмента происходит аналогично выгрузке с мастера.  
Для сбора необходимо указать параметр -gpseg, задать роль сегмента буквой p (primary) или m (mirror) и указать номер сегмента.    
Например, команда для mirror-сегмента 2:
```
bash /tmp/adbmt/adbmt.sh gp_log_collector -gpseg m2 -start 2015-11-25_09:00 -end 2015-11-25_18:00
```

В самом начале работы утилиты adbmt происходит проверка ssh-соединения с хостами кластера СУБД из списка всех имён хостов кластера ADB.  
Полный путь к файлу со списком всех имён хостов кластера ADB задаётся параметром -all-hosts.  
Если список не задан, то по умолчанию используется файл:
```
/home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts
```
По результатам проверки ssh-соединения создаётся файл хостов, к которым есть доступ по ssh.  
Имя файла: available_hosts.hosts.

#### 3. Сбор диагностической информации состоит из сбора:  
- 3.1. динамической информации - 1-й снимок.
- 3.2. статической информации.
- 3.3. информации PXF (опционально).
- 3.4. информации из базы gpperfmon (опционально). Может быть собрана, если установлен gpperfmon.
- 3.5. информации из схемы adbmon (опционально). Может быть собрана, если установлен adbmon.
- 3.6. динамической информации - 2-й снимок.

3.1. Сбор динамической информации состоит из двух снимков.  
Динамическая информация имеет смысл для оценки её во времени.  
Например, это оценка роста сетевых ошибок, роста потребления ресурсов процессами, ресурсными группами и т.д.  
Собираются такие данные:
  - ps axuww
  - /sbin/ifconfig
  - netstat -s
  - динамические SQL-запросы:
    - gp_toolkit.gp_resgroup_status
    - gp_toolkit.gp_resgroup_status_per_host
    - pg_locks
    - pg_stat_activity

Номер снимка (1-й или 2-й) будет записан вначале файла, например:  
1.ps_axuww_2025-01-01_08-00-00.csv.gz  

3.2. Сбор статической информации состоит из сбора:
  - статические SQL-запросы:
    - gp_server_version
    - postmaster_uptime
    - postmaster_stat
    - gp_resgroup_config
    - pg_database
    - pg_db_role_setting
    - gp_segment_configuration
    - gp_configuration_history
  - логи сервисных утилит ADB и analyzedb:
    - adb_collected_info
    - gpAdminLogs
    - operation_log
    - db_analyze
  - различные конфиг-файлы и вывод утилит ОС:
    - os-release, os-version
    - /etc/security/limits.conf
    - /etc/sysctl.conf
    - sysctl -a
    - netstat -rn
    - netstat -i
    - uname -a
    - dmesg -T
    - last -adFwx
    - hostnamectl
    - pg_controldata
    - init_config.conf
    - /home/gpadmin/arenadata_configs/init_config.conf
    - stat postmaster.pid
  - startup.log
  - sar-файлы
  - postgresql.conf
  - Проверка проходимости пакетов с MTU 9000:
    - test_ping_to_master.log.gz
    - test_ping_from_master.log.gz

3.3. с помощью опции -pxf задаётся дополнительный сбор PXF:
  - конфигураций PXF - pxf_conf_\<TIMESTAMP\>.tar.gz
  - лог-файлов PXF - pxf_logs_\<TIMESTAMP\>.tar.gz

3.4. с помощью опции -gpperfmon задаётся дополнительный сбор из исторических таблиц базы данных gpperfmon:
  - gpperfmon.database_history.csv.gz
  - gpperfmon.diskspace_history.csv.gz
  - gpperfmon.log_alert_history.csv.gz
  - gpperfmon.network_interface_history.csv.gz
  - gpperfmon.queries_history.csv.gz
  - gpperfmon.segment_history.csv.gz
  - gpperfmon.socket_history.csv.gz
  - gpperfmon.system_history.csv.gz

3.5. с помощью опции -adbmon задаётся дополнительный сбор из таблиц схемы adbmon:
  - t_audit_gp_resgroup_status.csv.gz
  - t_audit_gp_resgroup_status_per_seg.csv.gz
  - t_audit_locks_usage.csv.gz
  - t_audit_mem_usage.csv.gz
  - t_audit_pg_stat_activity.csv.gz
  - t_audit_top.csv.gz

3.6. Сбор динамической информации 2-й снимок - это повторный сбор информации, указанной в пункте 3.1.  
Номер снимка будет записан вначале файла, например:
```
2.ps_axuww_2025-01-01_08-10-00.csv.gz
```

Диагностические файлы собираются на мастер-ноду в рабочую директорию указанную параметром -dir.  
После сбора файлов утилита adbmt формирует оконечный tar.gz.  
Имя оконечного tar.gz файла состоит из имени утилиты adbmt и времени запуска утилиты.  
Имя файла будет отображено в стандартном выводе и в лог-файле утилиты adbmt.  
Например:
```
/tmp/adbmt_2025-01-01_08-00-00.tar.gz
```

## TOOL_OPTIONS:
```
TOOL_OPTIONS:                                        - Current values:
  -dir <DIRECTORY>                                   - $adbmt_tmp
    Path to the working directory where temporary files
    will be placed during compilation, as well as the final tar.gz.
    This directory should not have spaces characters in its name.

  -log <FILENAME>                                    - $LOG_FILE
    Full path to the log file of this executable script.
    By default, the path to the log is in the $module script location:
    $LOG_FILE
    The log file is also copied to the final tar.gz file with diagnostics.

  -gpseg <Role_and_ID>
    The segment to unload the DBMS message logs.
    The Role_and_ID value must consist of:
    1. the segment role: p - primary, m - mirror.
    2. the segment number.
    For example: primary segment gpseg10: -gpseg p10
    For the master node the option will be : -gpseg -1

  -start <YYYY-MM-DD_HH:MM>                          - $start
    Start date and time for collecting logs.
    The timestamp must be in the format: YYYY-MM-DD_HH:MM
    Without quotes, spaces between the date and time.
    If the -start time is not specified, then the time is used,
    which was an hour ago before this script was started.

  -end <YYYY-MM-DD_HH:MM>                            - $end
    End date and time for collecting logs.
    The timestamp must be in the format: YYYY-MM-DD_HH:MM
    Without quotes, spaces between the date and time.
    If -end is not specified, then current time is used.

  -all-hosts <FILENAME>
    Full path to a file listing all Arenadata DB cluster hostnames.
    If the file is not specified, the default file is:
    /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts

  -free-space <PERCENT>                              - $free_spc
    The percentage of free space on the partition with
    the working directory -dir, which is allowed to be occupied
    by the collected logs from the master or segments.

  -pxf
    Collect PXF configuration files and logs.

  -gpperfmon
    Collect historical tables information from the gpperfmon DB.

  -adbmon
    Collect information from tables in "adbmon" schema.

  -t_audit_top
    Collect information from the adbmon.t_audit_top table.
    The downloaded file may be very big.
    That's why collecting t_audit_top is a separate parameter.

  -db <DATABASE>                                     - $dbname
    The name of the database where the adbmon schema is located.

  -dbuser <DBUSER>                                   - $dbuser
    Database superuser name. In case it is not gpadmin.

  version                                            - $script_version
    Current version of the programme $module.

  -help
    Show this usage help and exit.
```

## EXAMPLES:
Collecting DBMS message logs from the master node:
```
bash $script gp_log_collector -gpseg -1 -start 2015-11-25_09:00 -end 2015-11-25_18:00
```

Collecting DBMS message logs from the mirror-segment No 2:
```
bash $script gp_log_collector -gpseg m2 -start 2015-11-25_09:00 -end 2015-11-25_18:00
```

Collecting diagnostic information (without PXF, gpperfmon, adbmon):
```
bash $script gp_log_collector
```

Collecting diagnostic information with PXF:
```
bash $script gp_log_collector -pxf
```

Collecting diagnostic with tables from the gpperfmon DB:
```
bash $script gp_log_collector -gpperfmon -start 2025-03-19_18:00 -end 2025-03-19_19:00
```

Collecting diagnostic with tables from the gpperfmon DB and adbmon schema:
```
bash $script gp_log_collector -gpperfmon -adbmon -db dwh -start 2025-03-19_18:00 -end 2025-03-19_19:00
```

Collecting diagnostic with adbmon schema including t_audit_top table:
```
bash $script gp_log_collector -t_audit_top -db dwh -start 2025-03-19_18:00 -end 2025-03-19_19:00
```

It is often necessary to perform several collection varies.  
For example: to collect logs from the master, collect logs from one segment, collect diagnostics.  
In this case, it is necessary to run the adbmt.sh utility several times within different options.  

