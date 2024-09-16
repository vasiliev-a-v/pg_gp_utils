-- pg_locks

CREATE TABLE IF NOT EXISTS public.$table (
    locktype           text    ,    database           oid     ,
    relation           oid     ,    page               integer ,
    tuple              smallint,    virtualxid         text    ,
    transactionid      xid     ,    classid            oid     ,
    objid              oid     ,    objsubid           smallint,
    virtualtransaction text    ,    pid                integer ,
    mode               text    ,    granted            boolean ,
    fastpath           boolean ,    mppsessionid       integer ,
    mppiswriter        boolean ,    gp_seg_id          integer
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;
