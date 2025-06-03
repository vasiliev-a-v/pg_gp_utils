# Скрипт для автоматического завершения неактивных соединений в Greenplum --ver 1.0.3
## Copyright 2025 Alexander Shcheglov
## 1800 секунд = 30 минут (1800 / 60) -- для пользовательских ролей ldap_users
## 172800 секунд = 48 часов (172800 / 3600) -- для технических ролей, которые не входят в ldap_users

## строка в crontab
*/3 * * * *. "$PROFILE" && "$HOME"/adm/scripts/terminate_inactive_connections.sh 
```sh
cat ~/adm/scripts/terminate_inactive_connections.sh
#!/bin/bash
LOCKFILE=$(dirname $0)/locks/$(basename $0 .sh).lock
flock -n "$LOCKFILE" /usr/lib/gpdb/bin/psql -U gpadmin -d adb  -c "select gpadmin.terminate_inactive_connections('%', 1800)" | grep Session >> "$MASTER_DATA_DIRECTORY/pg_log/terminate_backend_by_function-$(date +%Y-%m-%d).log" 2>&1
```
## для примера как можно поулучить логины которые входят в ldap_users 
```sql 
SELECT
    u.usename,
    g.groname
FROM
    pg_user u
    JOIN pg_group g ON u.usesysid = ANY (g.grolist)
WHERE
    g.groname = 'ldap_users';
```
# функция
```sql
CREATE OR REPLACE FUNCTION adm.terminate_inactive_connections (p_login varchar, p_timeout int4)
    RETURNS SETOF text
    LANGUAGE sql
    VOLATILE
    AS $$
    -- ver 1.0.3
    SELECT
        FORMAT('%s: Session with pid=%s; user=%s; database=%s; application=%s; IP=%s; state=%s; terminated: %s', 
               current_timestamp(0), pid, usename, datname, application_name, client_addr, state, 
               pg_terminate_backend(pid, 'session timeout ' || 
               CASE 
                   WHEN usename IN (SELECT u.usename 
                                  FROM pg_user u 
                                  JOIN pg_group g ON u.usesysid = ANY (g.grolist) 
                                  WHERE g.groname = 'ldap_users') 
                   THEN p_timeout::varchar 
                   ELSE '172800' 
               END || ' seconds')::varchar)
    FROM
        pg_stat_activity
    WHERE
        state IN ('idle', 'idle in transaction', 'idle in transaction (aborted)', 'disabled')
        AND usename LIKE p_login
        AND CURRENT_TIMESTAMP - state_change > INTERVAL '1 second' * 
            CASE 
                WHEN usename IN (SELECT u.usename 
                               FROM pg_user u 
                               JOIN pg_group g ON u.usesysid = ANY (g.grolist) 
                               WHERE g.groname = 'ldap_users') 
                THEN p_timeout 
                ELSE 172800 
            END
        AND application_name != 'gp_reserved_gpdiskquota'
        AND usename NOT IN ('gpadmin', 'adcc')
$$ EXECUTE ON ANY;

COMMENT ON FUNCTION adm.terminate_inactive_connections_2(varchar, int4) IS 
'Version: 1.0.3
Terminates idle database sessions based on timeout thresholds. 
Parameters: p_login (varchar) - username pattern (''%'' for all), p_timeout (int4) - timeout in seconds for ldap_users group (e.g., 1800 = 30 minutes).
Behavior: Uses p_timeout for ldap_users group, 172800 seconds (48 hours) for others. 
Excludes gpadmin, adcc, and ''gp_reserved_gpdiskquota'' sessions. 
Targets idle, idle in transaction, idle in transaction (aborted), and disabled states. 
Crontab recommendation: not more frequent than */3 * * * * (every 3 minutes) to avoid excessive load.
Example:
select adm.terminate_inactive_connections('%', 1800);
```
