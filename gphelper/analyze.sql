-- SELECT * FROM table;
\c gpadmin

\set my_date 20240214
\set ticket INC0018856

SET search_path TO :ticket;

SELECT content
  FROM start_stop
 WHERE host = 'p0dtpl-ad2054xp'
 ORDER BY content
;
\q

\o /a/INC/INC0018856/analyze_delay.log
\echo Разница между началом предыдущего и началом нового восстановления по сегментам
SELECT row_number() over() num
     , t2.content seg
     , t2.finish "конец прошлого"
     , t1.content seg
     , t1.start "начало нового"
     , t1.start - t2.finish "простой"
  FROM (SELECT row_number() over() num, * FROM start_stop ORDER BY start) t1
  JOIN (SELECT row_number() over() num, * FROM start_stop ORDER BY start) t2
    ON t2.num = (t1.num - 1)
 WHERE t1.num > 1
   AND t1.num <= 600
;

\o /a/INC/INC0018856/analyze_start_finish.log
\echo Начало и окончание восстановления по сегментам
SELECT 
       strt.content
     , strt.oid
     , strt.start
     , stop.finish
     , (stop.finish - strt.start) copied_time
     , stop.host
     , stop.size
  FROM starts_:my_date strt
  JOIN stops_:my_date  stop
       USING(content)
 ORDER BY strt.start
;

\q
DROP TABLE IF EXISTS start_stop;
CREATE TABLE IF NOT EXISTS start_stop
  (
     content integer
   , oid     integer
   , start   timestamp
   , finish   timestamp
   , copied  interval
   , host    text
   , size    bigint
  )
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 3
       )
  DISTRIBUTED BY (oid);
;

\q
INSERT INTO start_stop
SELECT 
       strt.content
     , strt.oid
     , strt.start
     , stop.finish
     , (stop.finish - strt.start) copied
     , stop.host
     , stop.size
  FROM starts_:my_date strt
  JOIN stops_:my_date  stop
       USING(content)
 ORDER BY strt.start
 --~ ORDER BY strt.content
  --~ LIMIT 40
;


