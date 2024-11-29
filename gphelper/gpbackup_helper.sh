#!/bin/bash
# Данные скрипты для восстановления через ddboost gprestore 

ticket=INC0018856
tst_host=avas-dwm1
tst_db=gpadmin
tst_user=avas
tst_schema=$ticket
path=/a/INC/$ticket/dr
date=20240214

# скопировать со своего компьютера на свой тестовый кластер ADB:
scp -r $path/gpbackup_helper.tar.gz $tst_user@$tst_host:/tmp
scp    $path/gprestore_$date.log    $tst_user@$tst_host:/tmp



# 
ssh $tst_user@$tst_host -q -T << EOF
chmod 0666 /tmp/gpbackup_helper.tar.gz
chmod 0666 /tmp/gprestore_${date}.log
sudo -iu gpadmin

psql -d ${tst_db} -c "
CREATE SCHEMA IF NOT EXISTS $tst_schema;
CREATE TABLE IF NOT EXISTS $tst_schema.helper_log_${date}
  (number int, line text)
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 3
       )
  DISTRIBUTED BY (number);

CREATE TABLE IF NOT EXISTS $tst_schema.gprestore_${date} (line text)
  WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 3
       )
  DISTRIBUTED RANDOMLY;
"

cd /tmp/
tar tf gpbackup_helper.tar.gz | \
  grep 'tar.gz' | \
  grep ${date} | \
  xargs -i -n1 -I {} \
  sh -c "tar xf gpbackup_helper.tar.gz {} -O | \
  tar xz -O" | \
  nl | \
  psql -d ${tst_db} -c "\copy ${tst_schema}.helper_log_${date} from stdin"

cat /tmp/gprestore_${date}.log | \
  psql -d ${tst_db} -c "\copy ${tst_schema}.gprestore_${date} from stdin with (FORMAT text, DELIMITER \"^\")"

psql -d ${tst_db} -c "
DROP TABLE IF EXISTS ${tst_schema}.starts_${date};
CREATE TABLE ${tst_schema}.starts_${date} WITH (
        appendonly    = true,
        orientation   = column,
        compresstype  = zstd,
        compresslevel = 3
       )
  AS SELECT (sizes[1] || ' ' || sizes[2])::timestamp AS start,   -- время начала копирования
             sizes[3]::int AS content, -- сегмент
             sizes[4]::int AS oid      -- oid таблицы
  FROM (
         SELECT
           regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:\S+:\S+:\d+-\[\w+\]:-Segment (\d+): Oid (\d+):') sizes
           FROM $tst_schema.helper_log_${date}
          WHERE line LIKE '%: Start table restore%'
       ) AS s
    DISTRIBUTED BY (oid);

DROP TABLE IF EXISTS ${tst_schema}.stops_${date};
CREATE TABLE ${tst_schema}.stops_${date} AS SELECT 
 (sizes[1] || ' ' || sizes[2])::timestamp as finish, -- время окончания копирования
  sizes[3] as host,
  sizes[4]::int as content, -- сегмент
  sizes[5]::int as oid,     -- oid таблицы
  sizes[6]::bigint as size  -- размер скопированных разжатых данных в байтах
FROM (
       SELECT regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:\S+:(\S+):\d+-\[\w+\]:-Segment (\d+): Oid (\d+): Copied (\d+) bytes') sizes
         FROM $tst_schema.helper_log_${date}
        WHERE line like '%: Copied%'
     ) AS s
  DISTRIBUTED BY (oid);
"
exit 0
exit 0
EOF

exit 0



-- вариант для backup:
date=20240214
ticket=INC0018856
tst_db=gpadmin
psql -d $tst_db << EOF
SET  search_path TO ${ticket};
SHOW search_path;
CREATE TABLE tables_${date} AS SELECT
             sizes[3]::int as oid, -- oid таблицы
             sizes[2] as table,    -- схема и имя таблицы
             sizes[1]::int as gpid -- PID gpbackup
  FROM (
        SELECT regexp_matches(line, '^\d+:\d{2}:\d{2}:\d{2} \S+:(\d+)-\[\w+\]:-\S+ \d+: COPY (\S+.\S+) TO PROGRAM \S+ \S+ \S+_pipe_\d+_(\d+)') sizes
  FROM gpbackup_log_${date} WHERE line LIKE '%: COPY % TO PROGRAM%'
  ) s DISTRIBUTED BY (oid);
EOF


-- 20231012:17:05:40 gpbackup_helper:gpadmin:p0dtpl-ad5917xp:045632-[DEBUG]:-Segment 89: Oid 5831238: Backing up table with pipe /data2/primary/gpseg89/gpbackup_89_20231012170016_pipe_50892_5831238


-- запрос для двойного gprestore в случае восстановление на кластер с другим числом сегментов:
select * from
(select oid,content,start,ROW_NUMBER() OVER(PARTITION BY oid,content ORDER BY start) as rownum from starts_${date} where  "oid" in (69279797)
) as a
where rownum = 1 order by content;

select * from
(select oid,content,finish,size,host, ROW_NUMBER() OVER(PARTITION BY oid,content ORDER BY finish) as rownum from stops_${date} where  "oid" in (69279797)
) as a
where rownum = 1 order by content;

exit 0


минимальный старт, максимальный финиш группировать по oid.

-- вариант для gprestore:
-- вывести отчет о времени копирования таблиц:
date=20240214
ticket=INC0018856
tst_db=gpadmin
psql -d $tst_db << EOF
SET  search_path TO ${ticket};
SHOW search_path;
with
strs_cte as (select strs.oid as oid_start, min(strs.start) as bkp_start_min, max(strs.start) as bkp_start_max from starts_20240214 strs group by strs.oid),
stps_cte as (select stps.oid as oid_stop, min(stps.finish) as bkp_stop_min, max(stps.finish) as bkp_stop_max, sum(stps.size) as bkp_size from stops_20240214 stps group by stps.oid)
select
tables.table as schema_table_name, -- схема и имя таблицы
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
from strs_cte
join stps_cte on strs_cte.oid_start = stps_cte.oid_stop
join tables_20240214 tables on strs_cte.oid_start = tables.oid
--where tables.gpid = <GPID> -- при необходимости указать PID gpbackup
order by strs_cte.bkp_start_min;
EOF



-- вариант для backup:
-- вывести отчет о времени копирования таблиц:
date=20240214
ticket=INC0018856
tst_db=gpadmin
psql -d $tst_db << EOF
SET  search_path TO ${ticket};
SHOW search_path;
with
strs_cte as (select strs.oid as oid_start, min(strs.start) as bkp_start_min, max(strs.start) as bkp_start_max from starts_20240214 strs group by strs.oid),
stps_cte as (select stps.oid as oid_stop, min(stps.finish) as bkp_stop_min, max(stps.finish) as bkp_stop_max, sum(stps.size) as bkp_size from stops_20240214 stps group by stps.oid)
select
tables.table as schema_table_name, -- схема и имя таблицы
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
from strs_cte
join stps_cte on strs_cte.oid_start = stps_cte.oid_stop
join tables_20240214 tables on strs_cte.oid_start = tables.oid
--where tables.gpid = <GPID> -- при необходимости указать PID gpbackup
order by strs_cte.bkp_start_min;
EOF



