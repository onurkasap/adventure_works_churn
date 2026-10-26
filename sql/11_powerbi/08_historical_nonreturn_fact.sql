/* Phase 8 fixed snapshots; one row per snapshot/customer. Outcome is kept
   separate from cutoff features. AnalyticalNonReturn is not permanent churn. */
WITH S AS (
 SELECT * FROM (VALUES ('A_2012',CONVERT(date,'20120630'),CONVERT(date,'20120701'),CONVERT(date,'20130630')),
 ('B_2013',CONVERT(date,'20130630'),CONVERT(date,'20130701'),CONVERT(date,'20140630')))
 v(SnapshotID,SnapshotDate,OutcomeStart,OutcomeEnd)
), Eligible AS (
 SELECT s.SnapshotID,s.SnapshotDate,s.OutcomeStart,s.OutcomeEnd,h.CustomerID,
 COUNT_BIG(*) Frequency,MIN(h.OrderDate) FirstOrderDate,MAX(h.OrderDate) LastOrderDate,
 SUM(CASE WHEN h.OnlineOrderFlag=1 THEN 1 ELSE 0 END) OnlineOrderCount
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
 GROUP BY s.SnapshotID,s.SnapshotDate,s.OutcomeStart,s.OutcomeEnd,h.CustomerID
)
SELECT e.SnapshotID,e.SnapshotDate,e.CustomerID,e.Frequency,
 DATEDIFF(day,CONVERT(date,e.LastOrderDate),e.SnapshotDate) RecencyDays,
 e.OnlineOrderCount*1.0/e.Frequency OnlineOrderShare,
 CONVERT(bit,CASE WHEN EXISTS (SELECT 1 FROM Sales.SalesOrderHeader f
 WHERE f.CustomerID=e.CustomerID AND f.OrderDate>=e.OutcomeStart
 AND f.OrderDate<DATEADD(day,1,e.OutcomeEnd)) THEN 0 ELSE 1 END) AnalyticalNonReturn,
 CONVERT(bit,CASE WHEN e.SnapshotID='A_2012' AND EXISTS (SELECT 1 FROM Sales.SalesOrderHeader r
 WHERE r.CustomerID=e.CustomerID AND r.OrderDate>='20130701' AND r.OrderDate<'20140701') THEN 1
 WHEN e.SnapshotID='A_2012' THEN 0 ELSE NULL END) ReturnedInNextObservableYear
FROM Eligible e;
