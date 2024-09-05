\c ADWH
-- Подставьте имя вашей партиционированной таблицы вместо 'schema_name.partitioned_table_name'
-- Скрипт корректно считает размер как партиционированной, так и непартиционированной таблицы
--~ \prompt table_name
-- партиционированная таблица:
\set table_name ao_delivery_times.delivery_times_rows
-- непартиционированная таблица:
--~ \set table_name pg_catalog.pg_class

WITH t1 AS (
  SELECT n.nspname AS schema_name,
         c.relname AS table_name,
         c.oid,
         pg_total_relation_size(c.oid) AS bytes
    FROM pg_class c
    JOIN pg_namespace n
      ON c.relnamespace = n.oid
   WHERE c.oid IN (
         SELECT inhrelid FROM pg_inherits
          WHERE inhparent = (
                SELECT c2.oid FROM pg_class c2
                 WHERE c2.oid = :'table_name'::regclass::oid
                )
         )
      OR c.oid = :'table_name'::regclass::oid
)
  SELECT schema_name||'.'||table_name AS table_name,
         oid,
         bytes,
         pg_size_pretty(bytes) AS human
    FROM t1
   UNION ALL
  SELECT 'Total:',
         :'table_name'::regclass::oid,
         sum(bytes),
         pg_size_pretty(sum(bytes)) AS human
    FROM t1
   ORDER BY table_name
;
\q


