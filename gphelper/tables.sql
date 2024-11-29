create table tables_dr_20240325 as (
select row_number() over (partition by gpid, worker_id order by bkp_start) as worker_num, worker_id, oid, table_name, gpid, bkp_start
    from (select sizes[4] as worker_id, 
                 sizes[6]::int as oid,
                 sizes[5] as table_name,
                 sizes[3]::int as gpid,
                 (sizes[1] || ' ' || sizes[2])::timestamp as bkp_start
            from (select line, 
                         regexp_matches(line, '^(\d+):(\d{2}:\d{2}:\d{2}) \S+:(\d+)-\[\w+\]:-(\S+ \d+): COPY (\S+.\S+) TO PROGRAM \S+ \S+ \S+_pipe_\d+_(\d+)') sizes 
                    from gpbackup_log_dr_20240325
                   where line like '%Worker %: COPY % TO PROGRAM%') s
        ) t
)
DISTRIBUTED BY (oid);