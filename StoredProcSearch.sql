declare @Search varchar (255)
set @Search = '<stored proc name>'

--select distinct	o.name,
--				o.type_desc
--from		sys.sql_modules	m
--inner join	sys.objects		o	on o.object_id = m.object_id
--where		m.definition like '%' + @Search + '%'
--order by	2,1


select distinct object_name(id) from syscomments where [text] like '%' + @Search + '%'