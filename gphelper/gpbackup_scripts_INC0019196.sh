#!/bin/bash

# минимальный старт, максимальный финиш группировать по oid.
# вариант для gpbackup:
# вывести отчет о времени копирования таблиц:


sudo -iu gpadmin

date=20240315
ticket=INC0019196
tst_db=gpadmin

psql -d $tst_db << EOF
SET search_path TO ${ticket};
SHOW search_path;

WITH
  strs_cte as (
    SELECT strs.oid as oid_start
         , min(strs.start) as bkp_start_min
         , max(strs.start) as bkp_start_max
      FROM starts_${date} strs
     GROUP BY strs.oid
    ),
  stps_cte as (
    SELECT 
           stps.oid as oid_stop
         , min(stps.finish) as bkp_stop_min
         , max(stps.finish) as bkp_stop_max
         , sum(stps.size) as bkp_size
      FROM stops_${date} stps
     GROUP BY stps.oid
    )
  SELECT
--         tables.table as schema_table_name, -- схема и имя таблицы
         strs_cte.oid_start as oid, -- oid таблицы
         
         strs_cte.bkp_start_min                          as bkp_start_min, -- минимальное время начала копирования на сегменте
         strs_cte.bkp_start_max                          as bkp_start_max, -- максимальное время начала копирования на сегменте
         strs_cte.bkp_start_max - strs_cte.bkp_start_min as wait_start,    -- разница между действиями start
         stps_cte.bkp_stop_min                           as bkp_stop_min,  -- минимальное время окончания копирования на сегменте
         stps_cte.bkp_stop_max                           as bkp_stop_max,  -- максимальное время окончания копирования на сегменте
         stps_cte.bkp_stop_max - stps_cte.bkp_stop_min   as wait_stop,     -- разница между действиями stop
         stps_cte.bkp_stop_max - strs_cte.bkp_start_min  as execute,       -- разница между максимальное время окончания копирования и минимальное время начала копирования
         stps_cte.bkp_size                               as sum_size_byte, -- размер скопированных разжатых данных в байтах
         pg_size_pretty(stps_cte.bkp_size)               as sum_size_human -- размер скопированных разжатых данных
    FROM strs_cte
    JOIN stps_cte
      ON strs_cte.oid_start = stps_cte.oid_stop
--  JOIN tables_${date} tables ON strs_cte.oid_start = tables.oid
-- WHERE tables.gpid = <GPID> -- при необходимости указать PID gpbackup
   ORDER BY strs_cte.bkp_start_min;
EOF

exit 0
exit 0


