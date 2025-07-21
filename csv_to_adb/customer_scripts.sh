#!/bin/bash
# copy table from ADB database:

# Нужно выполнить на стороне заказчика из-под gpadmin
# Для оценки ресурсов, пожалуйста выполните и пришлите полученный файл

# --- Стандартный общий набор команд. Пример с gp_resgroup_config:
# gp_resgroup_config
table="gp_toolkit.gp_resgroup_config"
dbname="customer_dbname"  # БД заказчика
psql -q -d $dbname -c "COPY (SELECT * FROM $table) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# --- Разные стандартные таблицы:

table="arenadata_toolkit.daily_operation"
table="gp_configuration_history"
table="gp_segment_configuration"
table="pg_stat_activity"
table="pg_stat_all_tables"
table="pg_stat_operations"
table="gp_toolkit.gp_resgroup_config"
table="gp_toolkit.gp_resgroup_status_per_host"
table="gp_toolkit.gp_resgroup_status_per_segment"
table="pg_stat_last_operation"
table="pg_stat_last_shoperation"
table="pg_statio_sys_tables"


# gp_segment_configuration
table="gp_segment_configuration"
dbname="template1"
psql -q -d $dbname -c "COPY (SELECT * FROM $table) TO PROGRAM 'gzip -f > /tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# gp_configuration_history
table="gp_configuration_history"
dbname="template1"
psql -q -d $dbname -c "COPY (SELECT * FROM $table) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# arenadata_toolkit.db_files_history
table="arenadata_toolkit.db_files_history"
dbname="adb"
psql -q -d $dbname -c "COPY (
  SELECT *
    FROM $table
) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip --force /tmp/$table.csv
chmod 0666   /tmp/$table.csv.gz
ls -lh       /tmp/$table.csv.gz

# arenadata_toolkit.db_files_history для конкретной таблицы
table="arenadata_toolkit.db_files_history"
dbname="ADWH"
psql -q -d $dbname -c "COPY (
  SELECT *
    FROM $table
   WHERE table_schema = 'ao_delivery_times'
     AND table_name   ~ 'delivery_times_rows'
     AND table_name  !~ 'delivery_times_rows_sav'
) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip --force /tmp/$table.csv
chmod 0666   /tmp/$table.csv.gz
ls -lh       /tmp/$table.csv.gz

# -- типовой скрипт (TODO: проверить)
table="pg_stat_operations"
dbname="ADWH"
psql -q -d $dbname -c "COPY (SELECT * FROM $table) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# --- Для gp_resgroup_status
table="gp_resgroup_status"
dbname="customer_dbname"  # БД заказчика
psql -q -d $dbname -c "COPY (SELECT rsgname, num_running, num_queueing, num_queued, num_executed FROM gp_toolkit.gp_resgroup_status) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# --- расширенный вариант для pg_stat_all_tables со всех нод:
table="pg_stat_all_tables"
dbname="ADWH"
psql -q -d $dbname -c "COPY (
SELECT * FROM pg_stat_user_tables WHERE schemaname = 'ao_delivery_times' AND relname = 'delivery_times_rows'
UNION ALL
SELECT * FROM gp_dist_random('pg_stat_user_tables') WHERE schemaname = 'ao_delivery_times' AND relname = 'delivery_times_rows'
) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# --- Для check_data_skew_to_csv
Возможно имеет место перекос данных.
Скопируйте приложенный файл с SQL-запросом
check_data_skew_to_csv.sql в каталог /home/gpadmin/arenadata_configs/
Выполните команды из-под пользователя gpadmin, пришлите полученный файл:

table="check_data_skew_to_csv"
dbname="gpadmin"  # БД заказчика
psql -d $dbname -f /home/gpadmin/arenadata_configs/$table.sql
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz


# --- Для pg_locks
table="pg_locks"
dbname="customer_dbname"  # БД заказчика
psql -q -d $dbname -c "COPY (SELECT * FROM $table) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# --- Для pg_stat_activity
table="pg_stat_activity"
dbname="adb"
psql -q -d $dbname -c "COPY (SELECT * FROM $table) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# --- Для pg_class
table="pg_class"
dbname="customer_dbname"  # БД заказчика
psql -q -d $dbname -c "COPY (SELECT oid, * FROM $table) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz


# -- pg_class с мастера и сегментов:
table="pg_class"
dbname="customer_dbname"  # БД заказчика
psql -q -d $dbname -c "COPY (
SELECT c.gp_segment_id, c.oid, c.*
  FROM pg_class c
  JOIN pg_namespace n
    ON c.relnamespace = n.oid
 WHERE n.nspname = 'public'
   AND c.relname = 'test_table2'
UNION ALL
SELECT c.gp_segment_id, c.oid, c.*
  FROM gp_dist_random('pg_class') c
  JOIN pg_namespace n
    ON c.relnamespace = n.oid
 WHERE n.nspname = 'public'
   AND c.relname = 'test_table2'
) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz



#~ TODO: проработать:
#gpprefmon
COPY (SELECT * FROM database_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/database_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM diskspace_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/diskspace_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM log_alert_history WHERE logtime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY logtime) TO '/home/gpadmin/Work/INC0019196/log_alert_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM network_interface_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/network_interface_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM queries_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/queries_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM segment_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/segment_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM socket_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/socket_history_20240315.csv' CSV HEADER;
COPY (SELECT * FROM system_history WHERE ctime BETWEEN '2024-03-15 20:30:00' AND '2024-03-18 20:55:00' ORDER BY ctime) TO '/home/gpadmin/Work/INC0019196/system_history_20240315.csv' CSV HEADER;


## adbmon
# adbmon.t_audit_top
table="adbmon.t_audit_top"
dbname="gpadmin"  # БД заказчика
psql -q -d $dbname -c "
COPY (SELECT * FROM $table
       where 1 = 1
         and dtm between '2024-07-02 10:59:00 +0300'
                     and '2024-07-02 17:21:00 +0300';
) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz

# adbmon.t_audit_pg_stat_activity
table="adbmon.t_audit_pg_stat_activity"
dbname="gpadmin"  # БД заказчика
psql -q -d $dbname -c "
COPY (SELECT * FROM $table
       where 1 = 1
         and dtm between '2024-07-02 10:59:00 +0300'
                     and '2024-07-02 17:21:00 +0300';
) TO '/tmp/$table.csv' (FORMAT CSV, HEADER)"
gzip /tmp/$table.csv
chmod 0666 /tmp/$table.csv.gz
ls -lh /tmp/$table.csv.gz


select * from adbmon.t_audit_top where 1 = 1 and dtm between '2024-04-22 14:00:00 +0300' and '2024-04-23 00:00:00 +0300';
select * from adbmon.t_audit_pg_stat_activity where 1 = 1 and dtm between '2024-04-22 14:00:00 +0300' and '2024-04-23 00:00:00 +0300';



exit 0
