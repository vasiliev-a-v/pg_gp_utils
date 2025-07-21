-- INC0025139
-- INC0025341_queries.sql

SET optimizer = off;

SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset
\set f_ta_top gzip' '-f' '>' '/tmp/ta_top_ :date .csv.gz
\set f_ta_pg_stat_activity gzip' '-f' '>' '/tmp/ta_pg_stat_activity_ :date .csv.gz
\set f_ta_gp_resgroup_status gzip' '-f' '>' '/tmp/ta_gp_resgroup_status_ :date .csv.gz
\set f_ta_gp_resgroup_status_per_seg gzip' '-f' '>' '/tmp/ta_gp_resgroup_status_per_seg_ :date .csv.gz
\set f_ta_pg_locks_usage gzip' '-f' '>' '/tmp/pg_locks_usage_ :date .csv.gz

\qecho :f_ta_top
COPY (SELECT * FROM adbmon.t_audit_top
       WHERE 1 = 1
         AND dtm BETWEEN '2025-07-18 09:30:00 +0300'
                     AND '2025-07-18 10:30:00 +0300'
   ) TO PROGRAM :'f_ta_top' (FORMAT CSV, HEADER)
;

\qecho :f_ta_pg_stat_activity
COPY (SELECT * FROM adbmon.t_audit_pg_stat_activity
       WHERE 1 = 1
         AND dtm BETWEEN '2025-07-18 09:30:00 +0300'
                     AND '2025-07-18 10:30:00 +0300'
   ) TO PROGRAM :'f_ta_pg_stat_activity' (FORMAT CSV, HEADER)
;

\qecho :f_ta_gp_resgroup_status
COPY (SELECT * FROM adbmon.t_audit_resgroup_status
       WHERE 1 = 1
         AND dtm BETWEEN '2025-07-18 09:30:00 +0300'
                     AND '2025-07-18 10:30:00 +0300'
   ) TO PROGRAM :'f_ta_gp_resgroup_status' (FORMAT CSV, HEADER)
;


\qecho :f_ta_gp_resgroup_status_per_seg
COPY (SELECT * FROM adbmon.t_audit_resgroup_status_per_seg
       WHERE 1 = 1
         AND dtm BETWEEN '2025-07-18 09:30:00 +0300'
                     AND '2025-07-18 10:30:00 +0300'
   ) TO PROGRAM :'f_ta_gp_resgroup_status_per_seg' (FORMAT CSV, HEADER)
;


\qecho :f_ta_pg_locks_usage
COPY (SELECT * FROM adbmon.t_audit_locks_usage
       WHERE 1 = 1
         AND dtm BETWEEN '2025-07-18 09:30:00 +0300'
                     AND '2025-07-18 10:30:00 +0300'
   ) TO PROGRAM :'f_ta_pg_locks_usage' (FORMAT CSV, HEADER)
;


\quit
-- Выполнить запрос командой:
psql -d ваша_база -f /home/gpadmin/arenadata_configs/INC0025341_queries.sql
-- Сформируются CSV-файлы.


