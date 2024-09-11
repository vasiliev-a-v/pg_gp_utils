-- kill_hung_query.sql


-- psql-скрипт, который прекращает распределённый SQL-запрос
-- в виде объединённых общим sess_id процессов на мастере и сегментах.
-- Отправка сигналов на сегментах и мастере происходит через функции:
-- 1. pg_terminate_backend(pid) (SIGTERM, сигнал 15) - завершает процесс
-- 2. pg_cancel_backend(pid) (SIGINT, сигнал 2) - отменяет запрос
-- Сигналы передаются на соответствующие pid процессов на сегментах
-- и на мастере по общему sess_id.


\setenv PGAPPNAME 'kill_hung_query'
\setenv QUIET on
-- переподключаемся к template1, чтобы активировать переменные setenv:
\c template1
-- меняет формат вывода утилитой psql:
\pset tuples_only on
\pset format unaligned


-- записываем строку команды psql с запущенным скриптом:
\! echo "SELECT '$(ps -eo pid,command | grep psql | grep kill_hung_query.sql | grep -v grep | cut -d ' ' -f1)' AS psql_pid, '$(ps -eo command | grep psql | grep kill_hung_query.sql | grep -v grep)' AS psql_command \gset" > /tmp/kill_hung_query.tmp
\i /tmp/kill_hung_query.tmp


-- ПРОВЕРКА sses_id
-- проверка на то, что задана переменная sess_id.
-- Если sess_id не задана, то скрипт выводит USAGE (help) и выходит
\set sess_to_kill :sess_id
\set sess_id NULL:sess_id

SELECT CASE
         WHEN what.sess_id = 'NULL'
           OR what.sess_id = 'NULL:sess_id' THEN '
SELECT ''
      Инструкция по использованию скрипта (USAGE).
  Необходимо выполнить команду вида:
  psql template1 -U gpadmin --set=sess_id=1234 --set=signal=SIGTERM \
    -f /home/gpadmin/arenadata_configs/kill_hung_query.sql

  Где опции в строке означают:
  -f - путь к текущему файлу-скрипту.

  --set=sess_id - ID сессии распределённого SQL-запроса.
  Если --set=sess_id не указана, то скрипт выведет данную инструкцию
  по использованию скрипта (USAGE) и завершит работу.

  --set=signal  - необходимо ввести тип посылаемого сигнала:
      - SIGTERM - завершает процессы (signal 15).
      - SIGINT  - прерывает запрос, не прерывая процессы (signal 2).
  Опцию --set=signal можно не указывать.
  В этом случае будет использоваться сигнал SIGTERM.

    Дополнительные параметры:
  По умолчанию скрипт сохраняет вывод в лог-файл:
  /home/gpadmin/gpAdminLogs/kill_hung_query_YYYYMMDD.log
  Перенаправить лог в другой файл можно с помощью опции:
  --set=log=/path_to/file.log - сохранить в лог-файл /path_to/file.log.
'';
\quit
'
         ELSE 'SELECT ''Looking for sess_id='||trim('NULL' from what.sess_id)||''';'
       END AS show_help_or_sess_id
  FROM (SELECT :'sess_id' sess_id) what
\gset

-- Выводит либо HELP либо sess_id:
:show_help_or_sess_id
-- возвращаем значение для переменной sess_id:
\set sess_id :sess_to_kill


-- Запишет в переменную app_name значение:
SELECT application_name AS app_name
  FROM pg_stat_activity
 WHERE pid = pg_backend_pid() \gset


-- ОПРЕДЕЛЯЕМСЯ С ЛОГ-ФАЙЛОМ
-- Если (по умолчанию) лог-файл не задан:
SELECT to_char(now(), 'YYYYMMDD') today \gset
\set log_file '/home/gpadmin/gpAdminLogs/kill_hung_query_':today'.log'

-- Если пользователем задан лог-файл (переменная log),
-- то присвоим переменной log_file значение переменной log:
\set orig_log :log
\set log  NULL:log
SELECT CASE
         WHEN what.log = 'NULL'
           OR what.log = 'NULL:log'
              THEN :'log_file'
         ELSE      :'orig_log'
       END AS log_file
  FROM (SELECT :'log' log) what
\gset

-- сформировать строку с командой записи в лог-файл:
\set save_to_log_file '\\out | tee -a ':log_file
-- включает запись в лог-файл:
:save_to_log_file

\qecho --- Начало работы :app_name ---
SELECT clock_timestamp();
\qecho PID psql-процесса:
\qecho :psql_pid
\qecho Строка команды psql:
\qecho :psql_command
\qecho Информация о соединении:
\conninfo
\pset tuples_only off
\pset format aligned
\x \\
SELECT * FROM pg_stat_activity WHERE pid = pg_backend_pid();
\x
\qecho Работа скрипта записывается в лог-файл:
\qecho :log_file


-- ПРОВЕРКА signal, выбор функции
-- проверка на то, что задана переменная signal:
-- если ничего не задано, то сигнал будет SIGTERM
\set signal SIGTERM:signal

SELECT CASE what.signal
         WHEN 'SIGTERMSIGINT' THEN 'pg_cancel_backend'
         ELSE 'pg_terminate_backend'
       END AS kill_function 
  FROM (SELECT :'signal' signal) what
\gset

\qecho Вызываем для sess_id = :sess_id функцию: :kill_function()




-- ОСНОВНАЯ РАБОТА СКРИПТА
-- создаём представление, чтобы можно было её использовать повторно.
-- Запрос собирает с сегментов номера pid процессов запроса
-- по общему sess_id с мастера.
-- собираем "pons" - pids on segments
CREATE OR REPLACE TEMP VIEW pids_view AS 
SELECT psga.gp_segment_id AS segment_id,
       psga.pid,
       psga.sess_id,
       substring(psga.query, 1, 20)
  FROM (
       SELECT -1 AS gp_segment_id,
              (pg_stat_get_activity(NULL::integer)).*
        UNION ALL
       SELECT gp_segment_id,
              (pg_stat_get_activity(NULL::integer)).*
         FROM gp_dist_random('gp_id')
       ) psga
 WHERE psga.sess_id = :sess_to_kill
;


-- Создаём временную таблицу.
-- Таблицу необходимо распределять по REPLICATED.
-- Сделано так для выполнения gp_dist_random() на сегментах.
-- Для этого нужно, чтобы полная копия всех данных таблицы
-- была на каждом сегменте.
CREATE TEMP TABLE pids_tmp AS SELECT * FROM pids_view
  DISTRIBUTED REPLICATED;


\qecho  Проверяем процессы с sess_id = :sess_id:
SELECT * FROM pids_tmp;


-- Специально разделено отключение на сегментах
-- и отключение на мастере.
-- Сперва происходит отключение на сегментах.
\qecho  Отключаем на сегментах процессы с sess_id = :sess_id:
SELECT gdr.gp_segment_id   gdr_seg,
       pids_tmp.segment_id pons_seg,
       (:kill_function (
           pids_tmp.pid, 
           (
            'sent signal '       || :'kill_function' ||
            '() from '           || :'app_name'      || ' on pid = ' ||
             pids_tmp.pid        ||
            ', sess_id = '       ||
             pids_tmp.sess_id    ||
            ', gpseg = '         ||
             pids_tmp.segment_id
           )
         )
       ),
       pids_tmp.pid pons_pid
  FROM gp_dist_random('gp_id') gdr,
       pids_tmp
 WHERE gdr.gp_segment_id = pids_tmp.segment_id
 ORDER BY gdr.gp_segment_id
;


-- Пауза необходимо, для обеспечения синхронизации статистики.
-- То есть, чтобы статистика успела дойти с сегментов до мастера.
\qecho  Пауза 3 секунды:
SELECT pg_sleep(3);

\qecho  Проверяем на сегментах процессы с sess_id = :sess_id:
SELECT * FROM pids_view;

\qecho  Отключаем на мастере процесс с sess_id = :sess_id:
SELECT (:kill_function (
           pid, 
           (
            'sent signal '       || :'kill_function' ||
            '() from '           || :'app_name'      || ' on pid = ' ||
             pid                 ||
            ', sess_id = '       ||
             sess_id             ||
            ', gpseg = -1'
           )
         )
       )
  FROM pg_stat_activity
 WHERE sess_id = :sess_to_kill;
\qecho  Проверяем через pids_view:
SELECT * FROM pids_view;


\qecho  Проверяем процессы с sess_id = :sess_id:
SELECT content segment_No, address, pid
  FROM gp_segment_configuration gsc
  JOIN pids_view pv
    ON gsc.content = pv.segment_id
 WHERE role = 'p'
 ORDER BY address, content
;


\qecho --- Завершение работы :app_name ---
\o
\q
