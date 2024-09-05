SET application_name = 'kill_hung_query_test.sql';

BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT pg_backend_pid();

WITH pids AS (
     SELECT sess_id
       FROM pg_stat_activity
      WHERE pid = pg_backend_pid()
     )
  SELECT psga.gp_segment_id,
         psga.pid,
         psga.sess_id,
         substring(psga.query, 1, 100)
    FROM (
         SELECT -1 AS gp_segment_id,
                (pg_stat_get_activity(NULL::integer)).*
          UNION ALL
         SELECT gp_segment_id,
                (pg_stat_get_activity(NULL::integer)).*
           FROM gp_dist_random('gp_id')
       ) psga
       , pids
   WHERE psga.sess_id = pids.sess_id
   ORDER BY psga.sess_id, psga.gp_segment_id
;
SELECT pg_sleep(10000);
COMMIT;
\q

SELECT sess_id
  FROM pg_stat_activity
 WHERE pid = pg_backend_pid();

SELECT -1 AS gp_segment_id, *
  FROM pg_class ORDER BY oid
 UNION ALL
SELECT gp_segment_id, *
  FROM pg_class ORDER BY oid, gp_segment_id
;

COMMIT;




