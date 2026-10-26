/* Phase 5 exact-month cohort retention. One row per cohort-month/index.
   NULL means future/unobservable; observed inactivity is zero. */
DECLARE @DatasetEnd date='20140630',@MaxMonthIndex int=12;
WITH Firsts AS (
 SELECT CustomerID,MIN(OrderDate) FirstOrderDate FROM Sales.SalesOrderHeader
 WHERE OrderDate<DATEADD(day,1,@DatasetEnd) GROUP BY CustomerID
), Cohorts AS (
 SELECT CustomerID,DATEFROMPARTS(YEAR(FirstOrderDate),MONTH(FirstOrderDate),1) CohortMonth FROM Firsts
), Sizes AS (SELECT CohortMonth,COUNT_BIG(*) CohortSize FROM Cohorts GROUP BY CohortMonth),
 Months AS (
 SELECT DISTINCT CustomerID,DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1) OrderMonth
 FROM Sales.SalesOrderHeader WHERE OrderDate<DATEADD(day,1,@DatasetEnd)
), Activity AS (
 SELECT c.CohortMonth,m.OrderMonth,DATEDIFF(month,c.CohortMonth,m.OrderMonth) MonthIndex,COUNT_BIG(*) ActiveCustomers
 FROM Cohorts c JOIN Months m ON m.CustomerID=c.CustomerID
 GROUP BY c.CohortMonth,m.OrderMonth,DATEDIFF(month,c.CohortMonth,m.OrderMonth)
), Idx AS (SELECT MonthIndex FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) v(MonthIndex)),
 Grid AS (
 SELECT s.CohortMonth,s.CohortSize,i.MonthIndex,DATEADD(month,i.MonthIndex,s.CohortMonth) TargetMonth
 FROM Sizes s CROSS JOIN Idx i
)
SELECT g.CohortMonth,g.CohortSize,g.MonthIndex,g.TargetMonth,
 CASE WHEN g.TargetMonth>DATEFROMPARTS(YEAR(@DatasetEnd),MONTH(@DatasetEnd),1) THEN CAST(NULL AS bigint)
 ELSE COALESCE(a.ActiveCustomers,CONVERT(bigint,0)) END ActiveCustomers,
 CASE WHEN g.TargetMonth>DATEFROMPARTS(YEAR(@DatasetEnd),MONTH(@DatasetEnd),1) THEN CAST(NULL AS decimal(9,6))
 ELSE CAST(COALESCE(a.ActiveCustomers,0)*1.0/NULLIF(g.CohortSize,0) AS decimal(9,6)) END RetentionRate
FROM Grid g LEFT JOIN Activity a ON a.CohortMonth=g.CohortMonth AND a.OrderMonth=g.TargetMonth;
