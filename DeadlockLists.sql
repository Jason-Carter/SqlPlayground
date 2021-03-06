﻿
if object_id('tempdb..#XMLDataSource') is not null  drop table #XMLDataSource
if object_id('tempdb..#ConvertedDataSource') is not null  drop table #ConvertedDataSource

DECLARE @XMLData XML 

SELECT	TOP 1 @XMLData = CAST(target_data  AS XML)
FROM	sys.dm_xe_session_targets	st
JOIN	sys.dm_xe_sessions			s ON s.address = st.event_session_address
WHERE	name = 'system_health'

SELECT	row_number() over(order by col.value('(data/value)[1]', 'VARCHAR(MAX)'))	as DeadlockRowNum,
		col.value('(./@timestamp)', 'DATETIME')										AS DeadlockTimeStamp , 
		cast(col.value('(data/value)[1]', 'VARCHAR(MAX)') as XML)					AS DeadLockXML
into	#XMLDataSource
FROM	@XMLData.nodes ('//event') AS X(Col)
WHERE	col.value('(data/value)[1]', 'VARCHAR(MAX)') LIKE '<deadlock%'

SELECT	DeadlockRowNum,
		DeadlockTimeStamp,
		DB_NAME(Currentdb) AS DatabaseName,
		hostname,
		--Victims,
		--VictimProcessId,
		spid,
		ProcessId,
		LockMode,
		Victim,
		TransactionName,
		CASE WHEN InputBuf LIKE '%Object Id%' 
			THEN SUBSTRING(InputBuf, CHARINDEX('Object Id', InputBuf) + 12, LEN(InputBuf) - CHARINDEX('Object Id', InputBuf) - 12 )
			ELSE '' 
		END			AS ObjectId,
		CASE WHEN InputBuf LIKE '%Object Id%' 
			THEN OBJECT_NAME(SUBSTRING(InputBuf, CHARINDEX('Object Id', InputBuf) + 12, LEN(InputBuf) - CHARINDEX('Object Id', InputBuf) - 12 ), currentdb)
			ELSE '' 
		END			AS ObjectName,
		ProcName,
		LineNumber,
		inputbuf,
		waitresource
into	#ConvertedDataSource
FROM	(
			SELECT	DeadlockRowNum,
					DeadlockTimeStamp,
					--Victim			= case when xmlVictims.value('/victim-list[1]/victimProcess[1]/@id', 'varchar(50)') = xmlProcesses.value('/process[1]/@id', 'varchar(50)') then 1 else 0 end,
					Victim			= case 
										when charindex(xmlProcesses.value('/process[1]/@id', 'varchar(50)'), 
														(select '##' + victimProcesses.ids.value('@id', 'varchar(max)') + '##'
														from xmlVictims.nodes('/victim-list/victimProcess') as victimProcesses (ids)
														for xml path(''))
														) > 0
										then 1 
										else 0 
									end,
					Victims			=	(
											select '##' + victimProcesses.ids.value('@id', 'varchar(max)') + '##'
											from xmlVictims.nodes('/victim-list/victimProcess') as victimProcesses (ids)
											for xml path('')
										),
					--VictimProcessId	= xmlVictims.value('/victim-list[1]/victimProcess[1]/@id', 'varchar(50)'),
					spid			= xmlProcesses.value('/process[1]/@spid', 'INT'),
					ProcessId		= xmlProcesses.value('/process[1]/@id', 'varchar(50)'),
					waitresource	= xmlProcesses.value('/process[1]/@waitresource', 'VARCHAR(100)'),
					hostname		= xmlProcesses.value('/process[1]/@hostname', 'VARCHAR(100)'),
					currentdb		= xmlProcesses.value('/process[1]/@currentdb', 'INT'),
					LockMode		= xmlProcesses.value('/process[1]/@lockMode', 'VARCHAR(10)'),
					TransactionName	= xmlProcesses.value('/process[1]/@transactionname', 'VARCHAR(100)'),
					ProcName		= xmlProcesses.value('/process[1]/executionStack[1]/frame[1]/@procname', 'VARCHAR(max)'),
					LineNumber		= xmlProcesses.value('/process[1]/executionStack[1]/frame[1]/@line', 'VARCHAR(max)'),
					inputbuf
			FROM 
					(
						SELECT	Processes.xmlProcs.query('.')	as xmlProcesses,
								Victims.xmlVics.query('.')		as xmlVictims,
								Processes.xmlProcs.value('inputbuf[1]', 'varchar(MAX)') as inputbuf, 
								d.DeadlockTimeStamp, 
								d.DeadlockRowNum
						FROM	#XMLDataSource d
						cross apply DeadLockXML.nodes ('//process-list/process')	AS Processes (xmlProcs)
						cross apply DeadLockXML.nodes ('//victim-list')				as Victims (xmlVics)
					) x
		) y
--order by DeadlockRowNum, spid, ProcessId

select * from #XMLDataSource order by 1
select * from #ConvertedDataSource order by DeadlockRowNum, spid, ProcessId

-- Deadlocks per day
;with cteUniqueDeadlocks as
(
	select DeadlockRowNum, convert(date, DeadlockTimeStamp) DeadlockDate  from #ConvertedDataSource group by DeadlockRowNum, convert(date, DeadlockTimeStamp)
)
select	DeadlockDate, count(*)
from	cteUniqueDeadlocks
group by DeadlockDate


--Analysis of X (exclusive) locks
declare @xlockTotal money = (select count(*) from #ConvertedDataSource where lockmode in ('X', 'IX'))

select	'TOTAL' as ObjectName, 
		''		as LineNumber, 
		count(*) as NumOccurrencesCausingExlusiveLocks,
		(count(*) / @xlockTotal) * 100 as PercentOfExlusiveLocks
from	#ConvertedDataSource
where	lockmode in ('X', 'IX')
	union
select	object_name(ObjectId), 
		LineNumber, 
		count(*) as NumOfExlusiveLocks,
		convert(money, (count(*) / @xlockTotal)) * 100  as PercentOfExlusiveLocks
from	#ConvertedDataSource
where	lockmode in ('X', 'IX')
group by ObjectId, LineNumber
order by 3 desc

--drop table #XMLDataSource
--drop table ##ConvertedDataSource
