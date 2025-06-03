 \c test_vacuum_oom


CREATE OR REPLACE FUNCTION dynamic_gp_dist_random(table_name text)
RETURNS SETOF RECORD AS $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE '
      SELECT gp_segment_id, * FROM ' || table_name || '
       UNION ALL
      SELECT gp_segment_id, *
        FROM gp_dist_random(' || quote_literal(table_name) || ')
       ORDER BY gp_segment_id;'
    LOOP
        RETURN NEXT rec;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


WITH wa AS (
            SELECT a.relid,
                   a.segrelid,
                   a.columnstore
              FROM pg_catalog.pg_appendonly a
         )
  SELECT wa.columnstore,
         n.nspname || '.' || c.relname AS table_name,
         wa.relid,
         wa.segrelid::regclass AS segrelid_name,
         wa.segrelid AS segrelid_oid,
         coalesce((
         sum(d.tupcount) FILTER (WHERE d.gp_segment_id  = -1)), 0)
           AS m_tupcount,
         coalesce((
         sum(d.tupcount) FILTER (WHERE d.gp_segment_id != -1)), 0)
           AS s_tupcount
    FROM wa
    JOIN pg_class c ON wa.relid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    LEFT JOIN LATERAL (

         -- Для AOCO-таблиц:
         SELECT 
                gp_segment_id, 
                tupcount
           FROM dynamic_gp_dist_random(wa.segrelid::regclass::text)
             AS t (
                   gp_segment_id integer, 
                   segno integer,
                   tupcount bigint, 
                   varblockcount bigint,
                   vpinfo bytea, 
                   modcount bigint,
                   formatversion smallint, 
                   state smallint
                )
          WHERE wa.columnstore = 't'
            AND state != 2

   UNION ALL

         -- Для AORO-таблиц:
         SELECT 
                gp_segment_id, 
                tupcount
           FROM dynamic_gp_dist_random(wa.segrelid::regclass::text)
             AS t (
                   gp_segment_id integer, 
                   segno integer,
                   eof bigint, 
                   tupcount bigint,
                   varblockcount bigint, 
                   eofuncompressed bigint,
                   modcount bigint, 
                   formatversion smallint,
                   state smallint
                )
          WHERE wa.columnstore != 't'
            AND state != 2
       ) d ON true
  GROUP BY wa.columnstore, table_name,
           relid, segrelid_name, segrelid_oid
;

