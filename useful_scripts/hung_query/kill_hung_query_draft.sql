-- SQL-скрипт, который прекращает распределённый запрос
-- в виде объединённых общим sess_id процессов на мастере и сегментах.
-- Прекращение запроса происходит через вызовы на сегментах и мастере
-- функции pg_terminate_backend(pid) с pid-ами по общему sess_id.
-- Если функция pg_terminate_backend() не поможет,
-- то SQL-скрипт предлагает список pid и примеры команд ssh
-- которые необходимо выполнить на мастере.

\prompt 'Enter process PID on master: ' pid_to_kill

-- BEGIN: ДЛЯ ТЕСТА
SELECT pid pid_to_kill
  FROM pg_stat_activity
 WHERE application_name = 'kill_hung_query_test.sql' \gset
\echo :pid_to_kill

SELECT (:'pid_to_kill' = '') AS no_pid \gset
\echo :no_pid
\if :no_pid
\q
\endif
-- END: ДЛЯ ТЕСТА


-- Получаем общий sess_id и записываем в переменную sess_to_kill:
SELECT sess_id AS sess_to_kill
  FROM pg_stat_activity
 WHERE pid = :pid_to_kill \gset


-- создаём представление, чтобы можно было её использовать повторно.
-- CTE собирает с сегментов номера pid процессов запроса
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

\echo Список сегментов, pid и номер сессии по данному запросу:
SELECT * FROM pids_tmp;

\echo отключаем бекенды на сегментах:
SELECT gdr.gp_segment_id   gdr_seg,
       pids_tmp.segment_id pons_seg,
       (pg_terminate_backend(pids_tmp.pid)),
       pids_tmp.pid pons_pid
  FROM gp_dist_random('gp_id') gdr,
       pids_tmp
 WHERE gdr.gp_segment_id = pids_tmp.segment_id
 ORDER BY gdr.gp_segment_id
;

-- это для тестирования:
\echo Пауза 5 секунд:
SELECT pg_sleep(5);
\echo Проверяем через pids_view:
SELECT * FROM pids_view;

\echo Отключаем бекенд на мастере:
SELECT pg_terminate_backend(:pid_to_kill);
\echo Проверяем через pids_view:
SELECT * FROM pids_view;


-- Эти запросы на случай, если зависшие процессы не прекратятся
\echo  hung pids:
SELECT content segment_No, address, pid
  FROM gp_segment_configuration gsc
  JOIN pids_view pv
    ON gsc.content = pv.segment_id
 WHERE role = 'p'
 ORDER BY address, content
;


-- Если дочерний процесс postgres зависнет,
-- то он может не позволить процессу postmaster
-- выполнить рестарт через pg_ctl в режиме fast
\echo Если pg_terminate_backend() (SIGTERM) не поможет,
\echo то придётся делать pg_ctl -m immediate restart.
\a
SELECT 'gpssh -h '||address||' ''$GPHOME/bin/pg_ctl -D '||datadir||' -m immediate -o "-D '||datadir||' -p '||port||'" stop'''
    AS "shell command examples:"
  FROM gp_segment_configuration gsc
  JOIN pids_view pv
    ON gsc.content = pv.segment_id
 WHERE role = 'p'
 ORDER BY address, content
;
\a
\q

-- gpssh -h avas-cdws1.ru-central1.internal '$GPHOME/bin/pg_ctl -D /data1/primary/gpseg0 -m immediate -o "-D /data1/primary/gpseg0 -p 10000" restart'


