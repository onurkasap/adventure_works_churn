/*
Candidate inactivity thresholds and snapshot status as of 2014-06-30.
"Reached threshold" means only that no later order is observed for at least
that many days before the extract ends. It is not confirmation that the
customer never returned after the cutoff.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerHistory AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), Thresholds AS (
    SELECT ThresholdDays FROM (VALUES (180),(365),(540)) AS t(ThresholdDays)
), CustomerSnapshot AS (
    SELECT c.CustomerID, c.Frequency,
           DATEDIFF(day, CONVERT(date, c.LastOrderDate), @DatasetEnd) AS RecencyDays,
           t.ThresholdDays,
           CASE WHEN DATEDIFF(day, CONVERT(date, c.LastOrderDate), @DatasetEnd) >= t.ThresholdDays
                THEN 'Observed inactivity reached threshold'
                ELSE 'Below threshold at cutoff (right-censored)' END AS SnapshotStatus
    FROM CustomerHistory AS c CROSS JOIN Thresholds AS t
)
SELECT ThresholdDays, SnapshotStatus,
       CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END AS CustomerType,
       COUNT_BIG(*) AS CustomerCount
FROM CustomerSnapshot
GROUP BY ThresholdDays, SnapshotStatus, CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END
ORDER BY ThresholdDays, CustomerType, SnapshotStatus;

-- Recency distribution at cutoff, split using the validated full-extract order count.
WITH CustomerHistory AS (
    SELECT CustomerID, MAX(OrderDate) AS LastOrderDate, COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), Recency AS (
    SELECT CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END AS CustomerType,
           DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays
    FROM CustomerHistory
), Stats AS (
    SELECT CustomerType, RecencyDays,
           MIN(RecencyDays) OVER (PARTITION BY CustomerType) AS MinimumDays,
           PERCENTILE_CONT(.25) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerType) AS P25,
           PERCENTILE_CONT(.50) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerType) AS MedianDays,
           PERCENTILE_CONT(.75) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerType) AS P75,
           PERCENTILE_CONT(.90) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerType) AS P90,
           AVG(CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerType) AS MeanDays,
           MAX(RecencyDays) OVER (PARTITION BY CustomerType) AS MaximumDays
    FROM Recency
)
SELECT DISTINCT CustomerType, COUNT_BIG(*) OVER (PARTITION BY CustomerType) AS CustomerCount,
       MinimumDays, P25, MedianDays, P75, P90, MeanDays, MaximumDays
FROM Stats ORDER BY CustomerType;

-- Compare thresholds to the independently validated repeat-gap percentiles.
WITH OrderedOrders AS (
    SELECT CustomerID, OrderDate,
           LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate, SalesOrderID) AS PreviousOrderDate
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
), Gaps AS (
    SELECT DATEDIFF(day, CONVERT(date, PreviousOrderDate), CONVERT(date, OrderDate)) AS GapDays
    FROM OrderedOrders WHERE PreviousOrderDate IS NOT NULL
)
SELECT DISTINCT COUNT_BIG(*) OVER () AS CompletedRepeatIntervals,
       PERCENTILE_CONT(.50) WITHIN GROUP (ORDER BY CONVERT(float, GapDays)) OVER () AS MedianGapDays,
       PERCENTILE_CONT(.75) WITHIN GROUP (ORDER BY CONVERT(float, GapDays)) OVER () AS P75GapDays,
       PERCENTILE_CONT(.90) WITHIN GROUP (ORDER BY CONVERT(float, GapDays)) OVER () AS P90GapDays,
       AVG(CONVERT(float, GapDays)) OVER () AS MeanGapDays
FROM Gaps;
