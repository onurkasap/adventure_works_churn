/* Snapshot eligibility and 365-day outcome reconciliation. Read-only source. */
WITH Snapshots AS (
    SELECT * FROM (VALUES
        ('A_2012', CONVERT(date,'20120630'), CONVERT(date,'20120701'), CONVERT(date,'20130630')),
        ('B_2013', CONVERT(date,'20130630'), CONVERT(date,'20130701'), CONVERT(date,'20140630'))
    ) v(SnapshotID, SnapshotDate, OutcomeStart, OutcomeEnd)
), Eligible AS (
    SELECT s.SnapshotID,s.SnapshotDate,s.OutcomeStart,s.OutcomeEnd,h.CustomerID
    FROM Snapshots s JOIN Sales.SalesOrderHeader h
      ON h.OrderDate < DATEADD(day,1,s.SnapshotDate)
    GROUP BY s.SnapshotID,s.SnapshotDate,s.OutcomeStart,s.OutcomeEnd,h.CustomerID
), Outcomes AS (
    SELECT e.*, CASE WHEN EXISTS (
        SELECT 1 FROM Sales.SalesOrderHeader f
        WHERE f.CustomerID=e.CustomerID AND f.OrderDate>=e.OutcomeStart
          AND f.OrderDate<DATEADD(day,1,e.OutcomeEnd)
    ) THEN 1 ELSE 0 END AS Returned
    FROM Eligible e
)
SELECT SnapshotID,SnapshotDate,OutcomeStart,OutcomeEnd,COUNT_BIG(*) EligibleCustomers,
       SUM(Returned) ReturnedCustomers,COUNT_BIG(*)-SUM(Returned) AnalyticalChurnCustomers,
       CAST(1.0*SUM(Returned)/COUNT_BIG(*) AS decimal(9,6)) ReturnRate,
       CAST(1.0*(COUNT_BIG(*)-SUM(Returned))/COUNT_BIG(*) AS decimal(9,6)) AnalyticalChurnRate
FROM Outcomes GROUP BY SnapshotID,SnapshotDate,OutcomeStart,OutcomeEnd ORDER BY SnapshotDate;
