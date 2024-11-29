create temp table fastest_dr_20240325 as (with max_speed_seg_cte as (
                            select max(speed_b_s) as sp, 
                                   oid from seg_times_dr_20240325 
                             where size != 0 
                          group by oid) 
                         select st.oid, 
                                st.segment, 
                                st.speed_mb_s, 
                                st.speed_b_s, 
                                st.duration
                           from seg_times_dr_20240325 st, max_speed_seg_cte ms where st.oid = ms.oid and st.speed_b_s = ms.sp) distributed by (oid);
                           
create temp table slowest_dr_20240325 as (with min_speed_seg_cte as (
                            select min(speed_b_s) as sp, 
                                   oid from seg_times_dr_20240325 
                             where size != 0 
                          group by oid) 
                         select st.oid, 
                                st.segment, 
                                st.speed_mb_s, 
                                st.speed_b_s, 
                                st.duration
                           from seg_times_dr_20240325 st, min_speed_seg_cte ms where st.oid = ms.oid and st.speed_b_s = ms.sp) distributed by (oid);

create temp table min_time_dr_20240325 as (with min_time_seg_cte as (
                            select min(duration_sec) as d, 
                                   oid from seg_times_dr_20240325 
                             where size != 0 
                          group by oid) 
                         select st.oid, 
                                st.segment, 
                                st.speed_mb_s, 
                                st.speed_b_s, 
                                st.duration
                           from seg_times_dr_20240325 st, min_time_seg_cte mt where st.oid = mt.oid and st.duration_sec = mt.d) distributed by (oid);
                           
create temp table max_time_dr_20240325 as (with max_time_seg_cte as (
                            select max(duration_sec) as d, 
                                   oid from seg_times_dr_20240325 
                             where size != 0 
                          group by oid) 
                         select st.oid, 
                                st.segment, 
                                st.speed_mb_s, 
                                st.speed_b_s, 
                                st.duration
                           from seg_times_dr_20240325 st, max_time_seg_cte mt where st.oid = mt.oid and st.duration_sec = mt.d) distributed by (oid);

CREATE TABLE table_times_dr_20240325 AS (
WITH strs_cte AS (
    SELECT strs.oid AS oid_start, 
           MIN(strs.start_time) AS bkp_start_min 
      FROM seg_times_dr_20240325 strs 
  GROUP BY strs.oid),
stps_cte AS (
    SELECT stps.oid AS oid_stop, 
           MAX(stps.stop_time) AS bkp_stop_max,
           SUM(stps.size) AS bkp_size
      FROM seg_times_dr_20240325 stps 
  GROUP BY stps.oid),
f1 AS (
    SELECT MIN(segment) AS seg_id, 
           oid 
      FROM fastest_dr_20240325 
  GROUP BY oid, 
           speed_b_s),
s1 AS (
    SELECT MIN(segment) AS seg_id, 
           oid 
      FROM slowest_dr_20240325
  GROUP BY oid, 
           speed_b_s),
min_time1 AS (
    SELECT MIN(segment) AS seg_id,
           oid
      FROM min_time_dr_20240325
  GROUP BY oid,
           duration),
max_time1 AS (
    SELECT MIN(segment) AS seg_id,
           oid
      FROM max_time_dr_20240325
  GROUP BY oid,
           duration),
seg_cnt AS (
    SELECT COUNT(1) AS cnt,
           oid
      FROM seg_times_dr_20240325
     WHERE size != 0
  GROUP BY oid)
select t.gpid,
       t.worker_num,
       t.worker_id,       
       t.table_name, 
       t.oid,
       t.bkp_start as bkp_prepare,
       strs_cte.bkp_start_min AS bkp_start, 
       stps_cte.bkp_stop_max AS bkp_stop,
       stps_cte.bkp_size,
       PG_SIZE_PRETTY(stps_cte.bkp_size) AS size_human,
       stps_cte.bkp_stop_max - strs_cte.bkp_start_min AS duration,
       EXTRACT('epoch' FROM stps_cte.bkp_stop_max - strs_cte.bkp_start_min) AS duration_sec,
       stps_cte.bkp_size / CASE EXTRACT('epoch' FROM stps_cte.bkp_stop_max - strs_cte.bkp_start_min)::int
                               WHEN 0 THEN 1
                               ELSE EXTRACT('epoch' FROM stps_cte.bkp_stop_max - strs_cte.bkp_start_min)::int
                           END AS speed_byte_per_sec,
       ROUND(CAST(stps_cte.bkp_size / CASE EXTRACT('epoch' FROM stps_cte.bkp_stop_max - strs_cte.bkp_start_min)
                                          WHEN 0 THEN 1
                                          ELSE EXTRACT('epoch' FROM stps_cte.bkp_stop_max - strs_cte.bkp_start_min)
                                      END /1024/1024 AS NUMERIC),2) AS speed_MB_per_sec,
       f1.seg_id AS fastest_seg,
       f2.speed_b_s AS fastest_speed,
       f2.speed_mb_s AS fastest_speed_MB,
       f2.duration AS fastest_duration,
       s1.seg_id AS slowest_seg,
       s2.speed_b_s AS slowest_speed,
       s2.speed_mb_s AS slowest_speed_MB,
       s2.duration AS slowest_duration,
       min_time1.seg_id AS min_time_seg,
       min_time_dr_20240325.speed_b_s AS min_time_speed,
       min_time_dr_20240325.speed_mb_s AS min_time_speed_MB,
       min_time_dr_20240325.duration AS min_time_duration,
       max_time1.seg_id AS max_time_seg,
       max_time_dr_20240325.speed_b_s AS max_time_speed,
       max_time_dr_20240325.speed_mb_s AS max_time_speed_MB,
       max_time_dr_20240325.duration AS max_time_duration,
       seg_cnt.cnt AS seg_cnt
  FROM tables_dr_20240325 t
  JOIN strs_cte ON strs_cte.oid_start = t.oid
  JOIN stps_cte ON stps_cte.oid_stop = t.oid
  JOIN f1 ON f1.oid = t.oid
  JOIN fastest_dr_20240325 f2 ON f2.oid = f1.oid
                 AND f2.segment = f1.seg_id
  JOIN s1 ON s1.oid = t.oid
  JOIN slowest_dr_20240325 s2 ON s2.oid = s1.oid
                 AND s2.segment = s1.seg_id 
  JOIN min_time1 ON min_time1.oid = t.oid
  JOIN min_time_dr_20240325 ON min_time_dr_20240325.oid = min_time1.oid
               AND min_time_dr_20240325.segment = min_time1.seg_id
  JOIN max_time1 ON max_time1.oid = t.oid
  JOIN max_time_dr_20240325 ON max_time_dr_20240325.oid = max_time1.oid
               AND max_time_dr_20240325.segment = max_time1.seg_id
  JOIN seg_cnt ON seg_cnt.oid = t.oid)
  DISTRIBUTED BY (oid);