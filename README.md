# SQL - Tools and Templates

This repository houses a collection of SQL templates and tools useful for gathering and summarizing data. These tools are generally presented using the T-SQL or MSSQL Server syntax, Codeblocks typically have the syntax commented at the top. Modification for use in other engines is genrally straight forward.

## First Day of the Month

There are numerous ways to transform date data into the first day of the month. T-SQL offers a handy function which returns the day at the end of the month titled `EOMONTH`, but there is no such function for the first day of the month. One common solution looks like this:

```sql
DATEADD(mm, DATEDIFF(mm, 0, '2018-05-15'), 0) -- Returns '2018-05-01
```

Breaking down this function to understand how it works is somewhat cumbersom and requires a user to understand how computers calculates dates. Basicially it reads, _"Give me the number of months between the date in question and the beginning of computer time, then add that number of months to the beggining of computer time."_

A much better solution which not only runs faster, but is also more readable looks like this:

```sql
DATEADD(dd, 1, EOMONTH('2018-05-15', -1)) -- Returns '2018-05-01
```

In plain english: _"Give me the last day of the previous month, then add one day to that."_

Both codes only call two function, but one is nonsensical to read and computationally heavier than the other. Good code is not only performant, but also readable. After all, if nobody can read or understand your code, how can it be maintained?

## Bucketizing Data

I like distribution charts. A LOT. They're one of the most useful tools in data exploration and can tell you so much so quickly. Sometimes, when an analyst is dealing with non-discrete data, it can be helpful to first transform their dataset into "buckets" of data. Your wish is my command.

```sql
--T-SQL Syntax
DECLARE @bucket_size INT = 10;
FLOOR(([data_field] + (@bucket_size - 1)) / @bucket_size) * @bucket_size [Bucketized Field]
```

The above code will bucketize the given field and group results into bins of 10. Easy-peazy. Modify your `bucket_size` variable to adjust for your specific dataset.

## Sequential Numbering

Sometimes you want a list of numbers to run calculations on or to aggregate against. Here's how you do that in a blazin' fast way.

```sql
-- T-SQL Syntax
WITH
  E1(N) AS (
            SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL
            SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL
            SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
           ),                          -- 1*10^1 or 10 rows
  E2(N) AS (SELECT 1 FROM E1 a, E1 b), -- 1*10^2 or 100 rows
  E4(N) AS (SELECT 1 FROM E2 a, E2 b), -- 1*10^4 or 10,000 rows
  E8(N) AS (SELECT 1 FROM E4 a, E4 b)  -- 1*10^8 or 100,000,000 rows
SELECT
	 TOP (40)
	 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) [Row]
FROM E8
```

```sql
--MySQL Syntax
SET @initialValue = 1;
SET @increment = 1;

SET SESSION cte_max_recursion_depth = 1000000; -- permit deeper recursion vs default of 1000;

WITH RECURSIVE seq AS (
  SELECT @initialValue AS value UNION ALL SELECT value + @increment FROM seq LIMIT 1000000
)
  SELECT * FROM seq;
```

## Stored Proc for Dimension Table Generation

```sql
--MySQL Syntax
CREATE PROCEDURE `dateDimGen`(IN startDate DATE, endDate DATE)
BEGIN
	SET SESSION cte_max_recursion_depth = 1000000; -- permit deeper recursion;

	DROP TABLE IF EXISTS dateDim;
	CREATE TABLE dateDim (
	  `id` int,
	  `Date` date,
	  `Day` int,
	  `Month` int,
	  `Year` int,
	  `Quarter` int,
	  `FirstOfMonth` DATE,
	  `LastOfMonth` DATE,
	  `DayOfWeekNumber` INT,
	  `DayOfWeek` VARCHAR(12),
	  `DayOfWeekShort` VARCHAR(3),
	  `MonthName` VARCHAR(12),
	  `MonthNameShort` VARCHAR(3),
	  `WeekOfYear` INT,
	  `DayOfYear` INT,
	  `FirstOfQuarter` DATE,
	  `FirstOfYear` DATE,
	  `MMM YY` VARCHAR(6)
	);

	INSERT INTO dateDim (
	  `id`,
	  `Date`,
	  `Day`,
	  `Month`,
	  `Year`,
	  `Quarter`,
	  `FirstOfMonth`,
	  `LastOfMonth`,
	  `DayOfWeekNumber`,
	  `DayOfWeek`,
	  `DayOfWeekShort`,
	  `MonthName`,
	  `MonthNameShort`,
	  `WeekOfYear`,
	  `DayOfYear`,
	  `FirstOfQuarter`,
	  `FirstOfYear`,
	  `MMM YY`
	)

	WITH RECURSIVE seq AS (
		SELECT
	          0 AS id,
		  startDate as d
	UNION ALL SELECT
		  id + 1,
	          DATE_ADD(d, INTERVAL 1 DAY)
	FROM seq
	WHERE d < endDate)

	SELECT
	  id,
	  d AS `Date`,
	  DAY(d) AS `Day`,
	  MONTH(d) AS `Month`,
	  YEAR(d) AS `Year`,
	  QUARTER(d) AS `Quarter`,
	  DATE_ADD(LAST_DAY(DATE_ADD(d, INTERVAL -1 MONTH)), INTERVAL 1 DAY) AS `FirstOfMonth`,
		LAST_DAY(d) AS `LastOfMonth`,
	  DAYOFWEEK(d) AS DayOfWeekNumber,
	  DAYNAME(d) AS `DayOfWeek`,
	  SUBSTRING(DAYNAME(d), 1, 3) `DayOfWeekShort`,
	  MONTHNAME(d) AS `MonthName`,
	  SUBSTRING(MONTHNAME(d), 1, 3) `MonthNameShort`,
	  WEEKOFYEAR(d) AS WeekOfYear,
	  DAYOFYEAR(d) AS DayOfYear,
	  DATE_ADD(LAST_DAY(DATE_ADD(d, INTERVAL
            CASE
              WHEN MONTH(d)%3 = 0 THEN 3
              ELSE MONTH(d)%3
            END * - 1 MONTH)),
          INTERVAL 1 DAY) AS `FirstOfQuarter`,
	  MAKEDATE(YEAR(d), 1) AS `FirstOfYear`,
	  CONCAT(SUBSTRING(MONTHNAME(d), 1, 3)," ",SUBSTRING(YEAR(d),3,2)) AS `MMM YY`
	FROM seq
        ORDER BY d asc;
END
```

## Dynamic Pivot Table

Pivoting data within SQL is not easy. Pivoting dynamic data within SQL is really not easy. This script makes pivoting data as simple as counting to three. It handles the pivot by using executing a dynamic query - sometimes fowned upon for security reasons. If you're pulling data internally and not exposing the dynamic query to an external API, nothing to worry about and you can enjoy simple, next-to-effortless pivot tables in SQL.

```sql
--T-SQL Syntax
-- ############ Declare and Set Variables ############
DECLARE @startdate  AS DATE       = DATEADD(m,-7,DATEADD(d,1,EOMONTH(GETDATE())))
       ,@enddate    AS DATE       = EOMONTH(DATEADD(m,-1,GETDATE()))
       ,@market     VARCHAR(2)    = 'US'
       ,@rowLabel   VARCHAR(24)   = 'ROW_LABEL_HERE'

-- Reinitialize temp tables
IF OBJECT_ID('tempdb..#temp_data','u') IS NOT NULL DROP TABLE #temp_data

-- #################### TEMPLATE USAGE ####################
-- You MUST SELECT INTO the #temp_data table for the pivot logic to work correctly.
-- Use the [pivot_columns] name to identify the element you want as columns.
-- Use the [pivot_rows] name to identify the element you want as the row label.
-- Use the [pivot_values] name to identify the values you want inserted at the intersections of the pivot.

-- ################### BEGIN DATA QUERY ###################
-- Write you query here - ableing the appropriate columns as they relate to your desired pivot.
SELECT
   o.month [pivot_columns] -- This column will serve as the pivot cloumns.
  ,od.SKU [pivot_rows] -- This column will serve as the pivot rows.
  ,od.quantity [pivot_values] -- This column will fill the values at the intersection.
INTO #temp_data -- You must select these cloumns into this temp table.
FROM dbo.tblOrderDetails (nolock) od
JOIN dbo.tblOrders (nolock) o
  ON od.OrderID = o.OrderID
  AND o.OrderDate BETWEEN @startdate AND @enddate
WHERE 1=1
  AND o.CustomerID = 123456789
-- #################### END DATA QUERY ####################


-- #####################################################
-- ############ Pivot Logic - DO NOT CHANGE ############
-- #####################################################
-- Variables used to build pivot table logic.
DECLARE @PivotColumnNames       AS NVARCHAR(MAX)
       ,@PivotSelectColumnNames AS NVARCHAR(MAX)
       ,@DynamicPivotQuery      AS NVARCHAR(MAX)

-- Find and order distinct values found in [pivot_columns]
SELECT
  @PivotColumnNames = ISNULL(@PivotColumnNames + ',','') + QUOTENAME(column_set.pivot_columns)
FROM (
  -- Returns a distinct list of values identified as column names and sorts them.
  SELECT DISTINCT
  td.pivot_columns
    FROM #temp_data td
) AS column_set
ORDER BY column_set.pivot_columns

-- Returns a NULL for each pivot entry that has no data.
SELECT
    @PivotSelectColumnNames
  = ISNULL(@PivotSelectColumnNames + ',','')
  + 'ISNULL(' + QUOTENAME(pivotdata.pivot_columns) + ', NULL) AS '
  + QUOTENAME(pivotdata.pivot_columns)
FROM (
  SELECT DISTINCT
  td.pivot_columns
  FROM #temp_data td
) AS pivotdata
ORDER BY
  pivotdata.pivot_columns

--Prepare the PIVOT query using the dynamic fields found above, and SUM the values.
SET @DynamicPivotQuery =
N'SELECT [pivot_rows] as ' + @rowLabel + ', ' + @PivotSelectColumnNames + '
FROM #temp_data
PIVOT(SUM(pivot_values)
FOR [pivot_columns] IN (' + @PivotColumnNames + ')) AS PVTTable'

EXECUTE(@DynamicPivotQuery)
```
