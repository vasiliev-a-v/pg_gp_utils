#!/bin/bash
# copy query from ADB database to CSV:

# Нужно выполнить на стороне заказчика из-под gpadmin:
fname="pg_stat_activity"
query="SELECT * FROM pg_stat_activity"
dbname="gpadmin"  # БД заказчика
psql -q -d $dbname -c "COPY (${query}) TO '/tmp/$fname.csv' (FORMAT CSV)"
gzip /tmp/$fname.csv
chmod 0666 /tmp/$fname.csv.gz
ls -lh /tmp/$fname.csv.gz

fname="pg_locks"
query="SELECT * FROM pg_locks"
dbname="gpadmin"  # БД заказчика
psql -q -d $dbname -c "COPY (${query}) TO '/tmp/$fname.csv' (FORMAT CSV)"
gzip /tmp/$fname.csv
chmod 0666 /tmp/$fname.csv.gz
ls -lh /tmp/$fname.csv.gz

fname="pg_class"
query="SELECT * FROM pg_class"
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
tst_schema=INC0018856
fname=pg_stat_activity
fname=pg_locks
table=$fname

# Загрузить на мастер-ноду ADB файл
scp /downloads/$fname.csv.gz $tst_user@$tst_host:/tmp

# Выполнить скрипт:
ssh $tst_user@$tst_host -q -T << EOF
chmod 0666 /tmp/$fname.csv.gz
gzip -d /tmp/$fname.csv.gz
sudo -iu gpadmin

psql -d $tst_db -c "
CREATE SCHEMA IF NOT EXISTS $tst_schema;

CREATE TABLE IF NOT EXISTS $tst_schema.$table (
    locktype           text    ,    database           oid     ,
    relation           oid     ,    page               integer ,
    tuple              smallint,    virtualxid         text    ,
    transactionid      xid     ,    classid            oid     ,
    objid              oid     ,    objsubid           smallint,
    virtualtransaction text    ,    pid                integer ,
    mode               text    ,    granted            boolean ,
    fastpath           boolean ,    mppsessionid       integer ,
    mppiswriter        boolean ,    gp_seg_id          integer
  )
  WITH (appendonly=true,
        orientation=column,
        compresstype=zstd,
        compresslevel=9
       )
  DISTRIBUTED RANDOMLY
;

COPY $tst_schema.$table FROM '/tmp/$fname.csv' (FORMAT CSV);

VACUUM ANALYZE $tst_schema.$table;

"
EOF

exit 0



