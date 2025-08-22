-- SQL-query collects database parameters.

SET optimizer = off;

-- filename definition variables:
\set fn_gsv  :adbmt_dir /gp_server_version.csv
\set fn_pu   :adbmt_dir /postmaster_uptime.csv
\set fn_pm   :adbmt_dir /postmaster_stat.csv
\set fn_prc  :adbmt_dir /gp_resgroup_config.csv
\set fn_pdb  :adbmt_dir /pg_database.csv
\set fn_pdrs :adbmt_dir /pg_db_role_setting.csv
\set fn_gsc  :adbmt_dir /gp_segment_configuration.csv
\set fn_gch  :adbmt_dir /gp_configuration_history.csv


\qecho :fn_gsv
COPY (SELECT productversion AS "gp_version_at_initdb",
             current_setting('gp_server_version') AS gp_server_version,
             version() AS "version()"
        FROM gp_version_at_initdb
   ) TO :'fn_gsv' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_pu
COPY (SELECT date_trunc('second', current_timestamp -
             pg_postmaster_start_time()) AS postmaster_uptime
   ) TO :'fn_pu' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_pm
COPY (SELECT -1 AS gpseg
           , (pg_stat_file('postmaster.pid')).*
       UNION ALL
      SELECT gp_segment_id AS gpseg
           , (pg_stat_file('postmaster.pid')).*
        FROM gp_dist_random('gp_id')
       ORDER BY 1
   ) TO :'fn_pm' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_prc
COPY (SELECT *
        FROM gp_toolkit.gp_resgroup_config
   ) TO :'fn_prc' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_pdb
COPY (SELECT oid, *
        FROM pg_catalog.pg_database
   ) TO :'fn_pdb' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_pdrs
COPY (SELECT pd.datname,
             CASE pdrs.setrole
                  WHEN 0 THEN ''
                  ELSE pg_get_userbyid(pdrs.setrole) 
             END::text AS rolname,
             pdrs.*
        FROM pg_catalog.pg_db_role_setting pdrs
        LEFT OUTER JOIN pg_database pd
          ON pdrs.setdatabase = pd.oid
   ) TO :'fn_pdrs' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_gsc
COPY (SELECT *
        FROM pg_catalog.gp_segment_configuration ORDER BY dbid
   ) TO :'fn_gsc' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_gch
COPY (SELECT *
        FROM pg_catalog.gp_configuration_history ORDER BY time
   ) TO :'fn_gch' (FORMAT CSV, HEADER)
;
\qecho 


\quit


