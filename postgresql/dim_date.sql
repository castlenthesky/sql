-- ################### Base List of Dates ###################
create table if not exists bi.dim_date as
with recursive base_set AS (
    select date '2016-01-01' AS date_value
    union all
    select (date_value + interval '1 day')::date
    from base_set
    where (date_value + interval '1 day')::date <= date '2035-12-31'
),
-- #################### Base Calculations ####################
base_calendar as (
	select
		 date_value
		,date_trunc('month', date_value)::date as start_of_month
		,(date_trunc('month', date_value) + interval '1 month' - interval '1 day')::date as end_of_month
		,date_part('year', date_value)::int as year_number
		,date_part('quarter', date_value)::int as quarter_of_year
		,date_part('month', date_value)::int as month_of_year
		,floor((date_part('doy', date_value) - 1) / 7 + 1)::int as week_of_year
		,floor((extract(day from (date_value - date_trunc('quarter', date_value))) / 7) + 1)::int as week_of_quarter
		,floor((date_part('day', date_value) - 1) / 7 + 1)::int as week_of_month
		,date_part('day', date_value)::int as day_of_month
		,date_part('doy', date_value)::int as day_of_year
		,(date_value - date_trunc('quarter', date_value)::date + 1)::int as day_of_quarter
		,date_part('dow', date_value)::int as day_of_week
		,(date_part('month', date_value)::int - 1) % 3 + 1 as month_of_quarter
		,case
			when date_part('dow', date_value)::int between 1 and 5 then 1 else 0
			end as is_weekday
		,(date_trunc('quarter', date_value))::date as start_of_quarter
		,(date_trunc('quarter', date_value) + interval '3 months' - interval '1 day')::date as end_of_quarter
		,date_trunc('year', date_value)::date as start_of_year
		,(date_trunc('year', date_value) + interval '1 year' - interval '1 day')::date as end_of_year
		,date_part('days', date_trunc('month',   date_value + interval '1 month' ) - interval '1 day')::int as days_in_month
		,extract(day from (date_trunc('quarter', date_value + interval '3 months') - date_trunc('quarter', date_value)))::int as days_in_quarter
		,extract(day from (date_trunc('year',    date_value + interval '1 year'  ) - date_trunc('year', date_value)))::int as days_in_year
	from base_set
)
-- ###################### Add Holidays ######################
, holiday_table as (
	select
		*
		,case
			-- New Year's Eve - December 31st
			when month_of_year = 12 and day_of_month = 31 then 'New Year''s Eve'
			when month_of_year = 12 and day_of_month + 1 = 31 and day_of_week = 5 then 'New Year''s Eve Observed'
			when month_of_year = 12 and day_of_month + 2 = 31 and day_of_week = 5 then 'New Year''s Eve Observed'
			-- New Year's Day - January 1st
			when day_of_year = 1 then 'New Year''s Day'
			when day_of_year = 2 and day_of_week = 1 then 'New Year''s Day Observed'
			when day_of_year = 3 and day_of_week = 1 then 'New Year''s Day Observed'
			-- Martin Luther King Day - 3rd Monday in January
			when month_of_year = 1 and week_of_month = 3 and day_of_week = 1 then 'Martin Luther King Day'
			-- Presidents' Day - 3rd Monday in February
			when month_of_year = 2
				and day_of_week = 1
				and count(*) filter (
					where day_of_week = 1
					and date_value <= date_value
					) over (
					partition by year_number, month_of_year
					order by date_value
					rows between unbounded preceding and current row
					) = 3
				then 'Presidents'' Day'
			-- Memorial Day - Last Monday in May
			when month_of_year = 5 and day_of_week = 1 and days_in_month - day_of_month <= 6 then 'Memorial Day'
			-- Juneteenth - June 19th
			when year_number >= 2021 and month_of_year = 6 and day_of_month = 19 then 'Juneteenth'
			when year_number >= 2021 and month_of_year = 6 and day_of_month = 18 and day_of_week = 5 then 'Juneteenth Observed'
			when year_number >= 2021 and month_of_year = 6 and day_of_month = 20 and day_of_week = 1 then 'Juneteenth Observed'
			-- Independence Day - July 4th
			when month_of_year = 7 and day_of_month = 4 then 'Independence Day'
			when month_of_year = 7 and day_of_month = 3 and day_of_week = 5 then 'Independence Day Observed'
			when month_of_year = 7 and day_of_month = 5 and day_of_week = 1 then 'Independence Day Observed'
			-- Pioneer Day - July 24th
			when month_of_year = 7 and day_of_month = 24 then 'Pioneer Day'
			-- Labour Day - First Monday in September
			when month_of_year = 9 and week_of_month = 1 and day_of_week = 1 then 'Labour Day'
			-- Columbus Day - 2nd Monday of October
			when month_of_year = 10
				and day_of_week = 1
				and count(*) filter (
					where day_of_week = 1
					and date_value <= date_value
					) over (
					partition by year_number, month_of_year
					order by date_value
					rows between unbounded preceding and current row
					) = 2
				then 'Columbus Day'
			-- Halloween - October 31st
			when month_of_year = 10 and day_of_month = 31 then 'Halloween'
			-- Veterans Day - November 11th
			when month_of_year = 11 and day_of_month = 11 then 'Veterans Day'
			when month_of_year = 11 and day_of_month = 10 and day_of_week = 5 then 'Veterans Day Observed'
			when month_of_year = 11 and day_of_month = 12 and day_of_week = 1 then 'Veterans Day Observed'
			-- Thanksgiving Day - 4th Thursday in November
			when month_of_year = 11
				and day_of_week = 4
				and count(*) filter (
					where day_of_week = 4
					and date_value <= date_value
					) over (
					partition by year_number, month_of_year
					order by date_value
					rows between unbounded preceding and current row
					) = 4
				then 'Thanksgiving Day'
			-- Christmas Eve - December 24th
			when month_of_year = 12 and day_of_month = 24 then 'Christmas Eve'
			when month_of_year = 12 and day_of_month = 23 and day_of_week = 5 then 'Christmas Eve Observed'
			when month_of_year = 12 and day_of_month = 25 and day_of_week = 1 then 'Christmas Eve Observed'
			-- Christmas Day - December 25th
			when month_of_year = 12 and day_of_month = 25 then 'Christmas Day'
			when month_of_year = 12 and day_of_month = 24 and day_of_week = 5 then 'Christmas Day Observed'
			when month_of_year = 12 and day_of_month = 26 and day_of_week = 1 then 'Christmas Day Observed'
			end as holiday_name
	from base_calendar
)
-- ################# Final Table Definition #################
, final as (
	select
		 date_value
		,year_number as year
		,quarter_of_year as quarter
		,'Q' || quarter_of_year::text as quarter_name
		,month_of_year as month
	    ,to_char(date_value, 'Month') AS month_name
	    ,to_char(date_value, 'Mon') AS month_abbrev
		,week_of_year as week
		,day_of_month as day
		,day_of_week
	    ,to_char(date_value, 'Day') AS day_of_week_name
	    ,to_char(date_value, 'Dy') AS day_of_week_abbrev
		,is_weekday
		,case when holiday_name is not null then 1 else 0 end as is_holiday
		,case when is_weekday = 1 and holiday_name is null then 1 else 0 end as is_workday
		,holiday_name
		,start_of_month
		,end_of_month
		,day_of_month
		,days_in_month
		,week_of_month
		,greatest(1, count(*) filter (
				where is_weekday = 1
				and holiday_name is null
				and date_value <= date_value
				) over (
				partition by year_number, month_of_year
				order by date_value
				rows between unbounded preceding and current row
				)
			) as workday_of_month
		,count(*) filter (
			where is_weekday = 1
			and holiday_name is null
			) over (
			partition by year_number, month_of_year
			) as workdays_in_month
		,start_of_quarter
		,end_of_quarter
		,day_of_quarter
		,days_in_quarter
		,week_of_quarter
		,month_of_quarter
		,greatest(1, count(*) filter (
				where is_weekday = 1
				and holiday_name is null
				and date_value <= date_value
				) over (
				partition by year_number, quarter_of_year
				order by date_value
				rows between unbounded preceding and current row
				)
			) as workday_of_quarter
		,count(*) filter (
			where is_weekday = 1
			and holiday_name is null
			) over (
			partition by year_number, quarter_of_year
			) as workdays_in_quarter
		,start_of_year
		,end_of_year
		,day_of_year
		,days_in_year
		,greatest(1, count(*) filter (
				where is_weekday = 1
				and holiday_name is null
				and date_value <= date_value
				) over (
				partition by year_number
				order by date_value
				rows between unbounded preceding and current row
						)
			) as workday_of_year
		,count(*) filter (
			where is_weekday = 1
			and holiday_name is null
			) over (
			partition by year_number
			) as workdays_in_year
		,week_of_year
	    ,- extract(hour from (date_value at time zone 'UTC' at time zone 'America/Denver')) as utc_diff
	    ,case
	    	when extract(hour from (date_value at time zone 'UTC' at time zone 'America/Denver')) = 6
	    	then 0
	    	else 1
	    	end as is_dst
	from holiday_table
)
-- Final SELECT
select * from final
;
