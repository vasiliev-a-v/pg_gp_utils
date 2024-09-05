#!/bin/bash
# check_by_auto_explain.sh
# Скрипт получает план запроса SQL-скрипта.
# Для этого данный скрипт:
# - устанавливает в сессии расширение auto_explain
# - запускает SQL-скрипт
# - отфильтровывает журнал сообщений СУБД за этот период


# sudo -iu gpadmin

date_start=$(date '+%Y-%m-%dT%H:%M:00')
date_for_pid=$(date '+%Y-%m-%dT%H-%M-00')
this_day=$(date '+%Y-%m-%d')
echo $date_start
echo $this_day
dbname="knd_sdw_prod_adb_dwh_hist_data"  # БД заказчика

psql -d $dbname << EOF
  SELECT pg_backend_pid() explain_pid \gset
  SET application_name=auto_explain:explain_pid;
  SELECT pid, application_name FROM pg_stat_activity WHERE pid = pg_backend_pid();

  LOAD 'auto_explain';
  SET auto_explain.log_analyze = on;
  SET auto_explain.log_buffers = on;
  SET auto_explain.log_timing = on;
  SET auto_explain.log_verbose = on;
  SET auto_explain.log_min_duration = 0;
  SET auto_explain.log_nested_statements = on;

  -- BEGIN: ТЕКСТ ЗАПРОСА.
  -- \i /home/gpadmin/arenadata_configs/collect_table_stats.sql
  -- \i /home/gpadmin/arenadata_configs/collect_table_stats_nl_on.sql
  -- \i /home/gpadmin/arenadata_configs/collect_table_stats_nl_off.sql
  -- \i /home/gpadmin/arenadata_configs/collect_table_stats_mj_on.sql
  -- ROLLBACK: ТЕКСТ ЗАПРОСА.

  \pset format unaligned
  \pset tuples_only on
  SELECT pg_backend_pid() \o /tmp/auto_explain_${date_for_pid}.pid
  ;
  \pset format aligned
  \pset tuples_only off
  \quit
EOF

sleep 2

explain_pid=$(cat /tmp/auto_explain_${date_for_pid}.pid)
date_end=$(date '+%Y-%m-%dT%H:%M:%S')

gplogfilter -b "$date_start" -e "$date_end" -f $explain_pid -o /tmp/auto_explain_gplogfilter_${date_for_pid}.log $MASTER_DATA_DIRECTORY/pg_log/gpdb-${this_day}*.csv

chmod 0666 /tmp/auto_explain*

exit 0
exit 0

