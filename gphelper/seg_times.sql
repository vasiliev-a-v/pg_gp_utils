create table seg_times_dr_20240325 as 
(select b.gpid as stream_id,
    t.worker_num,
    t.worker_id,
    t.table_name,
    b.oid, 
    b.content as segment, 
    b.start as start_time, 
    e.finish as stop_time, 
    e.size, 
    e.finish - b.start as duration, 
    extract('epoch' from e.finish-b.start) as duration_sec, 
    e.size / case extract('epoch' from e.finish-b.start)::int
                when 0 then 1 
                else extract('epoch' from e.finish-b.start)::int
                end as speed_B_s, 
    round(cast(e.size / case extract('epoch' from e.finish-b.start)
                            when 0 then 1 
                            else extract('epoch' from e.finish-b.start)
                            end /1024/1024 as numeric), 2) as speed_MB_s 
    from starts_dr_20240325 b, 
         stops_dr_20240325  e,
         tables_dr_20240325 t
    where b.oid = e.oid 
      and b.content = e.content
      and b.oid = t.oid)
DISTRIBUTED BY (oid);
