-- adbmon.t_audit_locks_usage

CREATE TABLE IF NOT EXISTS public.$table (
    datname          name                     ,
    dtm              timestamp with time zone ,
    locked_item      text                     ,
    waiting_duration interval                 ,
    locked_pid       integer                  ,
    locked_user      name                     ,
    locked_query     text                     ,
    locked_mode      text                     ,
    locking_pid      integer                  ,
    locking_user     name                     ,
    locking_query    text                     ,
    locking_mode     text
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;
