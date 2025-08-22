-- adbmon.t_audit_mem_usage
-- template_t_audit_mem_usage.sql

CREATE TABLE IF NOT EXISTS public.$table (
    dtm                  timestamptz,
    datname              name       ,
    sess_id              integer    ,
    usename              name       ,
    query                text       ,
    segid                integer    ,
    vmem_mb              integer    ,
    is_runaway           boolean    ,
    qe_count             integer    ,
    active_qe_count      integer    ,
    dirty_qe_count       integer    ,
    runaway_vmem_mb      integer    ,
    runaway_command_cnt  integer    ,
    idle_start           timestamptz
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;
