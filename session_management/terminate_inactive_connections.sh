#!/bin/bash
LOCKFILE=$(dirname $0)/locks/$(basename $0 .sh).lock
flock -n "$LOCKFILE" /usr/lib/gpdb/bin/psql -U gpadmin -d adb  -c "select gpadmin.terminate_inactive_connections('%', 1800)" | grep Session >> "$MASTER_DATA_DIRECTORY/pg_log/terminate_backend_by_function-$(date +%Y-%m-%d).log" 2>&1
