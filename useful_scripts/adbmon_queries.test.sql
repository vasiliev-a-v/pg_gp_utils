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
-- TODO: сделать опционально включить возможность собрать t_audit_top

-- -- -- -- ЭТО ТЕСТ! --

\c inc0025341

SET optimizer = off;
SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset


-- Тестировал $(hostname) в имени файла
-- COPY (SELECT * FROM public.t_audit_top
       -- WHERE 1 = 1
         -- AND dtm BETWEEN '2025-07-18 10:08:00 +0300'
                     -- AND '2025-07-18 10:35:00 +0300'
   -- ) TO PROGRAM 'gzip -f > /tmp/ta_top_$(hostname).csv.gz' (FORMAT CSV, HEADER);
-- \quit


-- Объявить переменные для названий файлов:
\set fn_ta_top                        /tmp/ta_top_ :date .csv.gz
\set fn_ta_pg_stat_activity           /tmp/ta_pg_stat_activity_$(hostname)_ :date .csv.gz
\set fn_ta_gp_resgroup_status         /tmp/ta_gp_resgroup_status_ :date .csv.gz
\set fn_ta_gp_resgroup_status_per_seg /tmp/ta_gp_resgroup_status_per_seg_ :date .csv.gz
\set fn_ta_locks_usage                /tmp/ta_locks_usage_ :date .csv.gz
\set fn_ta_mem_usage                  /tmp/ta_mem_usage_ :date .csv.gz

-- Объявить переменные для команд:
\set f_ta_top                        gzip' '-f' '>' ':fn_ta_top
\set f_ta_pg_stat_activity           gzip' '-f' '>' ':fn_ta_pg_stat_activity
\set f_ta_gp_resgroup_status         gzip' '-f' '>' ':fn_ta_gp_resgroup_status
\set f_ta_gp_resgroup_status_per_seg gzip' '-f' '>' ':fn_ta_gp_resgroup_status_per_seg
\set f_ta_locks_usage                gzip' '-f' '>' ':fn_ta_locks_usage
\set f_ta_mem_usage                  gzip' '-f' '>' ':fn_ta_mem_usage


-- отключил потому, что он может собрать черезчур много данных.
-- \qecho :fn_ta_top
-- COPY (SELECT * FROM public.t_audit_top
       -- WHERE 1 = 1
         -- AND dtm BETWEEN :'begin'
                     -- AND :'end'
   -- ) TO PROGRAM :'f_ta_top' (FORMAT CSV, HEADER)
-- ;

\qecho 
\qecho :fn_ta_pg_stat_activity
COPY (SELECT * FROM public.t_audit_pg_stat_activity
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_pg_stat_activity' (FORMAT CSV, HEADER)
;
\qecho 
\qecho :fn_ta_gp_resgroup_status
COPY (SELECT * FROM public.t_audit_resgroup_status
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_gp_resgroup_status' (FORMAT CSV, HEADER)
;
\qecho 
\qecho :fn_ta_gp_resgroup_status_per_seg
COPY (SELECT * FROM public.t_audit_resgroup_status_per_seg
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_gp_resgroup_status_per_seg' (FORMAT CSV, HEADER)
;
\qecho 
\qecho :fn_ta_locks_usage
COPY (SELECT * FROM public.t_audit_locks_usage
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_locks_usage' (FORMAT CSV, HEADER)
;
\qecho 
\qecho :fn_ta_mem_usage
COPY (SELECT * FROM public.t_audit_mem_usage
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'f_ta_mem_usage' (FORMAT CSV, HEADER)
;

\qecho 
\qecho /tmp/adbmon_queries.log



\quit
