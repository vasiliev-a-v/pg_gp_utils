-- Сделать файл на мастер-ноде:
-- /home/gpadmin/arenadata_configs/pg_stat_activity_on_cluster.sql
-- с содержимым:

SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset

\set file_activity /tmp/pg_stat_activity_on_cluster_ :date .csv
\qecho :file_activity

COPY (
      SELECT psga.*
        FROM (
             SELECT -1 AS gpseg,
                    (pg_stat_get_activity(NULL::integer)).*
              UNION ALL
             SELECT gp_segment_id AS gpseg,
                    (pg_stat_get_activity(NULL::integer)).*
               FROM gp_dist_random('gp_id')
             ) psga
        JOIN pg_catalog.gp_segment_configuration gsc
          ON psga.gpseg = gsc.content
         AND gsc.role = 'p'
       ORDER BY gpseg
  ) TO :'file_activity' (FORMAT CSV, HEADER)
;


\quit

-- Выполнить запрос командой:
psql -d template1 -f /home/gpadmin/arenadata_configs/pg_stat_activity_on_cluster.sql
-- Сформируется CSV-файл:
/tmp/pg_stat_activity_on_cluster_YYYY-MM-DD_HH24-MI-SS.csv

