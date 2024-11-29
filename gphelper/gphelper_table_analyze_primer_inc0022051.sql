-- SQL-запрос делает
-- отчет о времени копирования таблиц

\c inc0022051


-- SELECT * FROM helper_log_20241108 LIMIT 10;
-- \quit


-- - Реальный размер бэкапа можно посмотреть в Отчете:
-- sum_size_byte, -- размер скопированных разжатых данных в байтах
-- сумма этого столбца - будет размер бэкапа

-- Время начала и время
-- sum_size_byte / (bkp_stop_max - bkp_start_min) = скорость таблички


-- 1. Реальный размер бэкапа можно посмотреть в Отчете
-- 2. Время начала и время отдельных таблиц
-- 3. какой сегмент дольше всех копировался?


Поле wait_start отображает разницу во времени старта копирования таблицы на разных сегментах.
То есть, на одном сегменте таблица может стартовала раньше, другая позже.
Желательно, чтобы wait_start должен быть минимальным.
Разница в старте будет говорить о каких-то проблемах.
В этом случае можно поискать сегмент(ы), на котором бэкап тормозит.

Поле wait_stop отображает разницу во времени самого раннего и самого позднего завершения копирования таблицы на разных сегментах.
Если wait_stop большой, то это говорит либо о перекосе нагрузки, либо о перекосе данных таблицы.
В этом случае, самые поздние сегменты должны будут содержать наибольшее количество данных (перекос), либо если перекоса данных нет, то проблема с перекосом вычислений (CPU, аппаратная проблема с сервером).



\set date 20241108
\set tables_date tables_:date
\set starts_date starts_:date
\set stops_date  stops_:date

-- \dt+
-- \quit


WITH
  strs_cte AS (
    SELECT strs.oid        AS oid_start,
           min(strs.start) AS bkp_start_min,
           max(strs.start) AS bkp_start_max
      FROM :starts_date  AS strs
     GROUP BY strs.oid
  ),
  stps_cte AS (
    SELECT stps.oid AS oid_stop,
           min(stps.finish) AS bkp_stop_min,
           max(stps.finish) AS bkp_stop_max,
           sum(stps.size)   AS bkp_size 
      FROM :stops_date      AS stps
     GROUP BY stps.oid
  )
  SELECT
         tables.tbl               AS schema_table,  -- схема и имя таблицы
         strs_cte.oid_start       AS oid,           -- oid таблицы
         strs_cte.bkp_start_min   AS bkp_start_min, -- минимальное время начала копирования на сегменте
         strs_cte.bkp_start_max   AS bkp_start_max, -- максимальное время начала копирования на сегменте
         strs_cte.bkp_start_max - strs_cte.bkp_start_min AS wait_start,    -- разница между действиями start
         stps_cte.bkp_stop_min    AS bkp_stop_min,  -- минимальное время окончания копирования на сегменте
         stps_cte.bkp_stop_max    AS bkp_stop_max,  -- максимальное время окончания копирования на сегменте
         stps_cte.bkp_stop_max - stps_cte.bkp_stop_min  AS wait_stop,     -- разница между действиями stop
         stps_cte.bkp_stop_max - strs_cte.bkp_start_min AS execute,       -- разница между максимальным временем конца копирования
                                                                          -- и минимальным временем начала копирования
         stps_cte.bkp_size        AS sum_size_byte, -- размер скопированных разжатых данных в байтах
         pg_size_pretty(stps_cte.bkp_size)     AS sum_size_human -- размер скопированных разжатых данных
    FROM strs_cte
    JOIN stps_cte
      ON strs_cte.oid_start = stps_cte.oid_stop
    JOIN :tables_date AS tables
      ON strs_cte.oid_start = tables.oid
   -- WHERE tables.gpid = ${gpid} -- при необходимости указать PID gpbackup
   ORDER BY strs_cte.bkp_start_min;


