#!/bin/bash
# copy query from ADB database to CSV:

# Нужно выполнить на стороне заказчика из-под gpadmin:
fname="check_data_skew_to_csv"
dbname="knd_sdw_prod_adb_dwh_hist_data"  # БД заказчика
psql -d $dbname -f /home/gpadmin/arenadata_configs/$fname.sql > /tmp/$fname.csv
gzip /tmp/$fname.csv
chmod 0666 /tmp/$fname.csv.gz
ls -lh /tmp/$fname.csv.gz


# Выгрузить файлы:
#~ scp avas@avas-dwm1:/tmp/$fname.csv.gz /downloads/


# Нужно выполнить у себя:
tst_host=avas-dwm1
tst_db=gpadmin
tst_user=avas
tst_schema=INC0019026
fname=check_data_skew_to_csv
table=$fname
path=/a/INC/INC0019026/logs

# Загрузить на мастер-ноду ADB файл
scp $path/$fname.csv.gz $tst_user@$tst_host:/tmp

# Выполнить скрипт:
ssh $tst_user@$tst_host -q -T << EOF
chmod 0666 /tmp/$fname.csv.gz
gzip  -d   /tmp/$fname.csv.gz
ls    -ld  /tmp/$fname.csv
sudo -iu gpadmin
psql -d $tst_db -c "
CREATE SCHEMA IF NOT EXISTS $tst_schema;
CREATE TABLE IF NOT EXISTS $tst_schema.$table (
table_database   text,
table_schema     text,
table_name       text,
total_size_mb    numeric(15,2),
blocked_space_mb numeric(15,2),
skew             numeric(15,2),
seg_min_size_mb  numeric(15,2),
seg_max_size_mb  numeric(15,2),
seg_avg_size_mb  numeric(15,2),
empty_seg_cnt    int
)
WITH (appendonly=true, orientation=column,
      compresstype=zstd, compresslevel=9)
  DISTRIBUTED RANDOMLY;
COPY $tst_schema.$table FROM '/tmp/$fname.csv' (FORMAT CSV);
"
exit 0
ls -ld /tmp/$fname.csv
rm -f  /tmp/$fname.csv
ls -ld /tmp/$fname.csv
EOF


exit 0
