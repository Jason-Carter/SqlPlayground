
declare @NewDbVersion		varchar(20) = '5.2.1.124' -- <- CHANGE THIS VERSION
declare @CurrentDbVersion	varchar(20) = (select top 1 version from <databaseversion> where IsCurrent = 1)

--
-- Split the version numbers up into seperate Major, Minor, Build, Revision variables
--
declare @Dot1		int = CHARINDEX('.', @NewDbVersion)
declare @Dot2		int = CHARINDEX('.', @NewDbVersion, @Dot1 + 1)
declare @Dot3		int = CHARINDEX('.', @NewDbVersion, @Dot2 + 1)
declare @Length		int = len(@NewDbVersion)

declare @NewMajorVersion		int = cast(substring(@NewDbVersion, 1, @Dot1 - 1) as int)
declare @NewMinorVersion		int = cast(substring(@NewDbVersion, @Dot1 + 1, @Dot2 - @Dot1 - 1) as int)
declare @NewBuildVersion		int = cast(substring(@NewDbVersion, @Dot2 + 1, @Dot3 - @Dot2 - 1) as int)
declare @NewRevisionVersion		int = cast(substring(@NewDbVersion, @Dot3 + 1, @Length - @Dot3) as int)

select @Dot1 = CHARINDEX('.', @CurrentDbVersion)
select @Dot2 = CHARINDEX('.', @CurrentDbVersion, @Dot1 + 1)
select @Dot3 = CHARINDEX('.', @CurrentDbVersion, @Dot2 + 1)
select @Length = len(@CurrentDbVersion)

declare @CurrentMajorVersion	int = cast(substring(@CurrentDbVersion, 1, @Dot1 - 1) as int)
declare @CurrentMinorVersion	int = cast(substring(@CurrentDbVersion, @Dot1 + 1, @Dot2 - @Dot1 - 1) as int)
declare @CurrentBuildVersion	int = cast(substring(@CurrentDbVersion, @Dot2 + 1, @Dot3 - @Dot2 - 1) as int)
declare @CurrentRevisionVersion	int = cast(substring(@CurrentDbVersion, @Dot3 + 1, @Length - @Dot3) as int)

-- Check version numbers to ensure the upgrade is required
declare @PerformUpgrade bit = 0 -- default false

if		(@NewMajorVersion > @CurrentMajorVersion) set @PerformUpgrade = 1
else if (@NewMajorVersion = @CurrentMajorVersion) begin
	-- check the next version level - minor
	if		(@NewMinorVersion > @CurrentMinorVersion) set @PerformUpgrade = 1
	else if (@NewMinorVersion = @CurrentMinorVersion) begin
		-- check the next version level - build
		if		(@NewBuildVersion > @CurrentBuildVersion) set @PerformUpgrade = 1
		else if (@NewBuildVersion = @CurrentBuildVersion) begin
			-- check the next version level - revision
			if (@NewRevisionVersion > @CurrentRevisionVersion) set @PerformUpgrade = 1
		end
	end
end

if (@PerformUpgrade = 1) begin

    -- Perform upgrade steps...
    print ''
    
end
