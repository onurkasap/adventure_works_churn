/* Categorical profile cross-check: repeat status, historical channel flags,
   and current customer structure. Each row is a customer within snapshot. */
WITH S AS (
 SELECT * FROM (VALUES
 ('A_2012',CONVERT(date,'20120630'),CONVERT(date,'20120701'),CONVERT(date,'20130630')),
 ('B_2013',CONVERT(date,'20130630'),CONVERT(date,'20130701'),CONVERT(date,'20140630'))
 )v(SnapshotID,Cutoff,OutcomeStart,OutcomeEnd)
), O AS (
 SELECT s.SnapshotID,s.Cutoff,h.CustomerID,h.SalesOrderID,h.OrderDate,h.OnlineOrderFlag,
 ROW_NUMBER() OVER(PARTITION BY s.SnapshotID,h.CustomerID ORDER BY h.OrderDate,h.SalesOrderID) FirstRank,
 ROW_NUMBER() OVER(PARTITION BY s.SnapshotID,h.CustomerID ORDER BY h.OrderDate DESC,h.SalesOrderID DESC) LastRank
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.Cutoff)
), C AS (
 SELECT SnapshotID,Cutoff,CustomerID,COUNT_BIG(*) Frequency,
 MAX(CASE WHEN FirstRank=1 THEN CONVERT(int,OnlineOrderFlag) END) FirstOrderOnlineFlag,
 MAX(CASE WHEN LastRank=1 THEN CONVERT(int,OnlineOrderFlag) END) LastOrderOnlineFlag
 FROM O GROUP BY SnapshotID,Cutoff,CustomerID
), Y AS (
 SELECT s.SnapshotID,c.CustomerID,CONVERT(int,CASE WHEN EXISTS(
 SELECT 1 FROM Sales.SalesOrderHeader x WHERE x.CustomerID=c.CustomerID AND x.OrderDate>=s.OutcomeStart AND x.OrderDate<DATEADD(day,1,s.OutcomeEnd)
 ) THEN 0 ELSE 1 END) AnalyticalChurn FROM S s JOIN C c ON c.SnapshotID=s.SnapshotID
), X AS (
 SELECT c.SnapshotID,c.CustomerID,c.Frequency,c.FirstOrderOnlineFlag,c.LastOrderOnlineFlag,y.AnalyticalChurn,
 CASE WHEN sc.PersonID IS NOT NULL AND sc.StoreID IS NULL THEN 'Person only'
 WHEN sc.PersonID IS NOT NULL AND sc.StoreID IS NOT NULL THEN 'Person and Store'
 WHEN sc.PersonID IS NULL AND sc.StoreID IS NOT NULL THEN 'Store only' ELSE 'Neither/unknown' END CustomerStructure
 FROM C c JOIN Y y ON y.SnapshotID=c.SnapshotID AND y.CustomerID=c.CustomerID
 JOIN Sales.Customer sc ON sc.CustomerID=c.CustomerID
)
SELECT SnapshotID,'One-order/repeat' Feature,
 CASE WHEN Frequency=1 THEN 'One order so far' ELSE 'Repeat so far (2+)' END Category,
 AnalyticalChurn,COUNT_BIG(*) CustomerCount
FROM X GROUP BY SnapshotID,CASE WHEN Frequency=1 THEN 'One order so far' ELSE 'Repeat so far (2+)' END,AnalyticalChurn
UNION ALL
SELECT SnapshotID,'FirstOrderOnlineFlag',CONVERT(varchar(20),FirstOrderOnlineFlag),AnalyticalChurn,COUNT_BIG(*)
FROM X GROUP BY SnapshotID,FirstOrderOnlineFlag,AnalyticalChurn
UNION ALL
SELECT SnapshotID,'LastOrderOnlineFlag',CONVERT(varchar(20),LastOrderOnlineFlag),AnalyticalChurn,COUNT_BIG(*)
FROM X GROUP BY SnapshotID,LastOrderOnlineFlag,AnalyticalChurn
UNION ALL
SELECT SnapshotID,'CustomerStructure',CustomerStructure,AnalyticalChurn,COUNT_BIG(*)
FROM X GROUP BY SnapshotID,CustomerStructure,AnalyticalChurn
ORDER BY SnapshotID,Feature,Category,AnalyticalChurn;
