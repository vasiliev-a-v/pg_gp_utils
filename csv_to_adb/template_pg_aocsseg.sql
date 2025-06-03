-- template_pg_aocsseg

CREATE TABLE IF NOT EXISTS public.$table (
    gp_segm_id    integer ,
    segno         integer ,
    tupcount      bigint  ,
    varblockcount bigint  ,
    vpinfo        bytea   ,
    modcount      bigint  ,
    formatversion smallint,
    state         smallint
)
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;

