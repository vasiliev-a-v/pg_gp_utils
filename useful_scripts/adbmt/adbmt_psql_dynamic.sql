-- SQL-query collects dynamic data.

SET optimizer = off;

\set adbmt_dir /tmp
\set snp 1

-- declare variables:
SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset
\set fn_pl    :adbmt_dir / :snp . pg_locks_ :date .csv
\set fn_grs   :adbmt_dir / :snp . gp_resgroup_status_ :date .csv
\set fn_grsph :adbmt_dir / :snp . gp_resgroup_status_per_host_ :date .csv
\set fn_psa   :adbmt_dir / :snp . pg_stat_activity_on_cluster_ :date .csv


\qecho :fn_pl
COPY (       /* adbmt */
      SELECT *
        FROM pg_catalog.pg_locks
  ) TO :'fn_pl' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_grs
COPY (       /* adbmt */
      SELECT rsgname, num_running, num_queueing,
             num_queued, num_executed
        FROM gp_toolkit.gp_resgroup_status
   ) TO :'fn_grs' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_grsph
COPY (       /* adbmt */
      SELECT *
        FROM gp_toolkit.gp_resgroup_status_per_host
   ) TO :'fn_grsph' (FORMAT CSV, HEADER)
;
\qecho 

-- pg_stat_activity from all cluster:
\qecho :fn_psa
COPY (       /* adbmt */
      SELECT psga.*
        FROM (
             SELECT /* master (-1) */
                    -1 AS gpseg,
                    d.datname,
                    pg_get_userbyid(a.usesysid) AS usename,
                    a.*
               FROM pg_stat_get_activity(NULL::integer) AS a
               LEFT JOIN pg_database AS d
                 ON d.oid = a.datid
              UNION ALL
             SELECT /* segments (gp_dist_random) */
                    gid.gp_segment_id AS gpseg,
                    d.datname,
                    pg_get_userbyid(a.usesysid) AS usename,
                    a.*
               FROM gp_dist_random('gp_id') AS gid
              CROSS JOIN pg_stat_get_activity(NULL::integer) AS a
               LEFT JOIN pg_database AS d
                 ON d.oid = a.datid
            ) AS psga
         JOIN pg_catalog.gp_segment_configuration AS gsc
           ON psga.gpseg = gsc.content
          AND gsc.role = 'p'
        ORDER BY gpseg
  ) TO :'fn_psa' (FORMAT CSV, HEADER)
;
\qecho

\quit
