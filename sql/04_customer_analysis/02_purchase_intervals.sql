/*
Consecutive observed purchase intervals (read-only).
Order rows are sequenced by OrderDate and SalesOrderID for a stable order when
timestamps tie. DATEDIFF(day) measures calendar-day boundaries; two separate
orders on the same calendar date therefore have a zero-day interval.
Customers with one observed order have no measurable interval and are not in
this interval population. No interval is a churn label or threshold.
*/

WITH OrderedPurchases AS (
    SELECT
        CustomerID,
        SalesOrderID,
        OrderDate,
        LAG(OrderDate) OVER (
            PARTITION BY CustomerID
            ORDER BY OrderDate, SalesOrderID
        ) AS PreviousOrderDate
    FROM Sales.SalesOrderHeader
),
PurchaseIntervals AS (
    SELECT
        CustomerID,
        DATEDIFF(day, CONVERT(date, PreviousOrderDate), CONVERT(date, OrderDate))
            AS IntervalDays
    FROM OrderedPurchases
    WHERE PreviousOrderDate IS NOT NULL
),
IntervalSummary AS (
    SELECT
        COUNT_BIG(*) OVER () AS PurchaseIntervalCount,
        MIN(IntervalDays) OVER () AS MinimumIntervalDays,
        AVG(CONVERT(decimal(19, 4), IntervalDays)) OVER () AS AverageIntervalDays,
        MAX(IntervalDays) OVER () AS MaximumIntervalDays,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY IntervalDays) OVER () AS P25,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY IntervalDays) OVER () AS P50,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY IntervalDays) OVER () AS P75,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY IntervalDays) OVER () AS P90
    FROM PurchaseIntervals
),
RepeatCustomers AS (
    SELECT COUNT_BIG(*) AS CustomersWithMeasurableRepeatIntervals
    FROM (
        SELECT CustomerID
        FROM PurchaseIntervals
        GROUP BY CustomerID
    ) AS customers
)
SELECT DISTINCT
    r.CustomersWithMeasurableRepeatIntervals,
    s.PurchaseIntervalCount,
    s.MinimumIntervalDays,
    s.P25 AS IntervalDays_P25,
    s.P50 AS IntervalDays_Median,
    s.P75 AS IntervalDays_P75,
    s.P90 AS IntervalDays_P90,
    s.AverageIntervalDays,
    s.MaximumIntervalDays
FROM IntervalSummary AS s
CROSS JOIN RepeatCustomers AS r;

-- Optional frequency table of interval lengths for distribution inspection.
WITH OrderedPurchases AS (
    SELECT CustomerID, OrderDate,
           LAG(OrderDate) OVER (
               PARTITION BY CustomerID ORDER BY OrderDate, SalesOrderID
           ) AS PreviousOrderDate
    FROM Sales.SalesOrderHeader
)
SELECT
    DATEDIFF(day, CONVERT(date, PreviousOrderDate), CONVERT(date, OrderDate))
        AS IntervalDays,
    COUNT_BIG(*) AS PurchaseIntervalCount
FROM OrderedPurchases
WHERE PreviousOrderDate IS NOT NULL
GROUP BY DATEDIFF(day, CONVERT(date, PreviousOrderDate), CONVERT(date, OrderDate))
ORDER BY IntervalDays;
