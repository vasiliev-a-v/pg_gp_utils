#!/bin/bash

# EXAMPLES:

# /p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025341/ta_top_2025-07-21_14-10-58.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025341 --schema public --table t_audit_top  --template template_t_audit_top.sql

# /p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025341/ta_pg_stat_activity_2025-07-21_14-10-58.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025341 --schema public --table t_audit_pg_stat_activity --template template_t_audit_pg_stat_activity.sql

# /p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025341/pg_locks_usage2025-07-21_14-10-58.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025341 --schema public --table t_audit_locks_usage --template template_t_audit_locks_usage.sql

# /p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025341/ta_gp_resgroup_status_2025-07-21_14-10-58.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025341 --schema public --table t_audit_gp_resgroup_status --template template_t_audit_gp_resgroup_status.sql

# /p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025341/ta_gp_resgroup_status_per_seg_2025-07-21_14-10-58.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025341 --schema public --table t_audit_resgroup_status_per_seg --template template_t_audit_resgroup_status_per_seg.sql







exit 0

# /p/csv_to_adb/csv_upload.sh --path /a/INC/INC0020472/dia_res/arenadata_toolkit.db_files_current.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0020472 --schema arenadata_toolkit --table db_files_current1

# csv_upload.sh --path /a/INC/INC0024504/pg_aocsseg_436855222.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0024504 --table pg_aocsseg_436855222 --template template_pg_aocsseg.sql

# csv_upload.sh --path /a/INC/INC0019547/check_data_skew_to_csv.csv.gz --host avas-dwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket inc0019547 --table check_data_skew_to_csv --template template_check_data_skew.sql
# scp -r /p/csv_to_adb/ avas@avas-cdwm1:/tmp

#~ csv_upload.sh --path /a/INC/INC0020472/1/pg_stat_all_tables.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0020472 --table pg_stat_all_tables --template template_pg_stat_all_tables_all_cluster.sql

#~ csv_upload.sh --path /a/INC/INC0022604/tat1700-1705.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0022604 --table t_audit_top --template template_t_audit_top.sql


exit 0


