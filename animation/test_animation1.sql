\set i 1
\set cnt 9
\set pause .2
\set for_i '\\echo -n :i''... ''\b\b\b\b\b \\\\ SELECT (:i + 1) i \\gset \n'
\set sleep ' \\o /dev/null \\\\ SELECT pg_sleep(:pause); \\o \\\\ \n'
\set for_body :for_i:sleep
SELECT repeat(:'for_body', :cnt) AS for_loop \gset

\echo [
-- Выполнение цикла
:for_loop
\echo
-- SELECT * FROM gp_segment_configuration;


\quit
