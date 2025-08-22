-- SQL-query collects gpprefmon data.
-- \c gpperfmon

SET optimizer = off;
SELECT to_char(now(), 'YYYY-MM-DD_HH24-MI-SS') date \gset

-- filename definition variables:
\set fn_database     :adbmt_dir /gpperfmon.database_history.csv.gz
\set fn_diskspace    :adbmt_dir /gpperfmon.diskspace_history.csv.gz
\set fn_log_alert    :adbmt_dir /gpperfmon.log_alert_history.csv.gz
\set fn_network_i    :adbmt_dir /gpperfmon.network_interface_history.csv.gz
\set fn_queries      :adbmt_dir /gpperfmon.queries_history.csv.gz
\set fn_segment      :adbmt_dir /gpperfmon.segment_history.csv.gz
\set fn_socket       :adbmt_dir /gpperfmon.socket_history.csv.gz
\set fn_system       :adbmt_dir /gpperfmon.system_history.csv.gz

-- command definition variables:
\set cmd_database   gzip' '-f' '>' ':fn_database
\set cmd_diskspace  gzip' '-f' '>' ':fn_diskspace
\set cmd_log_alert  gzip' '-f' '>' ':fn_log_alert
\set cmd_network_i  gzip' '-f' '>' ':fn_network_i
\set cmd_queries    gzip' '-f' '>' ':fn_queries
\set cmd_segment    gzip' '-f' '>' ':fn_segment
\set cmd_socket     gzip' '-f' '>' ':fn_socket
\set cmd_system     gzip' '-f' '>' ':fn_system


\qecho :fn_database
COPY (SELECT *
        FROM database_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_database' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_diskspace
COPY (SELECT *
        FROM diskspace_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_diskspace' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_log_alert
COPY (SELECT *
        FROM log_alert_history
       WHERE 1 = 1
         AND logtime BETWEEN :'begin'
                         AND :'end'
       ORDER BY logtime
   ) TO PROGRAM :'cmd_log_alert' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_network_i
COPY (SELECT *
        FROM network_interface_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_network_i' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_queries
COPY (SELECT *
        FROM queries_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_queries' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_segment
COPY (SELECT *
        FROM segment_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_segment' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_socket
COPY (SELECT *
        FROM socket_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_socket' (FORMAT CSV, HEADER)
;
\qecho 

\qecho :fn_system
COPY (SELECT *
        FROM system_history
       WHERE 1 = 1
         AND ctime BETWEEN :'begin'
                       AND :'end'
       ORDER BY ctime
   ) TO PROGRAM :'cmd_system' (FORMAT CSV, HEADER)
;
\qecho 
