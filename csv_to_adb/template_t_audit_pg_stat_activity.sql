-- adbmon.t_audit_pg_stat_activity

CREATE TABLE IF NOT EXISTS public.$table (
dtm              timestamp with time zone ,
datid            oid                      ,
datname          name                     ,
pid              integer                  ,
sess_id          integer                  ,
usesysid         oid                      ,
usename          name                     ,
application_name text                     ,
client_addr      inet                     ,
client_hostname  text                     ,
client_port      integer                  ,
backend_start    timestamp with time zone ,
xact_start       timestamp with time zone ,
query_start      timestamp with time zone ,
state_change     timestamp with time zone ,
waiting          boolean                  ,
state            text                     ,
backend_xid      xid                      ,
backend_xmin     xid                      ,
query            text                     ,
waiting_reason   text                     ,
rsgid            oid                      ,
rsgname          text                     ,
rsgqueueduration interval
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;

