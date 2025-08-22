\c ADWH

SELECT gp_segment_id, (row).*
  FROM (
  SELECT gp_segment_id,
         (SELECT t AS t_row FROM pg_stat_activity t WHERE query ~ 'pg_stat_activity') row
    FROM gp_dist_random('gp_id')
  ) t
;


\q
SELECT 
       g.gp_segment_id, sess_id, 
       array(SELECT t FROM (SELECT t.datname, t.pid, t.usename) t),
       substr(query, 1, 40)
    --~ t.*
FROM
    gp_dist_random('gp_id') g
JOIN
    pg_stat_activity t
ON
      1 = 1
WHERE 1 = 1
  AND query ~ 'pg_stat_activity'
ORDER BY g.gp_segment_id
;
\q
\x \\
SELECT g.gp_segment_id, t.pronamespace, t.proowner
  FROM gp_dist_random('gp_id') g
  JOIN pg_proc t
    ON 1 = 1
 WHERE proname = 'boolin'
 ORDER BY g.gp_segment_id
;
\x
\q

datid           
datname         
pid             
sess_id         
usesysid        
usename         
application_name
client_addr     
client_hostname 
client_port     
backend_start   
xact_start      
query_start     
state_change    
waiting         
state           
backend_xid     
backend_xmin    
query           
waiting_reason  
rsgid           
rsgname         
rsgqueueduration


                             Представление "pg_catalog.pg_stat_activity"
     Столбец      |           Тип            | Правило сортировки | Допустимость NULL | По умолчанию 
------------------+--------------------------+--------------------+-------------------+--------------
 datid            | oid                      |                    |                   | 
 datname          | name                     |                    |                   | 
 pid              | integer                  |                    |                   | 
 sess_id          | integer                  |                    |                   | 
 usesysid         | oid                      |                    |                   | 
 usename          | name                     |                    |                   | 
 application_name | text                     |                    |                   | 
 client_addr      | inet                     |                    |                   | 
 client_hostname  | text                     |                    |                   | 
 client_port      | integer                  |                    |                   | 
 backend_start    | timestamp with time zone |                    |                   | 
 xact_start       | timestamp with time zone |                    |                   | 
 query_start      | timestamp with time zone |                    |                   | 
 state_change     | timestamp with time zone |                    |                   | 
 waiting          | boolean                  |                    |                   | 
 state            | text                     |                    |                   | 
 backend_xid      | xid                      |                    |                   | 
 backend_xmin     | xid                      |                    |                   | 
 query            | text                     |                    |                   | 
 waiting_reason   | text                     |                    |                   | 
 rsgid            | oid                      |                    |                   | 
 rsgname          | text                     |                    |                   | 
 rsgqueueduration | interval                 |                    |                   | 


В SQL-запросе №1:
```
SELECT gp_segment_id, (row).*
  FROM (
  SELECT gp_segment_id,
         (SELECT t AS t_row FROM pg_stat_all_tables t WHERE relname = 'pg_class') row
    FROM gp_dist_random('gp_id')
  ) t
;
```
Данный подзапрос:
```
SELECT t AS t_row FROM pg_stat_all_tables t WHERE relname = 'pg_class'
```
Возвращает по одной строке с каждого сегмента.

В SQL-запросе №2:
SELECT gp_segment_id, (row).*
  FROM (
  SELECT gp_segment_id,
         (SELECT t AS t_row FROM pg_proc t WHERE 1 = 1) row
    FROM gp_dist_random('gp_id')
  ) t
;
Возвращается больше строк с сегмента.
Поэтому запрос возвращает ошибку:
psql:/projects/bash/arena_scripts/useful_scripts/gp_dist_random_gp_id.sql:12: ERROR:  more than one row returned by a subquery used as an expression

Как реализовать SQL-запрос №2, чтобы он мог возвращать больше одной строки с каждого сегмента?



\q
SELECT t AS t_row FROM pg_proc t;
\q
SELECT gp_segment_id, (row).*
  FROM (
  SELECT gp_segment_id,
         (SELECT t AS t_row FROM pg_proc t) row
    FROM gp_dist_random('gp_id')
  ) t
;
\q
SELECT gp_segment_id, (row).*
  FROM (
  SELECT gp_segment_id,
         (SELECT t AS t_row FROM pg_stat_all_tables t WHERE relname = 'pg_class') row
    FROM gp_dist_random('gp_id')
  ) t
;
