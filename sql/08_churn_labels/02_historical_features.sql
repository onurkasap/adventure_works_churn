/* One row per eligible customer/snapshot. All features use cutoff-bounded orders. */
WITH Snapshots AS (
 SELECT * FROM (VALUES ('A_2012',CONVERT(date,'20120630')),('B_2013',CONVERT(date,'20130630'))) v(SnapshotID,SnapshotDate)
), O AS (
 SELECT s.SnapshotID,s.SnapshotDate,h.CustomerID,h.SalesOrderID,CONVERT(date,h.OrderDate) OrderDate
 FROM Snapshots s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
), G AS (
 SELECT *,LAG(OrderDate) OVER(PARTITION BY SnapshotID,CustomerID ORDER BY OrderDate,SalesOrderID) PriorOrderDate
 FROM O
), C AS (
 SELECT SnapshotID,SnapshotDate,CustomerID,MIN(OrderDate) FirstOrderDate,MAX(OrderDate) LastOrderDate,COUNT_BIG(*) Frequency,
        DATEDIFF(day,MIN(OrderDate),MAX(OrderDate)) CustomerLifetimeDays,
        DATEDIFF(day,MAX(OrderDate),SnapshotDate) RecencyDays,
        DATEDIFF(day,MIN(OrderDate),SnapshotDate) DaysSinceFirstOrder,
        AVG(CASE WHEN PriorOrderDate IS NOT NULL THEN CONVERT(float,DATEDIFF(day,PriorOrderDate,OrderDate)) END) AverageDaysBetweenOrders
 FROM G GROUP BY SnapshotID,SnapshotDate,CustomerID
), M AS (
 SELECT DISTINCT SnapshotID,CustomerID,
        PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY CONVERT(float,DATEDIFF(day,PriorOrderDate,OrderDate)))
          OVER(PARTITION BY SnapshotID,CustomerID) MedianDaysBetweenOrders
 FROM G WHERE PriorOrderDate IS NOT NULL
)
SELECT c.*,m.MedianDaysBetweenOrders,CONVERT(bit,CASE WHEN Frequency=1 THEN 1 ELSE 0 END) OneOrderSoFar,
       CONVERT(bit,CASE WHEN Frequency>1 THEN 1 ELSE 0 END) RepeatSoFar
FROM C c LEFT JOIN M m ON m.SnapshotID=c.SnapshotID AND m.CustomerID=c.CustomerID
ORDER BY c.SnapshotDate,c.CustomerID;
