-- SQL-скрипт, который прекращает распределённый запрос
-- в виде объединённых общим sess_id процессов на мастере и сегментах.
-- Прекращение запроса происходит через вызовы на сегментах и мастере
-- либо функции pg_cancel_backend(pid) (SIGINT, сигнал 2)
-- либо функции pg_terminate_backend(pid) (SIGTERM, сигнал 15).
-- с соответствующими pid процессов на сегментах и мастере по общему sess_id.


-- Ввести ID сессии распределённого запроса:
\prompt 'Enter your sess_id: ' sess_to_kill
\echo :sess_to_kill


-- выбрать тип используемой функции:
\prompt 'Terminate or cancel backend? Terminate sends SIGTERM signal (15) and terminate process. Cancel sends SIGINT signal (2) and interrupt process. Type "t" for SIGTERM or any_key for SIGINT: ' term_or_cancel

SELECT CASE t_var.what
         WHEN 't' THEN 'pg_terminate_backend'
         ELSE 'pg_cancel_backend'
       END AS kill_function 
  FROM (SELECT :'term_or_cancel' what) t_var
\gset
\echo :kill_function


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

\echo  Список сегментов, pid и номер сессии по данному запросу:
SELECT * FROM pids_tmp;


\echo  отключаем бекенды на сегментах:
SELECT gdr.gp_segment_id   gdr_seg,
       pids_tmp.segment_id pons_seg,
       -- pg_cancel_backend(pids_tmp.pid, 
       (:kill_function(pids_tmp.pid, 
         (
          'killed pid = '     ||
           pids_tmp.pid::text ||
          ', sess_id = '      ||
           pids_tmp.sess_id   ||
          ', gpseg = '        ||
           pids_tmp.segment_id::text
         )
       )),
       pids_tmp.pid pons_pid
  FROM gp_dist_random('gp_id') gdr,
       pids_tmp
 WHERE gdr.gp_segment_id = pids_tmp.segment_id
 ORDER BY gdr.gp_segment_id
;


-- Паузу в 5 секунд я сделал потому, что
-- иногда данные для pids_view не успевали обновляться
\echo  Пауза 5 секунд:
SELECT pg_sleep(5);
\echo  Проверяем через pids_view:
SELECT * FROM pids_view;

\q
\echo  Отключаем бекенд на мастере:
SELECT :kill_function(pid)
  FROM pg_stat_activity
 WHERE sess_id = :sess_to_kill;
\echo  Проверяем через pids_view:
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

\q




\quit
-- Данные действия ниже пока не являются рекомендуемыми!

-- Если функция pg_terminate_backend() не поможет,
-- то SQL-скрипт предлагает список pid и примеры команд gpssh
-- которые необходимо выполнить на мастере.

-- Если дочерний процесс postgres зависнет,
-- то он может не позволить процессу postmaster
-- выполнить рестарт через pg_ctl в режиме fast
\echo  Если pg_terminate_backend() (SIGTERM) не поможет,
\echo  то придётся делать pg_ctl -m immediate restart.
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


