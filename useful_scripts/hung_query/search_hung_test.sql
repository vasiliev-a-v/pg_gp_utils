-- Based on ticket: INC0020873
\x

-- \dfS gp_dist_wait_status

SELECT * FROM pg_proc WHERE proname = 'gp_dist_wait_status';

\quit

SELECT * FROM pg_catalog.gp_dist_wait_status();
\quit



-- Search hung SQL-queries.
-- This is such queries, which have no process on master.

-- \d pg_stat_activity
-- \q


-- Запрос на поиск зависших сессий
-- Сессии, которые есть на мастере

-- CREATE TEMP TABLE master_sessions AS
    -- SELECT sess_id
      -- FROM pg_stat_activity
     -- WHERE sess_id > 0
  -- DISTRIBUTED BY (sess_id);

-- SELECT count(*) FROM master_sessions;

-- CREATE TEMP TABLE segment_sessions AS
    -- SELECT sess_id
      -- FROM (
             -- SELECT gp_segment_id,
                    -- (pg_stat_get_activity(NULL::integer)).*
               -- FROM gp_dist_random('gp_id')
           -- ) psga
     -- WHERE sess_id > 0
     -- GROUP BY sess_id
  -- DISTRIBUTED BY (sess_id);

-- SELECT count(*) FROM master_sessions;

-- SELECT sess_id FROM segment_sessions;
-- SELECT sess_id FROM master_sessions;

-- SELECT sess_id FROM segment_sessions
-- EXCEPT
-- SELECT sess_id FROM master_sessions
-- ;
-- \quit


WITH master_sessions AS (
    -- SELECT generate_series(2, 9) AS sess_id
    -- SELECT count((pg_stat_get_activity(NULL::integer)).sess_id) sess_id
    SELECT sess_id
      FROM pg_stat_activity
     WHERE sess_id > 0
  )
  -- Сессии, которые есть на сегментах
  , segment_sessions AS (
    -- SELECT generate_series(1, 10) AS sess_id
    SELECT sess_id
      FROM (
             SELECT gp_segment_id,
                    (pg_stat_get_activity(NULL::integer)).*
               FROM gp_dist_random('gp_id')
           ) psga
     WHERE sess_id > 0
     GROUP BY sess_id
  )
  -- Вычисляем разность: сессии, которые есть на сегментах, но отсутствуют на мастере
  SELECT sess_id
    FROM segment_sessions
  -- UNION ALL
  EXCEPT
  SELECT sess_id
    FROM master_sessions
   WHERE sess_id > 0
;
\q


SELECT sess_id
  FROM (SELECT (pg_stat_get_activity(NULL::integer)).sess_id) psga 
 ORDER BY 1;
-- \q

SELECT 
       sess_id
  FROM (
         SELECT gp_segment_id,
                (pg_stat_get_activity(NULL::integer)).*
           FROM gp_dist_random('gp_id')
     ) psga
 WHERE sess_id > 0
 GROUP BY sess_id
 ORDER BY 1
;

\q

-- находит все сессии
SELECT 
       sess_id,
       gp_segment_id,
       pid,
       substr(query, 1, 70)
  FROM (
         SELECT gp_segment_id,
                (pg_stat_get_activity(NULL::integer)).*
           FROM gp_dist_random('gp_id')
     ) psga
 WHERE sess_id > 0
          -- GROUP BY sess_id
 ORDER BY sess_id, gp_segment_id
;

\q


Нужен SQL-запрос, который с помощью функции (pg_stat_get_activity(NULL::integer)).*
будет находить сессии, которые присутствуют только на сегментах, но отсутствуют на мастере.

Есть запрос, который собирает sess_id с мастера:
SELECT (pg_stat_get_activity(NULL::integer)).sess_id
Есть запрос, который собирает sess_id с сегментов:
SELECT 
       sess_id
  FROM (
         SELECT gp_segment_id,
                (pg_stat_get_activity(NULL::integer)).*
           FROM gp_dist_random('gp_id')
     ) psga
 WHERE sess_id > 0
 GROUP BY sess_id
;

Как соединить эти два запроса, чтобы получить те sess_id, которые есть на сегментах, но отсутствуют на мастере?






