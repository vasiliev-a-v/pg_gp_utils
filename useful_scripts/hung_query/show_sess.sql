-- \set sess_id 1665

-- SQL-вариант:
-- Запрос собирает по общему sess_id:
-- данные с мастера и сегментов: pid, gpseg, hostname, port, dir

-- Задать sess_id:
\set sess_id 7

SELECT psga.gp_segment_id AS gpseg,
       psga.pid,
       psga.sess_id,
       gsc.hostname,
       gsc.port,
       gsc.datadir,
       substring(psga.query, 1, 120)
  FROM (
       SELECT -1 AS gp_segment_id,
              (pg_stat_get_activity(NULL::integer)).*
        UNION ALL
       SELECT gp_segment_id,
              (pg_stat_get_activity(NULL::integer)).*
         FROM gp_dist_random('gp_id')
       ) psga
  JOIN pg_catalog.gp_segment_configuration gsc
    ON psga.gp_segment_id = gsc.content
 WHERE psga.sess_id = :sess_id
   AND gsc.role = 'p'
;


\quit
Всё же желательно выявлять процессы на серверах через команду в gpssh, а не через SQL-запрос.
Видеть серверы, на которых сессия запущена вы можете с помощью команды ниже:
```
gpssh -f /home/gpadmin/arenadata_configs/arenadata_all_hosts.hosts "ps aux | grep con12345 | grep -v grep"
```
Где, 12345 - это ID сессии.
