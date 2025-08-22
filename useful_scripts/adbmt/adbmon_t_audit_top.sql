-- Script gets data on adbmon schema between particular time range
-- and saves data to files *.csv.gz.

SET optimizer = off;

-- filename definition variables:
\set fn_ta_top    :adbmt_dir /t_audit_top.csv.gz
-- command definition variables:
\set cmd_ta_top    gzip' '-f' '>' ':fn_ta_top

\qecho :fn_ta_top
COPY (SELECT * FROM adbmon.t_audit_top
       WHERE 1 = 1
         AND dtm BETWEEN :'begin'
                     AND :'end'
   ) TO PROGRAM :'cmd_ta_top' (FORMAT CSV, HEADER)
;
\qecho 

\quit
