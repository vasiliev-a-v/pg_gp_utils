-- Script gets data on adbmon schema between particular time range
-- and saves data to files *.csv.gz.

SET optimizer = off;

-- filename definition variables:
\set fn_ta_psa      :adbmt_dir /t_audit_pg_stat_activity.csv.gz
\set fn_ta_grs      :adbmt_dir /t_audit_gp_resgroup_status.csv.gz
\set fn_ta_grsps    :adbmt_dir /t_audit_gp_resgroup_status_per_seg.csv.gz
\set fn_ta_lu       :adbmt_dir /t_audit_locks_usage.csv.gz
\set fn_ta_mu       :adbmt_dir /t_audit_mem_usage.csv.gz

-- command definition variables:
\set cmd_ta_psa      gzip' '-f' '>' ':fn_ta_psa
\set cmd_ta_grs      gzip' '-f' '>' ':fn_ta_grs
\set cmd_ta_grsps    gzip' '-f' '>' ':fn_ta_grsps
\set cmd_ta_lu       gzip' '-f' '>' ':fn_ta_lu
\set cmd_ta_mu       gzip' '-f' '>' ':fn_ta_mu

\qecho :fn_ta_psa
COPY (SELECT * FROM adbmon.t_audit_pg_stat_activity
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'cmd_ta_psa' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_ta_grs
COPY (SELECT * FROM adbmon.t_audit_resgroup_status
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'cmd_ta_grs' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_ta_grsps
COPY (SELECT * FROM adbmon.t_audit_resgroup_status_per_seg
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'cmd_ta_grsps' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_ta_lu
COPY (SELECT * FROM adbmon.t_audit_locks_usage
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'cmd_ta_lu' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_ta_mu
COPY (SELECT * FROM adbmon.t_audit_mem_usage
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'cmd_ta_mu' (FORMAT CSV, HEADER)
;
\qecho 



\quit
