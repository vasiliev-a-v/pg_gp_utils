-- Выполняет auto_explain, а потом вылавливает данные из лога

--~ \d pg_stat_activity
--~ \q

SELECT now();
SELECT date_trunc('second', now()) AS my_time \gset
SELECT pg_backend_pid() AS my_pid \gset
\echo :my_pid
\echo :my_time

--~ SELECT * FROM gp_toolkit.__gp_log_master_ext LIMIT 1 \gx

--~ \q
--~ SELECT lme.*
  --~ FROM gp_toolkit.__gp_log_master_ext lme
  --~ JOIN pg_stat_activity sa
    --~ ON logpid = 'p'||sa.pid::text
 --~ WHERE logpid = 'p'||pg_backend_pid()::text 
   --~ AND date_trunc('second', logtime) = date_trunc('second', sa.backend_start)
   --~ AND sa.pid = pg_backend_pid()
--~ ;

\q

--~ 
--~ SELECT * FROM gp_toolkit.__gp_log_master_ext LIMIT 1 \gx

\q
LOAD 'auto_explain';
SET auto_explain.log_analyze = 'on';
SET auto_explain.log_min_duration = '10ms';
SET auto_explain.log_nested_statements = on;

SELECT now();
