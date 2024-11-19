-- Based on ticket: INC0020873
-- Search hung SQL-queries: 
-- Hung queries are - queries, which have no process on master.
-- Запрос на поиск зависших сессий

-- Сессии, которые есть на мастере
CREATE TEMP TABLE master_sessions AS
    SELECT sess_id
      FROM pg_stat_activity
     WHERE sess_id > 0
  DISTRIBUTED BY (sess_id);

-- Сессии, которые есть на сегментах
CREATE TEMP TABLE segment_sessions AS
    SELECT sess_id
         , query
      FROM (
             SELECT (pg_stat_get_activity(NULL::integer)).*
               FROM gp_dist_random('gp_id')
           ) psga
     WHERE sess_id > 0
       -- Здесь: учитывается запрос, запускаемый на сегментах
       -- механизмом Global Deadlock Detector
       AND query !~ 'SELECT \* FROM pg_catalog.gp_dist_wait_status()'
     GROUP BY sess_id, query
  DISTRIBUTED BY (sess_id);

-- Отобразить зависшие сессии и их query
SELECT segment_sessions.sess_id,
       segment_sessions.query
  FROM (
        -- Вычисляются сессии,
        -- которые есть на сегментах,
        -- но отсутствуют на мастере:
        SELECT sess_id FROM segment_sessions
        EXCEPT
        SELECT sess_id FROM master_sessions
     ) hung_sessions
  JOIN segment_sessions
    ON hung_sessions.sess_id = segment_sessions.sess_id
;
\quit



\quit
-- -- ОПИСАНИЕ АЛГОРИТМА -- --

-- Можно выполнить такой вариант:
-- 1. во временную таблицу master_sessions собрать список sess_id на мастер-ноде запросом к pg_stat_activity.
-- В предикате необходимо учесть, что sess_id должны быть больше 0.
-- 2. во временную таблицу segment_sessions собрать (и сгруппировать) список sess_id на сегмент-нодах.
-- Помимо списка sess_id в выборку добавить также поле query, чтобы потом наглядно видеть, какой запрос выполнял зависший процесс. Это необязательная, но полезная часть.
-- Для сбора данных на сегментах можно в выборке обратиться к функции (pg_stat_get_activity(NULL::integer)).* с использованием gp_dist_random('gp_id') в поле FROM.
-- В предикате необходимо учесть, что sess_id должны быть больше 0.
-- Также необходимо учесть, что при использовании механизма Global Deadlock Detector в конечную выборку будет попадать запрос к функции pg_catalog.gp_dist_wait_status().
-- Механизм Global Deadlock Detector выполняет запрос только на сегментах.
-- Поэтому его надо тоже добавить в предикат, например так:
-- ```
-- AND query !~ 'SELECT \* FROM pg_catalog.gp_dist_wait_status()'
-- ```
-- 3. Соединить таблицу segment_sessions с таблицей master_sessions через EXCEPT.
-- Таким образом, мы получим вывод (назовём его hung_sessions) со списком сессий, которые есть на сегментах, но отсутствуют на мастере.
-- 4. Отобразить зависшие сессии и их query:
-- Полученный вывод hung_sessions соединить с segment_sessions по общему полю sess_id.
-- В полученной выборке вывести из segment_sessions поля sess_id и query.

-- При использовании данного алгоритма, необходимо учитывать такие нюансы:
-- - После получения sess_id "зависших запросов", их необходимо проверять вручную на предмет - пользовательские ли они или служебные. Например, в текущем алгоритме приведён пример со служебным запросом от механизма Global Deadlock Detector.
-- - В список могут попадать запросы, которые на момент выполнения SQL-запросов находились в процессе закрытия.
-- В данном случае, вы можете запустить запрос дважды.
-- Если одна и та же пользовательская сессия будет присутствовать в обеих выборках, то значит её можно признать претендентом на зависшую сессию.


