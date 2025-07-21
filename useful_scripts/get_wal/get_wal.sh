#!/bin/bash

# Скрипт записывает в таблицу СУБД arenadata_toolkit.wal_history
# сведения о WAL.
# Вызывается по crontab.
# TODO: поменять поля в таблице arenadata_toolkit.wal_history на нормальные
# TODO: написать обработку, когда с get_wal.sh возникают ошибки
#       например, скрипт не может подключиться к СУБД

# TODO: предусмотреть тот факт, что допустим, в СУБД уже есть данный SQL-запрос.
# TODO: для того, чтобы не создавать очереди.

# TODO: проверить, как будет работать сбор данных, если отключить один сегмент.
# TODO: то есть, будет ли запрос отрабатывать или повиснет.

# TODO:
# настраиваемый retention - время хранения данных. Допустим - месяц.
# наверное проще всего сделать отдельным crontab заданием,
# которое будет раз в месяц чистить старые записи таблицы.


source /usr/lib/gpdb/greenplum_path.sh
export MASTER_DATA_DIRECTORY="/data1/master/gpseg-1"
sleep 5  # маленькая пауза,
         # которая даёт отработать другим скриптам из crontab.

PGOPTIONS="-c gp_resource_group_bypass=true -c application_name='get_wal' -c client_min_messages=warning" \
  psql -q -d adb 2>>/tmp/get_wal.err << EOF
\c adb
SET gp_resource_group_bypass = on;

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
EOF


exit 0
