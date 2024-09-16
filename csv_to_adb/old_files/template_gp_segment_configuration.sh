#!/bin/bash
# copy query from ADB database to CSV:

# Нужно выполнить на стороне заказчика из-под gpadmin:
fname="gp_segment_configuration"
query="SELECT * FROM gp_segment_configuration"
dbname="gpadmin"  # БД заказчика
psql -q -d $dbname -c "COPY (${query}) TO '/tmp/$fname.csv' (FORMAT CSV)"
gzip /tmp/$fname.csv
chmod 0666 /tmp/$fname.csv.gz
ls -lh /tmp/$fname.csv.gz

# Выгрузить файлы:
#~ scp avas@avas-dwm1:/tmp/$fname.csv.gz /downloads/


# Нужно выполнить у себя:
tst_host=avas-dwm1
tst_db=gpadmin
tst_user=avas
tst_schema=INC0018921
fname=gp_segment_configuration
table=$fname

# Загрузить на мастер-ноду ADB файл
scp /downloads/$fname.csv.gz $tst_user@$tst_host:/tmp

# Выполнить скрипт:
ssh $tst_user@$tst_host -q -T << EOF
gzip -d /tmp/$fname.csv.gz
chmod 0666 /tmp/$fname.csv
sudo -iu gpadmin
psql -d $tst_db -c "
CREATE SCHEMA IF NOT EXISTS $tst_schema;
CREATE TABLE IF NOT EXISTS $tst_schema.$table (
like gp_segment_configuration
  )
  WITH (appendonly=true,
        orientation=column,
        compresstype=zstd,
        compresslevel=9
       )
  DISTRIBUTED RANDOMLY
;

COPY $tst_schema.$table FROM '/tmp/$fname.csv' (FORMAT CSV);
"
psql -d $tst_db -c "
VACUUM ANALYZE $tst_schema.$table;
"
EOF

exit 0

