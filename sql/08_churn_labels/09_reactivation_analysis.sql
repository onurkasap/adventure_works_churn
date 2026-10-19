/* Later activity among Snapshot A customers with no return in its first year.
   Original A labels remain unchanged. Snapshot B has no observable later window. */
WITH A AS (
 SELECT h.CustomerID,CONVERT(bit,CASE WHEN EXISTS(
  SELECT 1 FROM Sales.SalesOrderHeader f WHERE f.CustomerID=h.CustomerID
   AND f.OrderDate>='20120701' AND f.OrderDate<'20130701'
 ) THEN 0 ELSE 1 END) AnalyticalChurn
 FROM Sales.SalesOrderHeader h WHERE h.OrderDate<'20120701' GROUP BY h.CustomerID
), R AS (
 SELECT a.CustomerID,a.AnalyticalChurn,CONVERT(bit,CASE WHEN EXISTS(
  SELECT 1 FROM Sales.SalesOrderHeader f WHERE f.CustomerID=a.CustomerID
   AND f.OrderDate>='20130701' AND f.OrderDate<'20140701'
 ) THEN 1 ELSE 0 END) LaterReturnAfterLabelWindow
 FROM A a
)
SELECT COUNT_BIG(*) SnapshotACustomers,
 SUM(CASE WHEN AnalyticalChurn=1 THEN 1 ELSE 0 END) SnapshotAChurnProxy,
 SUM(CASE WHEN AnalyticalChurn=1 AND LaterReturnAfterLabelWindow=1 THEN 1 ELSE 0 END) LaterReactivated,
 CAST(100.0*SUM(CASE WHEN AnalyticalChurn=1 AND LaterReturnAfterLabelWindow=1 THEN 1 ELSE 0 END)/
 NULLIF(SUM(CASE WHEN AnalyticalChurn=1 THEN 1 ELSE 0 END),0) AS decimal(7,3)) ReactivationPercentOfChurnProxy
FROM R;

SELECT 'Snapshot B' SnapshotID,'Not observable: extract ends 2014-06-30' ReactivationObservation;
