-- Number Sequence: 1 to 10
;with num_seq as (
	select 1 as num
	union all
	select num+1
	from num_seq
	where num<100)
select num
from num_seq
where num <= 10

-- Date Sequence: May 2011
;with dt_seq as (
	select cast('5/1/2011' as datetime) as dt, 1 as num
	union all
	select dt+1, num+1
	from dt_seq
	where num<31)
select dt
from dt_seq

-- Factorial
;with fact as (
	select 1 as fac, 1 as num
	union all
	select fac*(num+1), num+1
	from fact
	where num<12)
select fac
from fact
where num=5

-- Fibonacci Series
;with fibo as (
	select 0 as fibA, 0 as fibB, 1 as seed, 1 as  num
	union all
	select seed+fibA, fibA+fibB, fibA, num+1
	from fibo
	where num<12)
select fibA
from fibo


