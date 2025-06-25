CREATE SCHEMA IF NOT EXISTS adm;
COMMENT ON SCHEMA adm IS 'Schema for administrative functions and utilities';
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
$$;

COMMENT ON FUNCTION adm.terminate_inactive_connections_2(varchar, int4) IS 
'Version: 1.0.3
Terminates idle database sessions based on timeout thresholds. 
Parameters: p_login (varchar) - username pattern (''%'' for all), p_timeout (int4) - timeout in seconds for ldap_users group (e.g., 1800 = 30 minutes).
Behavior: Uses p_timeout for ldap_users group, 172800 seconds (48 hours) for others. 
Excludes gpadmin, adcc, and ''gp_reserved_gpdiskquota'' sessions. 
Targets idle, idle in transaction, idle in transaction (aborted), and disabled states. 
Crontab recommendation: not more frequent than */3 * * * * (every 3 minutes) to avoid excessive load.
Example:
select adm.terminate_inactive_connections(''%'', 1800)';
