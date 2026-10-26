/* Fixed Phase 6 RF snapshot at 2014-06-30. Labels must not respond to date slicers.
   Logic intentionally follows sql/06_rfm/04_customer_segments.sql. */
DECLARE @DatasetEnd date='20140630';
WITH CustomerOrders AS (
 SELECT CustomerID,MIN(OrderDate) FirstOrderDate,MAX(OrderDate) LastOrderDate,COUNT_BIG(*) Frequency
 FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day,1,@DatasetEnd) GROUP BY CustomerID
), Measures AS (
 SELECT *,DATEDIFF(day,CONVERT(date,LastOrderDate),@DatasetEnd) RecencyDays FROM CustomerOrders
), Cutpoints AS (
 SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P20,
 PERCENTILE_CONT(.40) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P40,
 PERCENTILE_CONT(.60) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P60,
 PERCENTILE_CONT(.80) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P80 FROM Measures
), Scored AS (
 SELECT m.*,CASE WHEN m.RecencyDays<=c.P20 THEN 5 WHEN m.RecencyDays<=c.P40 THEN 4
 WHEN m.RecencyDays<=c.P60 THEN 3 WHEN m.RecencyDays<=c.P80 THEN 2 ELSE 1 END RScore,
 CASE WHEN Frequency=1 THEN 1 WHEN Frequency=2 THEN 2 WHEN Frequency=3 THEN 3
 WHEN Frequency BETWEEN 4 AND 5 THEN 4 ELSE 5 END FScore FROM Measures m CROSS JOIN Cutpoints c
)
SELECT CustomerID,CONVERT(date,FirstOrderDate) FirstObservedOrderDate,CONVERT(date,LastOrderDate) LastObservedOrderDate,
 RecencyDays,Frequency,RScore,FScore,
 CASE WHEN RScore>=4 AND FScore>=4 THEN 'Highly engaged repeat buyers'
 WHEN RScore<=3 AND FScore>=4 THEN 'Repeat buyers, longer since purchase'
 WHEN RScore>=4 AND FScore BETWEEN 2 AND 3 THEN 'Recent developing repeat buyers'
 WHEN RScore<=3 AND FScore BETWEEN 2 AND 3 THEN 'Developing repeat buyers, longer gap'
 WHEN RScore>=4 AND FScore=1 THEN 'Recent one-time buyers'
 ELSE 'One-time buyers, longer since purchase' END CustomerSegment,
 CONVERT(date,@DatasetEnd) SnapshotDate
FROM Scored;
