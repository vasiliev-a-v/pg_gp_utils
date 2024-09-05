\c ADWH
\echo
\echo pg_aoseg.pg_aocsseg_844920
SELECT gp_segment_id,
       pg_stat_get_blocks_fetched(c.oid) heap_blks_fetched,
       pg_stat_get_blocks_hit(c.oid) AS heap_blks_hit
  FROM gp_dist_random('gp_id'), (SELECT 'pg_aoseg.pg_aocsseg_844920'::regclass::oid) c
;
\q
SELECT gp_segment_id, * FROM gp_dist_random('test_table2') WHERE gp_segment_id = 3;
SELECT gp_segment_id, * FROM test_table2 WHERE gp_segment_id = 3;
SELECT gp_segment_id, * FROM test_table2 WHERE gp_segment_id = 3;
SELECT gp_segment_id, * FROM test_table2 WHERE gp_segment_id = 3;

\echo 
\echo Выйдем из базы
\c adb

\echo
\echo Зайдем в базу
\c gpadmin

\echo 
\echo Статистика по gp_segment_id обновилась:
SELECT gp_segment_id,
       pg_stat_get_blocks_fetched(c.oid) heap_blks_fetched,
       pg_stat_get_blocks_hit(c.oid) AS heap_blks_hit
  FROM gp_dist_random('gp_id'), (SELECT 'test_table2'::regclass::oid) c
;

\q
