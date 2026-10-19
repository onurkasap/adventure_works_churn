/* Historical channel and current customer-link structure, separately flagged. */
WITH S AS (
 SELECT * FROM (VALUES ('A_2012',CONVERT(date,'20120630')),('B_2013',CONVERT(date,'20130630'))) v(SnapshotID,SnapshotDate)
), O AS (
 SELECT s.SnapshotID,s.SnapshotDate,h.CustomerID,h.SalesOrderID,h.OrderDate,h.OnlineOrderFlag,
 ROW_NUMBER() OVER(PARTITION BY s.SnapshotID,h.CustomerID ORDER BY h.OrderDate,h.SalesOrderID) rn_first,
 ROW_NUMBER() OVER(PARTITION BY s.SnapshotID,h.CustomerID ORDER BY h.OrderDate DESC,h.SalesOrderID DESC) rn_last
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
), C AS (
 SELECT SnapshotID,SnapshotDate,CustomerID,MAX(CASE WHEN rn_first=1 THEN CONVERT(int,OnlineOrderFlag) END) FirstOrderOnlineFlag,
 MAX(CASE WHEN rn_last=1 THEN CONVERT(int,OnlineOrderFlag) END) LastOrderOnlineFlag,
 SUM(CASE WHEN OnlineOrderFlag=1 THEN 1 ELSE 0 END) OnlineOrderCount,
 SUM(CASE WHEN OnlineOrderFlag=0 THEN 1 ELSE 0 END) OfflineOrderCount,COUNT_BIG(*) OrderCount
 FROM O GROUP BY SnapshotID,SnapshotDate,CustomerID
)
SELECT c.*,1.0*OnlineOrderCount/NULLIF(OrderCount,0) OnlineOrderShare,
 CASE WHEN sc.PersonID IS NOT NULL AND sc.StoreID IS NULL THEN 'Person only'
      WHEN sc.PersonID IS NOT NULL AND sc.StoreID IS NOT NULL THEN 'Person and Store'
      WHEN sc.PersonID IS NULL AND sc.StoreID IS NOT NULL THEN 'Store only'
      ELSE 'Neither/unknown' END CustomerStructure
FROM C c JOIN Sales.Customer sc ON sc.CustomerID=c.CustomerID
ORDER BY SnapshotDate,c.CustomerID;
