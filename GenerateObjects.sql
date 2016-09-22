declare @id int

select @id=id from sysobjects where xtype='U' and name = '<tablename>'

--Used as a list of parameters for update queries
select '@'+name+',' from syscolumns where id=@id

--List of column names for queries
select name +','
from syscolumns where id=@id

--List of assignments for update set queries
select name +'= @' + name +','
from syscolumns where id=@id

--List of parameters with type for stored proc params
select '@'+name  + ' ' +
	CASE xtype
			 WHEN 56 THEN 'int'
			 WHEN 167 THEN 'varchar(' + cast([length] as varchar(5)) + ')'
			 WHEN 231 THEN 'nvarchar(' + cast([length] as varchar(5)) + ')'
			 WHEN 61 THEN 'datetime'
			 WHEN 52 THEN 'smallint'
			 WHEN 104 THEN 'bit'
			 ELSE 'Other'
		  END +','
from syscolumns where id=@id

--List of parameters with type for c# method params
select 
	CASE xtype
			 WHEN 56 THEN 'int'
			 WHEN 167 THEN 'string'
			 WHEN 231 THEN 'string'
			 WHEN 61 THEN 'DateTime'
			 WHEN 52 THEN 'Int16'
			 WHEN 104 THEN 'bool'
			 ELSE 'Other'
		  END +' ' + lower(SUBSTRING(name,1,1)) + SUBSTRING(name,2, len(name)-1)  + ', '
from syscolumns where id=@id

--List of properties for c# class
select 'public ' +
	CASE xtype
			 WHEN 56 THEN 'int'
			 WHEN 167 THEN 'string'
			 WHEN 231 THEN 'string'
			 WHEN 61 THEN 'DateTime'
			 WHEN 52 THEN 'int16'
			 WHEN 104 THEN 'bool'
			 ELSE 'Other'
		  END +' ' + name  + ' {get; set;}'
from syscolumns where id=@id

--MapData function contents for c# class
select 'item.' + name + ' = Sql_Utils.Get' + 
	CASE xtype
			 WHEN 56 THEN 'Int'
			 WHEN 167 THEN 'String'
			 WHEN 231 THEN 'String'
			 WHEN 61 THEN 'DateTime'
			 WHEN 52 THEN 'Int16'
			 WHEN 104 THEN 'Bool'
			 ELSE 'Other'
		  END + '(dr, "' + name  + '");'
from syscolumns where id=@id


-- Update / Create function contents for c# class
select 'cmd.Parameters.Add(CreateParam' + 
	CASE xtype
			 WHEN 56 THEN 'Int'
			 WHEN 167 THEN 'String'
			 WHEN 231 THEN 'String'
			 WHEN 61 THEN 'DateTime'
			 WHEN 52 THEN 'Int16'
			 WHEN 104 THEN 'Bool'
			 ELSE 'Other'
		  END + '("' + '@' + name  + '"' + ', item.' + name + '));'
from syscolumns where id=@id


