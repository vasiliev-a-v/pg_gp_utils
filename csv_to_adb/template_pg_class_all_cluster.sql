-- pg_class from all cluster
-- template_pg_class_all_cluster.sql

CREATE TABLE IF NOT EXISTS public.$table (
    gp_segm_id     integer ,
    oid            oid     ,
    relname        name    ,    relnamespace   oid     ,
    reltype        oid     ,    reloftype      oid     ,
    relowner       oid     ,    relam          oid     ,
    relfilenode    oid     ,    reltablespace  oid     ,
    relpages       integer ,    reltuples      real    ,
    relallvisible  integer ,    reltoastrelid  oid     ,
    relhasindex    boolean ,    relisshared    boolean ,
    relpersistence "char"  ,    relkind        "char"  ,
    relstorage     "char"  ,    relnatts       smallint,
    relchecks      smallint,    relhasoids     boolean ,
    relhaspkey     boolean ,    relhasrules    boolean ,
    relhastriggers boolean ,    relhassubclass boolean ,
    relispopulated boolean ,    relreplident   "char"  ,
    relfrozenxid   xid     ,    relminmxid     xid     ,
    relacl         text[]  ,    reloptions     text[]
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;
