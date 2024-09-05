\c ADWH
-- Подставьте имя вашей партиционированной таблицы вместо 'schema_name.partitioned_table_name'
--~ \prompt table_name
--~ \set table_name pg_catalog.pg_class
\set table_name ao_delivery_times.delivery_times_rows
\set table_name pg_catalog.pg_class

SELECT schemaname,
       tablename,
       round(sum(pg_total_relation_size(schemaname || '.' || partitiontablename))/1024/1024) "MB"
  FROM pg_partitions
 WHERE schemaname||'.'||tablename = :'table_name'
 GROUP by 1,2;
\q
