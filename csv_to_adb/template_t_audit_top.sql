-- adbmon.t_audit_top
-- template_t_audit_top.sql

CREATE TABLE IF NOT EXISTS public.$table (
    dtm              timestamp with time zone ,
    host_name        text,
    host_ip          text,
    seg_num          int,
    sess_id          int,
    cmd_num          int,
    slice_num        int,
    pid              int,
    pid_username     text,
    query_username   text,
    pr               text,
    ni               text,
    virt_kb          bigint,
    res_kb           bigint,
    shr_kb           bigint,
    s                text,
    cpu              float,
    cpu_normalized   float,
    cpu_elapsed      float,
    mem              float,
    time             text,
    command          text,
    query_hash       text,
    query            text
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;


