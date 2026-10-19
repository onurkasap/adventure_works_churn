/*
Historical feature/outcome design candidates. Each customer enters a snapshot
only if they have an order on/before its feature cutoff. Features must be
recomputed from those orders only. Each candidate has a full 365-day future
window ending by 2014-06-30. Outcomes are diagnostics, not churn labels.
*/
DECLARE @DatasetEnd date = '20140630';

WITH Cutoffs AS (
    SELECT FeatureCutoff FROM (VALUES (CONVERT(date,'20120630')),(CONVERT(date,'20130630'))) AS c(FeatureCutoff)
), SnapshotCustomers AS (
    SELECT c.FeatureCutoff, h.CustomerID,
           MIN(h.OrderDate) AS FirstOrderDate,
           MAX(h.OrderDate) AS LastOrderAtCutoff,
           COUNT_BIG(*) AS FrequencyAtCutoff
    FROM Cutoffs AS c
    INNER JOIN Sales.SalesOrderHeader AS h ON h.OrderDate < DATEADD(day, 1, c.FeatureCutoff)
    GROUP BY c.FeatureCutoff, h.CustomerID
), FutureOutcome AS (
    SELECT s.FeatureCutoff, s.CustomerID,
           CASE WHEN EXISTS (
               SELECT 1 FROM Sales.SalesOrderHeader AS h
               WHERE h.CustomerID = s.CustomerID
                 AND h.OrderDate >= DATEADD(day, 1, s.FeatureCutoff)
                 AND h.OrderDate <= DATEADD(day, 365, s.FeatureCutoff)
                 AND h.OrderDate < DATEADD(day, 1, @DatasetEnd)
           ) THEN 1 ELSE 0 END AS ReturnedDuring365DayWindow
    FROM SnapshotCustomers AS s
)
SELECT s.FeatureCutoff,
       CASE WHEN s.FeatureCutoff = '20120630' THEN '2011-05-31 through 2012-06-30 (about 13 months)'
            ELSE '2011-05-31 through 2013-06-30 (about 25 months)' END AS FeatureHistoryAvailable,
       DATEADD(day, 1, s.FeatureCutoff) AS OutcomeWindowStart,
       DATEADD(day, 365, s.FeatureCutoff) AS OutcomeWindowEnd,
       COUNT_BIG(*) AS HistoricalPurchasersEligible,
       SUM(o.ReturnedDuring365DayWindow) AS CustomersWithObservedReturn,
       SUM(CASE WHEN o.ReturnedDuring365DayWindow = 0 THEN 1 ELSE 0 END) AS NoObservedReturnIn365Days
FROM SnapshotCustomers AS s
INNER JOIN FutureOutcome AS o ON o.FeatureCutoff = s.FeatureCutoff AND o.CustomerID = s.CustomerID
GROUP BY s.FeatureCutoff ORDER BY s.FeatureCutoff;

WITH Cutoffs AS (
    SELECT FeatureCutoff FROM (VALUES (CONVERT(date,'20120630')),(CONVERT(date,'20130630'))) AS c(FeatureCutoff)
)
SELECT FeatureCutoff, DATEADD(day, 365, FeatureCutoff) AS OutcomeWindowEnd,
       CASE WHEN DATEADD(day, 365, FeatureCutoff) <= @DatasetEnd THEN 'Complete in extract' ELSE 'Incomplete' END AS CoverageStatus
FROM Cutoffs ORDER BY FeatureCutoff;
