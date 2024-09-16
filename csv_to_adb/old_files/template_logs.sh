#!/bin/bash
# Скопировать файлы из gpdb в каталог:
gplogfilter -b "2023-09-07" -e "2023-10-01" -f "Фильтр-слово" -o /tmp/gplogfilter-2023-09.csv.gz $MASTER_DATA_DIRECTORY/pg_log/gpdb-2023-09-*.csv.gz
chmod 0666 /tmp/gplogfilter-2023-09.csv.gz
ls -lh /tmp/gplogfilter-2023-09.csv.gz

gzip -c $MASTER_DATA_DIRECTORY/pg_log/startup.log > /tmp/startup.log.gz
chmod 0666 /tmp/startup.log.gz
ls -lh /tmp/startup.log.gz

tar cfz /tmp/operation_log.tar.gz -C /home/gpadmin/arenadata_configs operation_log
chmod 0666 /tmp/operation_log.tar.gz
ls -lh /tmp/operation_log.tar.gz

tar cfz /tmp/gpAdminLogs.tar.gz -C /home/gpadmin gpAdminLogs
chmod 0666 /tmp/gpAdminLogs.tar.gz
ls -lh /tmp/gpAdminLogs.tar.gz


gplogfilter -b "2024-03-26T05:00:00" -e "2024-03-26T06:00:00" -o /tmp/gplogfilter-2024-03-26.csv.gz $MASTER_DATA_DIRECTORY/pg_log/gpdb-2024-03-26*.csv.gz

gplogfilter -b "2024-04-18T18:00:00" -e "2024-04-18T22:00:00" -f "idl.bbridge_entry" -o /tmp/gplogfilter-2024-03-26.csv.gz /a/INC/INC0019598/tmp/INC0019598/gpdb-2024-04-18_{1,2}*.csv.gz

exit 0


# Поиск на мастере:
gplogfilter -b "2024-02-09T09:00" -e "2024-02-09T12:00" -o /tmp/gplogfilter-2024-02-09.csv.gz $MASTER_DATA_DIRECTORY/pg_log/gpdb-2024-02-09*.csv

# Поиск на сегменте который повис "намертво":
gpssh -h i148-ADBP-SRV-05 'source /usr/lib/gpdb/greenplum_path.sh; logfilter -b "2024-02-09T09:00" -e "2024-02-09T12:00" -o /tmp/gplogfilter-gpseg98-2024-02-09.csv.gz /data/primary/gpseg98/pg_log/gpdb-2024-02-09*.csv'
gpscp -h avas-dws1 =:/tmp/gplogfilter-gpseg98-2024-02-09.csv.gz /tmp
ls /tmp/gplogfilter-gpseg98-2024-02-09.csv.gz


#~ gpssh -h avas-dws1 'source /usr/lib/gpdb/greenplum_path.sh; gplogfilter -b "2024-02-09T09:00" -e "2024-02-09T12:00" -o /tmp/gplogfilter-gpseg98-2024-02-09.csv.gz /data1/primary/gpseg1/pg_log/gpdb-2024-02-09*.csv'


# /var/log/messages - от пользователя root:
grep -h "Dec 30 " /var/log/messages* | gzip -c > /tmp/messages_2023-12-30_$(hostname).log.gz
chown gpadmin:gpadmin /tmp/messages_2023-12-30_$(hostname).log.gz
# на мастер-ноде от пользователя gpadmin:
gpscp -h p0dtpl-ad2034xp =:/tmp/messages_2023-12-30_p0dtpl-ad2034xp.lop.gz /tmp
#~ gpscp -h avas-dws1 =:/tmp/messages_2023-12-30_$(hostname).log.gz /tmp



# сбор SAR-отчётов
mkdir -p /home/gpadmin/Work/INC0019196/sar_logs
gpssh -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts "mkdir /tmp/sar_20240315_18"
gpssh -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts 'tar -czf /tmp/sar_20240315_18/sa_$(hostname).tar.gz /var/log/sa/sa15 /var/log/sa/sa16 /var/log/sa/sa17 /var/log/sa/sa18'
gpscp -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts =:/tmp/sar_20240315_18/sa* /home/gpadmin/Work/INC0019196/sar_logs


