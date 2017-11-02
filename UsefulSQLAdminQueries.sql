-- Very Quick Count (doesn't use table scan like select count(*) does)
select	object_name(spart.object_id)	as TableName,
		sum (spart.rows)				as TableRowCount
from	sys.partitions spart
--where	spart.object_id = object_id('ScenarioSetScenario')
--and		spart.index_id < 2
where	spart.index_id < 2
group by spart.object_id
order by 2 desc

--Queries with most impact

SELECT	SUM(highest_cpu_queries.total_worker_time) [Total CPU Time], 
		SUM(highest_cpu_queries.execution_count) [No of Executions],
		SUM(highest_cpu_queries.last_worker_time) [Run Once Time],
		MIN(creation_time) [Since],
		q.[text] [SQL]
FROM	(SELECT TOP 50  
				qs.plan_handle,  
				qs.total_worker_time,
				qs.execution_count,
				qs.last_worker_time,
				creation_time
		FROM	sys.dm_exec_query_stats qs 
		ORDER BY qs.total_worker_time DESC) AS highest_cpu_queries 
    CROSS APPLY sys.dm_exec_sql_text(plan_handle) AS q 

GROUP BY q.text
ORDER BY sum(highest_cpu_queries.total_worker_time) DESC


--Largest IO Queries

SELECT TOP 50
        (qs.total_logical_reads + qs.total_logical_writes) /qs.execution_count as [Avg IO],
        substring (qt.text,qs.statement_start_offset/2, 
         (case when qs.statement_end_offset = -1 
        then len(convert(nvarchar(max), qt.text)) * 2 
        else qs.statement_end_offset end -    qs.statement_start_offset)/2) 
        as query_text,
    qt.dbid,
    qt.objectid 
FROM sys.dm_exec_query_stats qs
cross apply sys.dm_exec_sql_text (qs.sql_handle) as qt
ORDER BY [Avg IO] DESC


--Unused Indexes
SELECT  OBJECT_SCHEMA_NAME(I.OBJECT_ID) AS SchemaName,
        OBJECT_NAME(I.OBJECT_ID) AS ObjectName,
        I.NAME AS IndexName        
FROM    sys.indexes I   
WHERE   -- only get indexes for user created tables
        OBJECTPROPERTY(I.OBJECT_ID, 'IsUserTable') = 1 
        -- find all indexes that exists but are NOT used
        AND NOT EXISTS ( 
                    SELECT  index_id 
                    FROM    sys.dm_db_index_usage_stats
                    WHERE   OBJECT_ID = I.OBJECT_ID 
                            AND I.index_id = index_id 
                            -- limit our query only for the current db
                            AND database_id = DB_ID()) 
ORDER BY SchemaName, ObjectName, IndexName 




--Index Usage Stats

SELECT   OBJECT_NAME(S.[OBJECT_ID]) AS [OBJECT NAME], 
         I.[NAME] AS [INDEX NAME], 
         USER_SEEKS, 
         USER_SCANS, 
         USER_LOOKUPS, 
         USER_UPDATES 
FROM     SYS.DM_DB_INDEX_USAGE_STATS AS S 
         INNER JOIN SYS.INDEXES AS I 
           ON I.[OBJECT_ID] = S.[OBJECT_ID] 
              AND I.INDEX_ID = S.INDEX_ID 
WHERE    OBJECTPROPERTY(S.[OBJECT_ID],'IsUserTable') = 1
order by 1,2


--Suggested Missing Indexes 

SELECT     'CREATE NONCLUSTERED INDEX <NewNameHere> ON ' + sys.objects.name + ' ( ' + mid.equality_columns + CASE WHEN mid.inequality_columns IS NULL
                       THEN '' ELSE CASE WHEN mid.equality_columns IS NULL 
                      THEN '' ELSE ',' END + mid.inequality_columns END + ' ) ' + CASE WHEN mid.included_columns IS NULL 
                      THEN '' ELSE 'INCLUDE (' + mid.included_columns + ')' END + ';' AS CreateIndexStatement, mid.equality_columns, mid.inequality_columns, 
                      mid.included_columns
FROM         sys.dm_db_missing_index_group_stats AS migs INNER JOIN
                      sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle INNER JOIN
                      sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle INNER JOIN
                      sys.objects WITH (nolock) ON mid.object_id = sys.objects.object_id
WHERE     (migs.group_handle IN
                          (SELECT     TOP (10) group_handle
                            FROM          sys.dm_db_missing_index_group_stats WITH (nolock)
                            ORDER BY (avg_total_user_cost * avg_user_impact) * (user_seeks + user_scans) DESC))



-- Index Fragmentation
							
SELECT 
                OBJECT_NAME(ind.OBJECT_ID) AS TableName, 
                ind.name AS IndexName, 
                indexstats.index_type_desc AS IndexType, 
                indexstats.avg_fragmentation_in_percent 
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats 
        INNER JOIN sys.indexes ind  
                ON ind.object_id = indexstats.object_id 
                AND ind.index_id = indexstats.index_id 
WHERE indexstats.avg_fragmentation_in_percent > 30 
                AND ind.Name IS NOT NULL 
ORDER BY indexstats.avg_fragmentation_in_percent DESC



-- Table Sizes in Rows and MB
-- uses sp_spaceused, a very useful stored proc!

DECLARE @spaceused TABLE ( 
                tablename NVARCHAR(128), 
                table_rows VARCHAR(100), 
                spacereserved VARCHAR(100), 
                data_size VARCHAR(100), 
                index_size VARCHAR(100), 
                unused VARCHAR(100) 
                ) 
                
                
INSERT @spaceused(tablename,table_rows,spacereserved,data_size, index_size, unused) 
EXEC sp_msforeachtable "sp_SpaceuSED '?' "   

SELECT tablename, 
                CAST(LEFT(spacereserved, LEN(spacereserved)-3) AS int)/1000 AS 'spacereserved (mb)', 
                CAST(LEFT(data_size, LEN(data_size)-3) AS int)/1000 AS 'data_size (mb)', 
                CAST(LEFT(index_size, LEN(index_size)-3) AS int)/1000 AS 'index_size (mb)', 
                CAST(LEFT(unused, LEN(unused)-3) AS int)/1000 AS 'unused (mb)', 
                (CAST(LEFT(data_size, LEN(data_size)-3) AS int)/1000) + (CAST(LEFT(index_size, LEN(index_size)-3) AS int)/1000) AS 'used (mb)',

                table_rows 
                FROM @spaceused 
ORDER BY 2 DESC



-- Check the last value of self incrementing columns
-- Need to ensure it isn't approaching the max value
-- TODO: Add max value to the query, and show percentage used
SELECT		s.name		as SchemaName,
		o.name		as TableName,
		ic.name		as ColumnName,
		ic.seed_value,
		ic.increment_value,
		ic.last_value
		--ic.system_type_id,
		--ic.user_type_id
FROM		sys.identity_columns	ic
inner join	sys.objects		o	on o.object_id = ic.object_id and o.type = 'U'
inner join	sys.schemas		s	on s.schema_id = o.schema_id
order by	ic.last_value desc

