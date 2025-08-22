-- adbmon.t_audit_gp_resgroup_status
-- template_t_audit_gp_resgroup_status.sql

CREATE TABLE IF NOT EXISTS public.$table (
    dtm                  timestamp with time zone ,
    rsgname              text,
    groupid              bigint,
    num_running          bigint,
    num_queueing         bigint,
    num_queued           bigint,
    num_executed         bigint,
    total_queue_duration interval
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;
