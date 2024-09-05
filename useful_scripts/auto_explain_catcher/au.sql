-- Выполняет auto_explain, а потом вылавливает данные из лога

SELECT now();
SELECT pg_backend_pid() my_pid;
\echo my_pid
LOAD 'auto_explain';
SET auto_explain.log_analyze = 'on';
SET auto_explain.log_min_duration = '10ms';
SET auto_explain.log_nested_statements = on;

SELECT now();
