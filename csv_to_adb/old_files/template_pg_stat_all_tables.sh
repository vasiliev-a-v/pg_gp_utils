#!/bin/bash
# copy table from ADB database:

# Нужно выполнить на стороне заказчика из-под gpadmin:
ticket=INC0019026
time=$(date '+%Y-%m-%dT%H-%M-%S')
table="pg_stat_all_tables"
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
ticket=INC0019026
file=pg_stat_all_tables
tst_schema=$ticket
table=$file

# Загрузить на мастер-ноду ADB файл
scp /downloads/$table.csv.gz $tst_user@$tst_host:/tmp

# Выполнить скрипт:
ssh $tst_user@$tst_host -q -T << EOF
chmod 0666 /tmp/$ticket.*.$table.csv.gz
gzip -d /tmp/$ticket.*.$table.csv.gz
sudo -iu gpadmin
psql -d $tst_db -c "
CREATE SCHEMA IF NOT EXISTS $tst_schema;
CREATE TABLE IF NOT EXISTS $tst_schema.$table
  (LIKE $table)
WITH (appendonly=true, orientation=column,
      compresstype=zstd, compresslevel=9)
  DISTRIBUTED RANDOMLY;
COPY $tst_schema.$table FROM '/tmp/$table.csv' (FORMAT CSV);
"
EOF


exit 0
