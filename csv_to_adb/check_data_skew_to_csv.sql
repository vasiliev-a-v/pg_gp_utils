-- перекосы таблиц
COPY (
select
    t.table_database,
    t.table_schema,
    t.table_name,
    t.total_size_mb,
    t.seg_max_size_mb * seg_cnt - total_size_mb blocked_space_mb, -- заблокированно места из-за перекосов в МБ. Основной показатель, у маленьких таблиц-справочников может быть большой перекос в %, но малое влияние на кластер из-за небольшого размера самих таблиц
    (t.seg_max_size_mb - t.seg_avg_size_mb)/t.seg_max_size_mb skew, -- перекос, 0 - хорошо, нет перекоса, чем ближе к 1 тем хуже
    round(t.seg_min_size_mb) seg_min_size_mb,
    round(t.seg_max_size_mb) seg_max_size_mb,
    round(t.seg_avg_size_mb) seg_avg_size_mb,
    t.empty_seg_cnt -- количество сегментов, на которых вообще нет данных таблицы. Для средних и больших таблиц должен быть = 0, иначе проблема и большой перекос
from 
    (select 
        oid,
        table_database,
        table_schema,
        table_name,
        table_parent_table,
        table_tablespace,
        file_type,
        storage,
        max(seg_cnt) seg_cnt,
        (sum(seg_size)/(1024^2))::numeric(15,2) AS total_size_MB,
        (min(seg_size)/(1024^2))::numeric(15,2) as seg_min_size_MB,
        (max(seg_size)/(1024^2))::numeric(15,2) as seg_max_size_MB,
        (avg(seg_size)/(1024^2))::numeric(15,2) as seg_avg_size_MB,
        count(seg_size) filter (where seg_size = 0) as empty_seg_cnt,
        max(last_dtm)    as last_dtm,
        sum(file_cnt)     as file_cnt
    from 
        (select
            oid,
            table_database,
            table_schema,
            table_name,
            table_parent_table,
            table_tablespace,
            type file_type,
            storage,
            content,
            sum(file_size) AS seg_size,
            max(modifiedtime) last_dtm,
            count(distinct file) file_cnt,
            count(distinct content) over () seg_cnt
        from
            arenadata_toolkit.db_files_current 
        where 
            table_name is not null
        group by
            oid,
            table_database,
            table_schema,
            table_name,
            table_parent_table,
            table_tablespace,
            file_type,
            storage,
            content
        ) t
    group by
        oid,
        table_database,
        table_schema,
        table_name,
        table_parent_table,
        table_tablespace,
        file_type,
        storage
    ) t
where
    t.seg_max_size_mb > 0
order by 
    blocked_space_mb desc
) TO '/tmp/check_data_skew.csv' (FORMAT CSV)
;
