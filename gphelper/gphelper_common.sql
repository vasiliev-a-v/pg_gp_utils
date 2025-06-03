-- \c postgres

-- эти переменные должны прийти сюда при вызове SQL-скрипта
-- \set date 20241108
-- \set gp_schema inc0022051

SET search_path TO :gp_schema,public;

\set tables_date   tables_:date
\set starts_date   starts_:date
\set stops_date    stops_:date
\set analysis_date analysis_:date
\set results_date  results_:date

-- Таблица с результатами резервного копирования:
\qecho создаём таблицу с результатами РК: :results_date
-- DROP TABLE IF EXISTS :results_date;
CREATE TABLE :results_date AS 
WITH
  strs_cte AS (
    SELECT strs.oid AS oid_start
         , min(strs.start) AS bkp_start_min
         , max(strs.start) AS bkp_start_max
      FROM :starts_date strs
     GROUP BY strs.oid
  ),

  stps_cte AS (
    SELECT stps.oid AS oid_stop
         , min(stps.finish)       AS bkp_stop_min
         , max(stps.finish)       AS bkp_stop_max
         , sum(stps.size)::bigint AS bkp_size 
      FROM :stops_date  stps
     GROUP BY stps.oid
  ),

  -- Размер скопированных разжатых данных в байтах
  bkp_size AS (
    SELECT sum(stps_cte.bkp_size) AS bytes
      FROM strs_cte
      JOIN stps_cte
        ON strs_cte.oid_start = stps_cte.oid_stop
      JOIN :tables_date
        ON strs_cte.oid_start = :tables_date.oid
  ),

  -- Время выполнения резервного копирования в секундах:
  bkp_secs AS (
    SELECT
       extract(epoch FROM (
         ( SELECT max(finish) FROM :stops_date  )::timestamp -
         ( SELECT min(start)  FROM :starts_date )::timestamp
       )
     ) AS seconds
  )

SELECT
       -- Время выполнения резервного копирования в секундах:
      bkp_secs.seconds

       -- Время начала резервного копирования:
     , (SELECT min(start)  FROM :starts_date )
         AS bkp_start

       -- Время завершнения резервного копирования:
     , (SELECT max(finish) FROM :stops_date  )
         AS bkp_finish

       -- Размер скопированных разжатых данных базы данных в байтах:
     , bkp_size.bytes
         AS bkp_bytes

       -- Размер скопированных разжатых данных в ТБ:
     , pg_size_pretty(bkp_size.bytes)
         AS bkp_hum

       -- backup_speed - скорость резервного копирования
     , CASE WHEN seconds = 0 THEN bkp_size.bytes
       ELSE (bkp_size.bytes / bkp_secs.seconds)::bigint
       END
         AS speed_sec

       -- backup_speed - скорость резервного копирования в красивых ед.
     , CASE WHEN seconds = 0 THEN bkp_size.bytes::text || ' byte'
       ELSE pg_size_pretty((bytes / seconds)::bigint)::text || '/sec'
       END
         AS speed_sec_h

  FROM bkp_secs, bkp_size
  DISTRIBUTED RANDOMLY
;



-- создаём таблицу для анализа
\qecho создаём таблицу для анализа: :analysis_date
-- DROP TABLE IF EXISTS :analysis_date;
CREATE TABLE :analysis_date WITH (
  appendonly = true,
  orientation = column,
  compresstype = zstd,
  compresslevel = 9
) 
AS 
WITH
  strs_cte AS (            -- Start CTE
    SELECT strs.oid        AS oid_start,
           min(strs.start) AS bkp_start_min,
           max(strs.start) AS bkp_start_max
      FROM :starts_date    AS strs
     GROUP BY strs.oid
  ),

  stps_cte AS (             -- Stop CTE
    SELECT stps.oid         AS oid_stop,
           min(stps.finish) AS bkp_stop_min,
           max(stps.finish) AS bkp_stop_max,
           sum(stps.size)   AS bkp_size 
      FROM :stops_date      AS stps
     GROUP BY stps.oid
  )

  SELECT
         -- схема и имя таблицы
         tables.tbl
           AS schema_table
         -- oid таблицы
       , strs_cte.oid_start
           AS oid
         -- минимальное время начала копирования на сегменте
       , strs_cte.bkp_start_min
           AS bkp_start_min
         -- максимальное время начала копирования на сегменте
       , strs_cte.bkp_start_max
           AS bkp_start_max

         -- Поле wait_start отображает разницу во времени
         -- старта копирования таблицы на разных сегментах.
         -- То есть, на одном сегменте таблица может стартовала раньше,
         -- на другом сегменте - позже.
         -- Желательно, чтобы wait_start должен быть минимальным.
         -- Разница в старте будет говорить о каких-то проблемах.
         -- В этом случае можно поискать сегмент(ы),
         -- на котором бэкап тормозит.
       , strs_cte.bkp_start_max - strs_cte.bkp_start_min
           AS wait_start

         -- минимальное время окончания копирования на сегменте
       , stps_cte.bkp_stop_min
           AS bkp_stop_min

         -- максимальное время окончания копирования на сегменте
       , stps_cte.bkp_stop_max
           AS bkp_stop_max

         -- Разница по сегментам между минимальным и максимальным
         -- временем завершения копирования таблицы.
         -- Большая разница говорит о перекосах таблицы (данных или CPU)
       , stps_cte.bkp_stop_max - stps_cte.bkp_stop_min
           AS wait_stop

         -- время копирования таблицы в часах и минутах
       , stps_cte.bkp_stop_max - strs_cte.bkp_start_min
           AS copy_time

         -- время копирования таблицы в секундах
       , extract (epoch FROM (stps_cte.bkp_stop_max - 
                              strs_cte.bkp_start_min
                  )
         ) AS copy_seconds

         -- размер скопированных разжатых данных в байтах
       , stps_cte.bkp_size
           AS sum_size_byte

         -- размер скопированных разжатых данных
       , pg_size_pretty(stps_cte.bkp_size)
           AS sum_size_human

         -- copy_speed - скорость копирования таблиц
       , CASE WHEN extract (epoch FROM (stps_cte.bkp_stop_max -
                                        strs_cte.bkp_start_min
                            )
                   ) = 0
              THEN stps_cte.bkp_size / 1
         ELSE stps_cte.bkp_size / 
              extract (epoch
                 FROM (stps_cte.bkp_stop_max -
                       strs_cte.bkp_start_min
                    )
              )
         END
           AS copy_speed

    FROM strs_cte
    JOIN stps_cte
      ON strs_cte.oid_start = stps_cte.oid_stop
    JOIN :tables_date         AS tables
      ON strs_cte.oid_start = tables.oid
   WHERE 1 = 1
  -- AND tables.gpid = ${gpid} -- при необходимости указать PID gpbackup

      -- Из выборки убраны таблицы,
      -- которые имеют нулевой размер
     AND stps_cte.bkp_size <> 0

      -- Также убраны такие таблицы,
      -- которые копировались менее 1 минуты (60 секунд).
      -- Потому что такие таблицы дают "ложно-медленный" результат.
     AND extract (epoch FROM (stps_cte.bkp_stop_max -
                              strs_cte.bkp_start_min
                  )
         ) > 60

   ORDER BY strs_cte.bkp_start_min
  DISTRIBUTED BY (oid)
;


\dt+

