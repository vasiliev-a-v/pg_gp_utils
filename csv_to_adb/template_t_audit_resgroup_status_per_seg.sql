-- adbmon.t_audit_resgroup_status_per_seg
-- template_t_audit_resgroup_status_per_seg.sql

CREATE TABLE IF NOT EXISTS public.$table (
    dtm                     timestamp with time zone,
    rsgname                 text,
    groupid                 bigint,
    hostname                text,
    segment_id              bigint,
    cpu                     numeric(5,2),
    memory_used             bigint,
    memory_available        bigint,
    memory_quota_used       bigint,
    memory_quota_available  bigint,
    memory_shared_used      bigint,
    memory_shared_available bigint
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;





