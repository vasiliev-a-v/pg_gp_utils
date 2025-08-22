-- common

CREATE TABLE IF NOT EXISTS public.$table (
    LIKE $schema.$table
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 9
       )
  DISTRIBUTED RANDOMLY
;


-- \quit
-- pg_dump --schema-only -d template1 -t gp_toolkit.gp_resgroup_status -f /tmp/gp_toolkit.gp_resgroup_status.dll.dump
