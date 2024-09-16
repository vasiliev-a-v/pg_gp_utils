-- check_data_skew

CREATE TABLE IF NOT EXISTS public.$table (
    table_database   text,
    table_schema     text,
    table_name       text,
    total_size_mb    numeric(15,2),
    blocked_space_mb numeric(15,2),
    skew             numeric(15,2),
    seg_min_size_mb  numeric(15,2),
    seg_max_size_mb  numeric(15,2),
    seg_avg_size_mb  numeric(15,2),
    empty_seg_cnt    int
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;
