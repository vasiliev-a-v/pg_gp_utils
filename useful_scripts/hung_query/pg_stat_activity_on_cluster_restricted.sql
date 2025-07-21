-- Сделать файл на мастер-ноде:
-- /home/gpadmin/arenadata_configs/pg_stat_activity_on_cluster.sql
-- с содержимым:

SELECT psga.gp_segment_id AS gpseg,
       psga.pid,
       psga.sess_id,
       gsc.hostname,
       gsc.port,
       gsc.datadir,
       substring(psga.query, 1, 120)
  FROM (
       SELECT -1 AS gp_segment_id,
              (pg_stat_get_activity(NULL::integer)).*
        UNION ALL
       SELECT gp_segment_id,
              (pg_stat_get_activity(NULL::integer)).*
         FROM gp_dist_random('gp_id')
       ) psga
  JOIN pg_catalog.gp_segment_configuration gsc
    ON psga.gp_segment_id = gsc.content
   AND gsc.role = 'p'
 ORDER BY gpseg
;



\quit

-- Выполнить запрос командой:
-- psql -d template1 -f /home/gpadmin/arenadata_configs/pg_stat_activity_on_cluster.sql > /tmp/pg_stat_activity_on_cluster.log

