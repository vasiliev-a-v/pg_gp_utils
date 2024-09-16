#!/bin/bash
# copy table from ADB database:

# Нужно выполнить на стороне заказчика:
table="arenadata_toolkit.daily_operation"
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
fname=arenadata_toolkit.daily_operation
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
    relname        name    ,    relnamespace   oid     ,
    reltype        oid     ,    reloftype      oid     ,
    relowner       oid     ,    relam          oid     ,
    relfilenode    oid     ,    reltablespace  oid     ,
    relpages       integer ,    reltuples      real    ,
    relallvisible  integer ,    reltoastrelid  oid     ,
    relhasindex    boolean ,    relisshared    boolean ,
    relpersistence "char"  ,    relkind        "char"  ,
    relstorage     "char"  ,    relnatts       smallint,
    relchecks      smallint,    relhasoids     boolean ,
    relhaspkey     boolean ,    relhasrules    boolean ,
    relhastriggers boolean ,    relhassubclass boolean ,
    relispopulated boolean ,    relreplident   "char"  ,
    relfrozenxid   xid     ,    relminmxid     xid     ,
    relacl         text[]  ,    reloptions     text[]
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
