/*
Completed inter-order gaps only. Every gap > threshold ends in an observed
next purchase and demonstrates return after crossing that threshold. This is
retrospective premature-churn risk, not a production-model false-positive rate.
Incomplete final gaps are handled as censored in 03_label_eligibility.sql.
*/
DECLARE @DatasetEnd date = '20140630';

WITH OrderedOrders AS (
    SELECT CustomerID, SalesOrderID, OrderDate,
           LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate, SalesOrderID) AS PreviousOrderDate
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
), CompletedGaps AS (
    SELECT CustomerID,
           DATEDIFF(day, CONVERT(date, PreviousOrderDate), CONVERT(date, OrderDate)) AS GapDays
    FROM OrderedOrders WHERE PreviousOrderDate IS NOT NULL
), Thresholds AS (
    SELECT ThresholdDays FROM (VALUES (180),(365),(540)) AS t(ThresholdDays)
), IntervalResults AS (
    SELECT t.ThresholdDays, g.CustomerID, g.GapDays,
           CASE WHEN g.GapDays > t.ThresholdDays THEN 1 ELSE 0 END AS GapLongerThanThreshold
    FROM Thresholds AS t CROSS JOIN CompletedGaps AS g
), IntervalSummary AS (
    SELECT ThresholdDays, COUNT_BIG(*) AS CompletedIntervals,
           SUM(GapLongerThanThreshold) AS IntervalsLongerThanThreshold
    FROM IntervalResults GROUP BY ThresholdDays
), CustomerSummary AS (
    SELECT ThresholdDays, COUNT(DISTINCT CASE WHEN GapLongerThanThreshold = 1 THEN CustomerID END)
               AS CustomersWithReturnAfterThreshold
    FROM IntervalResults GROUP BY ThresholdDays
), RepeatPopulation AS (
    SELECT COUNT_BIG(*) AS RepeatCustomers
    FROM (SELECT CustomerID FROM CompletedGaps GROUP BY CustomerID) AS c
)
SELECT i.ThresholdDays, i.CompletedIntervals,
       i.IntervalsLongerThanThreshold,
       CAST(100.0 * i.IntervalsLongerThanThreshold / NULLIF(i.CompletedIntervals, 0) AS decimal(7, 3))
           AS PercentOfCompletedIntervalsLonger,
       c.CustomersWithReturnAfterThreshold,
       CAST(100.0 * c.CustomersWithReturnAfterThreshold / NULLIF(p.RepeatCustomers, 0) AS decimal(7, 3))
           AS PercentOfRepeatCustomersWithReturnAfterThreshold,
       p.RepeatCustomers AS RepeatCustomerDenominator
FROM IntervalSummary AS i
INNER JOIN CustomerSummary AS c ON c.ThresholdDays = i.ThresholdDays
CROSS JOIN RepeatPopulation AS p
ORDER BY i.ThresholdDays;

SELECT COUNT_BIG(*) AS CompletedIntervals, COUNT(DISTINCT CustomerID) AS CustomersWithCompletedInterval
FROM (
    SELECT CustomerID, LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate, SalesOrderID) AS PreviousOrderDate
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
) AS ordered_orders
WHERE PreviousOrderDate IS NOT NULL;
