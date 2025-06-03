-- Данный скрипт
-- сохраняет историческую информацию с сегментов
-- о WAL в специальную таблицу
-- arenadata_toolkit.wal_history
-- После этого можно обращаться к таблице за определённый период
-- с целью анализа.

-- TODO: написать SQL-запрос, который вычислит объём в байтах
--       с определённого времени по настоящее время.
-- TODO: поменять поля в таблице arenadata_toolkit.wal_history на нормальные
-- TODO: написать обработку, когда с get_wal.sh возникают ошибки
--       например, скрипт не может подключиться к СУБД
\c adb
SET gp_resource_group_bypass = on;

-- SELECT * FROM pg_proc WHERE proname ~ 'pg_ls';
-- \quit

CREATE TEMP TABLE IF NOT EXISTS temp_t (
    gpseg       integer,
    dtm         timestamptz, -- now() function
    wal_current pg_lsn,      -- pg_current_xlog_location
    wal_insert  pg_lsn,      -- pg_current_xlog_insert_location
    file_name   text,
    file_offset bigint
  ) WITH (appendonly    = true,
          orientation   = column,
          compresstype  = zstd,
          compresslevel = 9
       ) 
  DISTRIBUTED BY (gpseg)
;

\dn+ pg_temp_*.*


\quit

SELECT * FROM pg_stat_activity;


-- SELECT pg_ls_dir(current_setting('data_directory') || '/pg_xlog');
\quit

-- SELECT * FROM arenadata_toolkit.wal_history ORDER BY dtm DESC LIMIT 1;

WITH w_start  AS (
       SELECT *
         FROM arenadata_toolkit.wal_history
        WHERE 1 = 1
          AND dtm BETWEEN '2025-05-19 13:00:00' AND '2025-05-19 13:01:00'
     ),
     w_stop   AS (
       SELECT *
         FROM arenadata_toolkit.wal_history
        WHERE 1 = 1
          AND dtm BETWEEN '2025-05-19 13:35:00' AND '2025-05-19 13:36:00'
     )
  SELECT w_start.gpseg
       , w_start.wal_insert AS start_lsn
       , w_stop.wal_insert  AS stop_lsn
       , (w_stop.wal_insert::pg_lsn - 
          w_start.wal_insert::pg_lsn) bytes
       , EXTRACT(EPOCH FROM w_stop.dtm - w_start.dtm)
           AS time_difference_seconds
       , (w_stop.wal_insert - 
          w_start.wal_insert) / 
          EXTRACT(EPOCH FROM w_stop.dtm - w_start.dtm)
           AS speed_bytes_per_second
    FROM w_start
    JOIN w_stop
      ON w_start.gpseg = w_stop.gpseg
   ORDER BY w_start.gpseg
;
\quit


SELECT gp_segment_id, *
  FROM arenadata_toolkit.wal_history
 ORDER BY now
;
\quit


CREATE TABLE IF NOT EXISTS arenadata_toolkit.wal_history (
    gpseg       integer,
    dtm         timestamptz, -- now() function
    wal_current pg_lsn,      -- pg_current_xlog_location
    wal_insert  pg_lsn,      -- pg_current_xlog_insert_location
    file_name   text,
    file_offset bigint
  ) WITH (appendonly    = true,
          orientation   = column,
          compresstype  = zstd,
          compresslevel = 9
       ) 
  DISTRIBUTED BY (gpseg)
;


-- код в скрипте get_wal.sh, который запускается по crontab:
psql -q -d adb -c "
INSERT INTO arenadata_toolkit.wal_history
  SELECT -1 AS gpseg,
         now(),
         pg_current_xlog_location(),
         pg_current_xlog_insert_location(),
         (pg_xlogfile_name_offset(pg_current_xlog_insert_location())).* 
   UNION ALL
  SELECT gp_segment_id AS gpseg,
         now(),
         pg_current_xlog_location(),
         pg_current_xlog_insert_location(),
         (pg_xlogfile_name_offset(pg_current_xlog_insert_location())).* 
    FROM gp_dist_random('gp_id')
   ORDER BY gpseg
  ;
"



\quit

-- основной запрос на сбор wal файлов:
SELECT -1 AS gpseg,
       now(),
       pg_current_xlog_location(),
       pg_current_xlog_insert_location(),
       (pg_xlogfile_name_offset(pg_current_xlog_insert_location())).* 
 UNION ALL
SELECT gp_segment_id AS gpseg,
       now(),
       pg_current_xlog_location(),
       pg_current_xlog_insert_location(),
       (pg_xlogfile_name_offset(pg_current_xlog_insert_location())).* 
  FROM gp_dist_random('gp_id')
 ORDER BY gpseg
;
\quit









-- возможно будет полезно это расширение:
CREATE EXTENSION IF NOT EXISTS gp_pitr;
SELECT * FROM gp_stat_archiver;
\quit
gpseg |              now              | pg_current_xlog_location | pg_current_xlog_insert_location |        file_name         | file_offset



\quit

SELECT clock_timestamp(),
       pg_current_xlog_location(),
       pg_current_xlog_insert_location(),
       (pg_xlogfile_name_offset(pg_current_xlog_insert_location())).* 
  FROM gp_dist_random('gp_id')
;




-- Оценить информацию по записанным WAL-данным вы можете на примере такого кода:
-- ```
WITH lsn_data AS (
       SELECT 
         '9/37BFBE98'::pg_lsn AS lsn_start,
         '9/37DCD200'::pg_lsn AS lsn_end,
         '2024-08-23 11:08:51'::timestamp AS time_start,
         '2024-08-23 11:33:27'::timestamp AS time_end
     )
  SELECT 
         lsn_end - lsn_start
           AS lsn_difference_bytes,
         EXTRACT(EPOCH FROM time_end - time_start)
           AS time_difference_seconds,
         (lsn_end - lsn_start) / EXTRACT(EPOCH FROM time_end - time_start)
           AS speed_bytes_per_second
    FROM lsn_data
;
-- ```



\quit
-- Различные функции по работе с файлами:
pg_ls_dir(path text)
pg_stat_file(path text)
pg_read_file(path, offset, length)
pg_read_binary_file(path, offset, length)



