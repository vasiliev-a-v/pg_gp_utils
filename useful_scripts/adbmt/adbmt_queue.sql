-- SET gp_resource_group_bypass=true;
-- SET gp_resource_group_queuing_timeout='1min';
-- SET statement_timeout = '1h';
-- SET gp_interconnect_type=tcp;
-- SHOW gp_interconnect_type;
\t
\x \\
\qecho RESOURCE_GROUP_STATUS:
SELECT now() AS test_connection_adbmt,
       rsgname,
       num_running,
       num_queueing,
       concurrency,
       (grc.concurrency::int - grs.num_running) AS "concurrency - num_running",
       CASE WHEN grc.concurrency::int - grs.num_running <= 2
              OR grs.num_queueing > 0
         THEN 'WARN: Concurrency is Low!'
         ELSE 'INFO: Concurrency is Norm.'
       END AS status
  FROM gp_toolkit.gp_resgroup_status AS grs
  JOIN gp_toolkit.gp_resgroup_config AS grc
    ON grs.rsgname = grc.groupname
 WHERE rsgname = 'admin_group'
;
\x


\quit
-- adbmt_queue.sql
