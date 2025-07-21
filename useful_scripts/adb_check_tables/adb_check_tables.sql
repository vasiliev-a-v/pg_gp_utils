-- SQL-скрипт производит чтение всех таблиц базы данных через count.
-- Данное действие необходимо для принудительного чтения всех блоков таблиц.
-- Ошибки, проявившиеся при чтении таблиц, покажут наличие таблиц со сбойными блоками.
-- Такие таблицы необходимо будет пересоздать.


-- \d arenadata_toolkit.adb_skew_coefficients
-- \d+ arenadata_toolkit.__db_files_current
-- \quit

-- SELECT * FROM rdv3.tb_aocs_test;
-- \quit


-- COPY (SELECT gp_segment_id, * FROM rdv3.tb_aocs_test WHERE gp_segment_id = 0 LIMIT 10000) TO '/dev/null' WITH (FORMAT csv);
-- SELECT count(*) FROM rdv3.tb_aocs_test;
-- \quit

SELECT -1, relname, relfilenode
  FROM pg_class
 WHERE relname = 'tb_aocs_test'
 UNION ALL
SELECT gp_segment_id, relname, relfilenode
  FROM gp_dist_random('pg_class')
 WHERE relname = 'tb_aocs_test'
 ORDER BY 1
;
\quit

/* column | relfilenode
----------+-------------
       -1 |       90632
        0 |       25143
        1 |       25143
        2 |       25141
        3 |       25141

-- /data1/primary/gpseg0/base/17019/25143

ls -l /data1/primary/gpseg0/base/17019/25143.1
cp /data1/primary/gpseg0/base/17019/25143.1 /data1/primary/gpseg0/base/17019/25143.1.copy
echo -n -e '\xFF' >> /data1/primary/gpseg0/base/17019/25143.1
truncate -s -1 /data1/primary/gpseg0/base/17019/25143.1

hexdump -C -n 24 /data1/primary/gpseg0/base/17019/25143.1

ls -l /data1/primary/gpseg0/base/17019/25143.129
cp /data1/primary/gpseg0/base/17019/25143.129 /data1/primary/gpseg0/base/17019/25143.129.copy
echo -n -e '\xFF' >> /data1/primary/gpseg0/base/17019/25143.129
truncate -s -1 /data1/primary/gpseg0/base/17019/25143.129
*/

SELECT oid FROM pg_database WHERE datname = current_database();
SELECT 'base/' || d.db || '/' || c.fn,
       pg_stat_file( 'base/' || d.db || '/' || c.fn )
  FROM (SELECT oid AS db FROM pg_database WHERE datname = current_database()) d,
       (SELECT relfilenode fn FROM pg_class WHERE relname = 'tb_aocs_test') c
;
-- 17019/57638

\quit

-- \setenv QUIET on


-- ОПРЕДЕЛЯЕМСЯ С ЛОГ-ФАЙЛОМ
SELECT to_char(now(), 'YYYYMMDD') today \gset
\set log_file '/home/gpadmin/gpAdminLogs/adb_check_tables_':today'.log'
-- сформировать строку с командой записи в лог-файл:
\set save_to_log_file '\\out | tee -a ':log_file
-- включает запись в лог-файл:
-- :save_to_log_file


SELECT now() AS begin;

DO $$
DECLARE
  tbl text;
  tbl_count int;
BEGIN
  RAISE NOTICE 'Таблица, число строк:';
  FOR tbl IN (
    SELECT n.nspname || '.' || c.relname
      FROM pg_class c
      JOIN pg_namespace n
        ON c.relnamespace = n.oid
     WHERE relpersistence = 'p'  -- p = heap or append-optimized table
       -- AND relkind ~ 'r|'  -- 
       AND relkind !~ 'i|S|v|c|f|u'  -- 
       AND relstorage ~ 'a|c|h'   -- v = virtual, x = external table
  ) LOOP
    -- EXECUTE 'SELECT count() FROM ' || tbl INTO tbl_count;
    RAISE NOTICE '%', tbl;
    EXECUTE 'SELECT * FROM ' || tbl;
    RAISE NOTICE '% прочитана.', tbl;
    EXECUTE 'SELECT pg_sleep(0.1) AS pause';
  END LOOP;
END $$;

SELECT now() AS end;




\o
\quit



    SELECT n.nspname || '.' || c.relname
      FROM pg_class c
      JOIN pg_namespace n
        ON c.relnamespace = n.oid
     WHERE relpersistence = 'p'  -- p = heap or append-optimized table
       -- AND relkind !~ 'i|S|v|c|f|u'  -- 
       -- AND relkind NOT IN ('i','S','v','c','f','u')  -- 

       -- AND relstorage !~ 'v|x'   -- v = virtual, x = external table
       -- AND relname = 'adb_skew_coefficients'
       AND relname = '__db_files_current'
;

\quit

