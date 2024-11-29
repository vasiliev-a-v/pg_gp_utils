-- SQL-запрос делает
-- отчет о времени копирования таблиц

\c inc0022051

-- Скорость передачи данных можно посчитать на калькуляторе:
-- https://poschitat.online/skorost-peredachi-dannyh

-- 31299275722871 байт, 28 TB
-- 2024-11-08 16:07:48.000
-- 2024-11-08 22:47:47.000;
-- 23999


-- Сумма скачанных байт:
WITH
  strs_cte as (select strs.oid as oid_start, min(strs.start) as bkp_start_min, max(strs.start) as bkp_start_max from starts_20241108 strs group by strs.oid),
  stps_cte as (select stps.oid as oid_stop, min(stps.finish) as bkp_stop_min, max(stps.finish) as bkp_stop_max, sum(stps.size) as bkp_size 
from stops_20241108 stps group by stps.oid)
select
sum(stps_cte.bkp_size) as sum_size_byte, -- размер скопированных разжатых данных в байтах
pg_size_pretty(sum(stps_cte.bkp_size)) as sum_size_human -- размер скопированных разжатых данных
from strs_cte
join stps_cte on strs_cte.oid_start = stps_cte.oid_stop
join tables_20241108 as tables on strs_cte.oid_start = tables.oid;
\quit



WITH
  strs_cte AS (
    SELECT strs.oid        AS oid_start,
           min(strs.start) AS bkp_start_min,
           max(strs.start) AS bkp_start_max
      FROM starts_${date}  AS strs
     GROUP BY strs.oid
  ),
  stps_cte AS (
    SELECT stps.oid AS oid_stop,
           min(stps.finish) AS bkp_stop_min,
           max(stps.finish) AS bkp_stop_max,
           sum(stps.size)   AS bkp_size 
      FROM stops_${date}    AS stps
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
         ) AS copy_time_sec,

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
    JOIN :tables_date AS tables
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

   ORDER BY strs_cte.bkp_start_min;






\quit
-- Запрос от Артёма
WITH
strs_cte as (select strs.oid as oid_start, min(strs.start) as bkp_start_min, max(strs.start) as bkp_start_max from starts_20241108 strs group by strs.oid),
stps_cte as (select stps.oid as oid_stop, min(stps.finish) as bkp_stop_min, max(stps.finish) as bkp_stop_max, sum(stps.size) as bkp_size 
from stops_20241108 stps group by stps.oid)
select
tables.tbl as schema_table_name, -- схема и имя таблицы
strs_cte.oid_start as oid, -- oid таблицы
strs_cte.bkp_start_min as bkp_start_min, -- минимальное время начала копирования на сегменте
strs_cte.bkp_start_max as bkp_start_max, -- максимальное время начала копирования на сегменте
strs_cte.bkp_start_max - strs_cte.bkp_start_min as wait_start, -- разница между действиями start
stps_cte.bkp_stop_min as bkp_stop_min, -- минимальное время окончания копирования на сегменте
stps_cte.bkp_stop_max as bkp_stop_max, -- максимальное время окончания копирования на сегменте
stps_cte.bkp_stop_max - stps_cte.bkp_stop_min as wait_stop, -- разница между действиями stop
stps_cte.bkp_stop_max - strs_cte.bkp_start_min as execute, -- разница между максимальное время окончания копирования и минимальное время начала копирования
stps_cte.bkp_size as sum_size_byte, -- размер скопированных разжатых данных в байтах
pg_size_pretty(stps_cte.bkp_size) as sum_size_human -- размер скопированных разжатых данных
,EXTRACT(EPOCH FROM (stps_cte.bkp_stop_max - strs_cte.bkp_start_min)) as time_s,
CASE WHEN EXTRACT(EPOCH FROM (stps_cte.bkp_stop_max - strs_cte.bkp_start_min))=0 THEN stps_cte.bkp_size/1
            ELSE stps_cte.bkp_size/EXTRACT(EPOCH FROM (stps_cte.bkp_stop_max - strs_cte.bkp_start_min))  end as speed
from strs_cte
join stps_cte on strs_cte.oid_start = stps_cte.oid_stop
join tables_20241108 as tables on strs_cte.oid_start = tables.oid
--where tables.gpid = <GPID> -- при необходимости указать PID gpbackup
where stps_cte.bkp_size <> 0 and EXTRACT(EPOCH FROM (stps_cte.bkp_stop_max - strs_cte.bkp_start_min))>60
order by strs_cte.bkp_start_min;



