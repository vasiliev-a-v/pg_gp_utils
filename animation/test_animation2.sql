\set i 1
\set cnt 9
\set pause .1
\set for_i '\\echo -n :i\b \\\\ SELECT (:i + 1) i \\gset \n'
\set sleep ' \\o /dev/null \\\\ SELECT pg_sleep(:pause); \\o \\\\ \n'
\set for_body :for_i:sleep
SELECT repeat(:'for_body', :cnt) AS for_loop \gset

\echo -n [0]'\b\b'

-- Выполнение цикла
:for_loop
\echo

\quit
