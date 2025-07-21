\c template1

-- Сделать файл на мастер-ноде:
-- /home/gpadmin/arenadata_configs/process_queries.sql
-- с содержимым:

SET optimizer = off;

SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset
\set file_pg_locks gzip' '-f' '>' '/tmp/pg_locks_ :date .csv.gz
\set file_pg_stat_activity gzip' '-f' '>' '/tmp/pg_stat_activity_ :date .csv.gz
\set file_gp_resgroup_status gzip' '-f' '>' '/tmp/gp_resgroup_status_ :date .csv.gz
\set file_gp_resgroup_status_per_host gzip' '-f' '>' '/tmp/gp_resgroup_status_per_host_ :date .csv.gz

\qecho :file_pg_locks
COPY (SELECT * FROM pg_locks) TO PROGRAM :'file_pg_locks' (FORMAT CSV, HEADER);

\qecho :file_pg_stat_activity
COPY (SELECT * FROM pg_stat_activity) TO PROGRAM :'file_pg_stat_activity' (FORMAT CSV, HEADER);

\qecho :file_gp_resgroup_status
COPY (SELECT rsgname, num_running, num_queueing, num_queued, num_executed FROM gp_toolkit.gp_resgroup_status) TO PROGRAM :'file_gp_resgroup_status' (FORMAT CSV, HEADER);

\qecho :file_gp_resgroup_status_per_host
COPY (SELECT * FROM gp_toolkit.gp_resgroup_status_per_host) TO PROGRAM :'file_gp_resgroup_status_per_host' (FORMAT CSV, HEADER);

\quit
-- Выполнить запрос командой:
psql -d template1 -f /home/gpadmin/arenadata_configs/process_queries.sql
-- Сформируются CSV-файлы:
/tmp/pg_locks_*.csv.gz
/tmp/pg_stat_activity_*.csv.gz
/tmp/gp_resgroup_status_*.csv.gz
/tmp/gp_resgroup_status_per_host_*.csv.gz




-- psql -q -d template1 -c "COPY (SELECT * FROM gp_toolkit.gp_resgroup_config) TO '/tmp/gp_resgroup_config.csv' (FORMAT CSV, HEADER)"
