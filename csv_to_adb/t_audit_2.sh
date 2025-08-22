#!/bin/bash
# INC0025383

# ta_gp_resgroup_status_2025-07-24_13-32-22.csv.gz
# ta_gp_resgroup_status_per_seg_2025-07-24_13-32-22.csv.gz
# ta_locks_usage_2025-07-24_13-32-22.csv.gz
# ta_mem_usage_2025-07-24_13-32-22.csv.gz
# ta_pg_stat_activity_2025-07-24_13-32-22.csv.gz
# ta_top_master.csv.gz

/p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025383/ta_top_master.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025383 --schema public --table t_audit_top  --template template_t_audit_top.sql

exit 0

/p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025383/ta_pg_stat_activity_2025-07-24_13-32-22.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025383 --schema public --table t_audit_pg_stat_activity --template template_t_audit_pg_stat_activity.sql

/p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025383/ta_gp_resgroup_status_2025-07-24_13-32-22.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025383 --schema public --table t_audit_gp_resgroup_status --template template_t_audit_gp_resgroup_status.sql

/p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025383/ta_gp_resgroup_status_per_seg_2025-07-24_13-32-22.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025383 --schema public --table t_audit_resgroup_status_per_seg --template template_t_audit_resgroup_status_per_seg.sql

/p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025383/ta_locks_usage_2025-07-24_13-32-22.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025383 --schema public --table t_audit_locks_usage --template template_t_audit_locks_usage.sql

/p/pg_gp_utils/csv_to_adb/csv_upload.sh --path /a/INC/INC0025383/ta_mem_usage_2025-07-24_13-32-22.csv.gz --host avas-cdwm1 --user avas --csv_to_adb /tmp/csv_to_adb/csv_to_adb.sh --ticket INC0025383 --schema public --table t_audit_mem_usage --template template_t_audit_mem_usage.sql



exit 0
