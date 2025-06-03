Добрый день, коллеги!

Предлагаю обсудить такое решение.

- первоначально создаётся таблица arenadata_toolkit.wal_history, которая будет хранить историю о WAL.
```
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
```

- периодически по crontab запускается некий SQL-скрипт.
- скрипт собирает данные о WAL с мастера и сегментов.
Например, подобным образом:
```
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
```

- После этого, имея исторические данные о WAL, можно делать к таблице SQL-запросы для анализа:
```
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
```

- И получать подобные результаты:
```
 gpseg | start_lsn  |  stop_lsn  |  bytes  | time_difference_seconds | speed_bytes_per_second 
-------+------------+------------+---------+-------------------------+------------------------
    -1 | 8/D456A2C0 | 8/D4592CC8 |  166408 |             2099.939037 |       79.2442052211823
     0 | 8/55D609C8 | 8/55E6BC60 | 1094296 |             2099.939037 |       521.108461111959
     1 | 8/2DAB2110 | 8/2DBBD720 | 1095184 |             2099.939037 |       521.531330530716
     2 | 8/51BFA7A0 | 8/51D22408 | 1211496 |             2099.939037 |       576.919605118994
     3 | 8/3DB10F00 | 8/3DC30BF8 | 1178872 |             2099.939037 |       561.383916022701
(5 строк)

```

В том числе, заказчик сможет решать указанную выше в PFP проблему, а именно:
```
Иногда это невозможно (по причине ротации WAL-файлов), и заказчик вынужден выполнять gprecoverseg с опцией -F.
При этом у заказчика отсутствует возможность со стороны СУБД оценить размер сгенерированной журнальной информации в прошлом для сравнительного анализа и прогнозирования, возможно ли выполнить инкрементальное восстановление системы.
```

Теперь, когда у них будет фиксироваться в поле file_name имя WAL-файла, то они смогут узнать, какие у них были имена WAL-файлов (сегментов) со времени падения и выполнить подобный запрос:
```
SELECT pg_ls_dir(current_setting('data_directory') || '/pg_xlog');
```
И сравнить вывод с именем файла в file_name.
Так можно узнать, остался ли искомый WAL-файл.
Если файл остался, то заказчик может спрогнозировать, что инкрементальное восстановление системы возможно.

Каких-либо дополнительных настроек в СУБД при таком решении не потребуется.



