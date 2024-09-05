\c ADWH

-- Подставьте имя вашей партиционированной таблицы вместо 'schema_name.partitioned_table_name'
\set table_name ao_delivery_times.delivery_times_rows


\x \\
SELECT 
       relid::regclass,
       segrelid::regclass,
       visimaprelid::regclass,
       visimapidxid::regclass,
       *
  FROM pg_appendonly a
 WHERE a.relid IN (
       SELECT inhrelid FROM pg_inherits
        WHERE inhparent = (
              SELECT a2.relid FROM pg_appendonly a2
               WHERE a2.relid = :'table_name'::regclass::oid
              )
       )
    OR a.relid = :'table_name'::regclass::oid
;
\q


--~ SELECT oid db_oid FROM pg_database WHERE datname = 'ADWH' \gset
--~ \echo :db_oid
--~ \q
--~ \! echo $MASTER_DATA_DIRECTORY
--~ \! ls $MASTER_DATA_DIRECTORY/base/844884/444104
--~ \q
\x \\
SELECT 
       t1.relid::regclass,
       c.relname,
       --~ segrelid::regclass,
       --~ visimaprelid::regclass,
       --~ visimapidxid::regclass,
       c.*
  FROM pg_class c
  JOIN (
    SELECT 
           relid, segrelid, visimaprelid, visimapidxid
      FROM pg_appendonly a
     WHERE a.relid IN (
           SELECT inhrelid FROM pg_inherits
            WHERE inhparent = (
                  SELECT a2.relid FROM pg_appendonly a2
                   WHERE a2.relid = :'table_name'::regclass::oid
                  )
           )
        OR a.relid = :'table_name'::regclass::oid
  ) t1
  ON c.oid = t1.segrelid
  OR c.oid = t1.visimaprelid
  OR c.oid = t1.visimapidxid
;


\q



\q
Таблица "pg_catalog.pg_appendonly"
     Столбец     |   Тип    | Правило сортировки | Допустимость NULL | По умолчанию 
-----------------+----------+--------------------+-------------------+--------------
 relid           | oid      |                    | not null          | 
 blocksize       | integer  |                    | not null          | 
 safefswritesize | integer  |                    | not null          | 
 compresslevel   | smallint |                    | not null          | 
 checksum        | boolean  |                    | not null          | 
 compresstype    | name     |                    | not null          | 
 columnstore     | boolean  |                    | not null          | 
 segrelid        | oid      |                    | not null          | 
 blkdirrelid     | oid      |                    | not null          | 
 blkdiridxid     | oid      |                    | not null          | 
 visimaprelid    | oid      |                    | not null          | 
 visimapidxid    | oid      |                    | not null          | 


