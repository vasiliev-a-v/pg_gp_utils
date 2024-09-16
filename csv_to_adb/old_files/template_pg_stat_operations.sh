#!/bin/bash
# copy table from ADB database:

# Нужно выполнить на стороне заказчика:
table="pg_stat_operations"
ticket=INC0019026
time=$(date '+%Y-%m-%dT%H-%M-%S')
customer_db="gpadmin"  # БД заказчика
psql -q -d $customer_db -c "COPY (SELECT * FROM $table) TO '/tmp/$ticket.$time.$table.csv' (FORMAT CSV)"
gzip /tmp/$ticket.$time.$table.csv
chmod 0666 /tmp/$ticket.$time.$table.csv.gz
ls -lh /tmp/$ticket.$time.$table.csv.gz

# Выгрузить файлы:
#~ scp avas@avas-dwm1:/tmp/$table.csv.gz /downloads/

# Нужно выполнить у себя:
tst_host=avas-dwm1
tst_db=gpadmin
tst_user=avas
tst_schema=INC0019026
fname=INC0019026.2024-03-12T14-42-53.pg_stat_operations
table=pg_stat_operations
path=/a/INC/INC0019026/logs

# Загрузить на мастер-ноду ADB файл
scp $path/$fname.csv.gz $tst_user@$tst_host:/tmp

# Выполнить скрипт:
ssh $tst_user@$tst_host -q -T << EOF
chmod 0666 /tmp/$fname.csv.gz
gzip -d /tmp/$fname.csv.gz
sudo -iu gpadmin

psql -d $tst_db -c "
CREATE SCHEMA IF NOT EXISTS $tst_schema;

CREATE TABLE IF NOT EXISTS $tst_schema.$table (
  LIKE pg_catalog.pg_stat_operations
  )
  WITH (appendonly=true,
        orientation=column,
        compresstype=zstd,
        compresslevel=3
       )
  DISTRIBUTED RANDOMLY
;

COPY $tst_schema.$table FROM '/tmp/$fname.csv' (FORMAT CSV);
"
exit 0
ls -ld /tmp/$fname.csv
rm -f  /tmp/$fname.csv
ls -ld /tmp/$fname.csv
EOF




exit 0
