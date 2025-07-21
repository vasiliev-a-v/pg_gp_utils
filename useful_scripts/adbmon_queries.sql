-- Скрипт собирает данные с adbmon по заданному временному диапазону
-- и сохраняет в файлы *.csv.gz (сжатые csv-файлы).
-- Подсказка по смещению по времени, например:
-- 2024-03-26 08:03:00+00 - это 2024-03-26 11:03:00 +0300
-- 2024-03-26 08:06:00+00 - это 2024-03-26 11:06:00 +0300
-- Выполнить запрос командой:
-- psql -d ваша_база -f /home/gpadmin/arenadata_configs/adbmon_queries.sql -v begin 'YYYY-MM-DD HH:mm:SS' -v end='YYYY-MM-DD HH:mm:SS'
-- Например:
-- psql -d adb -f /home/gpadmin/arenadata_configs/adbmon_queries.sql -v begin '2024-03-26 11:03:00 +0300' -v end='2024-03-26 11:06:00 +0300'
-- Сформируются CSV-файлы.


SET optimizer = off;


SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset
-- \set f_ta_top gzip' '-f' '>' '/tmp/ta_top_ :date .csv.gz
\set f_ta_pg_stat_activity gzip' '-f' '>' '/tmp/ta_pg_stat_activity_ :date .csv.gz
\set f_ta_gp_resgroup_status gzip' '-f' '>' '/tmp/ta_gp_resgroup_status_ :date .csv.gz
\set f_ta_gp_resgroup_status_per_seg gzip' '-f' '>' '/tmp/ta_gp_resgroup_status_per_seg_ :date .csv.gz
\set f_ta_pg_locks_usage gzip' '-f' '>' '/tmp/ta_pg_locks_usage_ :date .csv.gz
\set f_ta_audit_mem_usage gzip' '-f' '>' '/tmp/ta_mem_usage_ :date .csv.gz


-- \qecho :f_ta_top
-- COPY (SELECT * FROM adbmon.t_audit_top
       -- WHERE 1 = 1
         -- AND dtm BETWEEN :'begin'
                     -- AND :'end'
   -- ) TO PROGRAM :'f_ta_top' (FORMAT CSV, HEADER)
-- ;

\qecho :f_ta_pg_stat_activity
COPY (SELECT * FROM adbmon.t_audit_pg_stat_activity
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_pg_stat_activity' (FORMAT CSV, HEADER)
;

\qecho :f_ta_gp_resgroup_status
COPY (SELECT * FROM adbmon.t_audit_resgroup_status
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_gp_resgroup_status' (FORMAT CSV, HEADER)
;

\qecho :f_ta_gp_resgroup_status_per_seg
COPY (SELECT * FROM adbmon.t_audit_resgroup_status_per_seg
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_gp_resgroup_status_per_seg' (FORMAT CSV, HEADER)
;

\qecho :f_ta_pg_locks_usage
COPY (SELECT * FROM adbmon.t_audit_locks_usage
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_pg_locks_usage' (FORMAT CSV, HEADER)
;

\qecho :f_ta_audit_mem_usage
COPY (SELECT * FROM adbmon.t_audit_mem_usage
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_audit_mem_usage' (FORMAT CSV, HEADER)
;


\quit

