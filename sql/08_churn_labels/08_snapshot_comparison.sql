/* Population and outcome shift checks. Descriptive only; no hypothesis tests. */
WITH S AS (
 SELECT * FROM (VALUES ('A_2012',CONVERT(date,'20120630'),CONVERT(date,'20120701'),CONVERT(date,'20130630')),
 ('B_2013',CONVERT(date,'20130630'),CONVERT(date,'20130701'),CONVERT(date,'20140630')))v(SnapshotID,SnapshotDate,OutcomeStart,OutcomeEnd)
), O AS (
 SELECT s.SnapshotID,s.SnapshotDate,h.CustomerID,h.SalesOrderID,h.OrderDate,h.OnlineOrderFlag,
 ROW_NUMBER() OVER(PARTITION BY s.SnapshotID,h.CustomerID ORDER BY h.OrderDate,h.SalesOrderID) rn1,
 ROW_NUMBER() OVER(PARTITION BY s.SnapshotID,h.CustomerID ORDER BY h.OrderDate DESC,h.SalesOrderID DESC) rnn
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
), H AS (
 SELECT SnapshotID,SnapshotDate,CustomerID,COUNT_BIG(*) Frequency,DATEDIFF(day,MAX(CONVERT(date,OrderDate)),SnapshotDate) RecencyDays,
 MAX(CASE WHEN rn1=1 THEN CONVERT(int,OnlineOrderFlag) END) FirstOrderOnlineFlag,
 SUM(CASE WHEN OnlineOrderFlag=1 THEN 1 ELSE 0 END)*1.0/COUNT_BIG(*) OnlineOrderShare
 FROM O GROUP BY SnapshotID,SnapshotDate,CustomerID
), Y AS (
 SELECT h.SnapshotID,h.CustomerID,CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader f JOIN S s ON s.SnapshotID=h.SnapshotID
 WHERE f.CustomerID=h.CustomerID AND f.OrderDate>=s.OutcomeStart AND f.OrderDate<DATEADD(day,1,s.OutcomeEnd)) THEN 1 ELSE 0 END) Returned
 FROM H h
)
/* Snapshot comparison and label profile with strictly pre-cutoff metrics. */
SELECT h.SnapshotID,y.Returned,COUNT_BIG(*) Customers,AVG(CONVERT(float,h.RecencyDays)) MeanRecencyDays,
 AVG(CONVERT(float,h.Frequency)) MeanFrequency,
 AVG(CASE WHEN h.Frequency=1 THEN 1.0 ELSE 0.0 END) OneOrderSoFarShare,
 AVG(h.OnlineOrderShare) MeanOnlineOrderShare,
 AVG(CASE WHEN h.FirstOrderOnlineFlag=1 THEN 1.0 ELSE 0.0 END) FirstOrderOnlineShare
FROM H h JOIN Y y ON y.SnapshotID=h.SnapshotID AND y.CustomerID=h.CustomerID
GROUP BY h.SnapshotID,y.Returned ORDER BY h.SnapshotID,y.Returned;
