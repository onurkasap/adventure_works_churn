/*
Two different eligibility views, neither a final churn label:
1) Snapshot: inactivity reached T by cutoff, or follow-up is shorter than T.
2) First-purchase fixed window: complete T-day follow-up and a later order in
   (FirstOrderDate, FirstOrderDate + T]. A full no-return window means only no
   observed return within that defined period; return after it remains unknown.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerHistory AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), Thresholds AS (
    SELECT ThresholdDays FROM (VALUES (180),(365),(540)) AS t(ThresholdDays)
), SnapshotEligibility AS (
    SELECT t.ThresholdDays, c.CustomerID, c.Frequency,
           DATEDIFF(day, CONVERT(date, c.LastOrderDate), @DatasetEnd) AS RecencyDays,
           CASE WHEN DATEDIFF(day, CONVERT(date, c.LastOrderDate), @DatasetEnd) >= t.ThresholdDays
                THEN 'Observed inactivity reached threshold; future return unknown'
                ELSE 'Below threshold at cutoff (right-censored)' END AS EligibilityStatus
    FROM CustomerHistory AS c CROSS JOIN Thresholds AS t
)
SELECT ThresholdDays, EligibilityStatus,
       CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END AS CustomerType,
       COUNT_BIG(*) AS CustomerCount
FROM SnapshotEligibility
GROUP BY ThresholdDays, EligibilityStatus, CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END
ORDER BY ThresholdDays, CustomerType, EligibilityStatus;

-- Fixed follow-up from first observed order, comparable to Phase 4 return windows.
WITH CustomerHistory AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), Thresholds AS (
    SELECT ThresholdDays FROM (VALUES (180),(365),(540)) AS t(ThresholdDays)
), FixedWindow AS (
    SELECT c.CustomerID, c.FirstOrderDate, c.Frequency, t.ThresholdDays,
           DATEADD(day, t.ThresholdDays, c.FirstOrderDate) AS FollowUpEnd,
           CASE WHEN CONVERT(date, c.FirstOrderDate) <= DATEADD(day, -t.ThresholdDays, @DatasetEnd)
                THEN 1 ELSE 0 END AS IsEligible
    FROM CustomerHistory AS c CROSS JOIN Thresholds AS t
), ReturnFlag AS (
    SELECT w.*,
           CASE WHEN w.IsEligible = 1 AND EXISTS (
               SELECT 1 FROM Sales.SalesOrderHeader AS h
               WHERE h.CustomerID = w.CustomerID
                 AND h.OrderDate > w.FirstOrderDate AND h.OrderDate <= w.FollowUpEnd
           ) THEN 1 ELSE 0 END AS ReturnedWithinWindow
    FROM FixedWindow AS w
)
SELECT ThresholdDays, CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END AS FullExtractCustomerType,
       COUNT_BIG(*) AS PurchasingCustomers,
       SUM(IsEligible) AS CustomersWithCompleteFollowUp,
       SUM(CASE WHEN IsEligible = 0 THEN 1 ELSE 0 END) AS CustomersCensoredBeforeWindowEnd,
       SUM(CASE WHEN IsEligible = 1 AND ReturnedWithinWindow = 1 THEN 1 ELSE 0 END) AS ReturnedWithinThreshold,
       SUM(CASE WHEN IsEligible = 1 AND ReturnedWithinWindow = 0 THEN 1 ELSE 0 END) AS NoObservedReturnWithinThreshold
FROM ReturnFlag
GROUP BY ThresholdDays, CASE WHEN Frequency = 1 THEN 'One-time' ELSE 'Repeat' END
ORDER BY ThresholdDays, FullExtractCustomerType;
