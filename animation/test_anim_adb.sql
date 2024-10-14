\set i 1
\set sec .1
\set string 'Arenadata’s support team does not create SQL queries.'
SELECT char_length(:'string') AS cnt \gset

\set for_i 'SELECT substr(:''string'', :i, 1) chr \\gset \\echo -n :chr \\\\ \n'
\set incrm 'SELECT (:i + 1) i \\gset \\\\ \n'
\set pause ' \\o /dev/null \\\\ SELECT pg_sleep(:sec); \\o \\\\ \n'
\set for_body :for_i:incrm --:pause
SELECT repeat(:'for_body', :cnt) AS for_loop \gset
-- loop execution:
:for_loop
\echo


\quit
