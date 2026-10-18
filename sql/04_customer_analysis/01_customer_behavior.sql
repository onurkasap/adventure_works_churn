/*
Phase 4: customer-level purchasing behavior (read-only).

Population: customers with at least one SalesOrderHeader row. Registered
customers with zero orders are intentionally excluded from the behavior
dataset and remain a separate population (701 in the prior quality review).
Order grain: one SalesOrderHeader row per order; no detail join is needed.
Monetary convention: sum header SubTotal before tax and freight, once per
order. Stored amounts are not FX-converted and must not be called consolidated
revenue. Observation cutoff is the verified maximum OrderDate, 2014-06-30.
*/

DECLARE @DatasetEnd date = '20140630';

WITH CustomerBehavior AS (
    SELECT
        h.CustomerID,
        MIN(h.OrderDate) AS FirstOrderDate,
        MAX(h.OrderDate) AS LastOrderDate,
        COUNT_BIG(*) AS OrderCount,
        SUM(h.SubTotal) AS TotalPurchaseValue,
        AVG(CONVERT(decimal(19, 4), h.SubTotal)) AS AverageOrderValue
    FROM Sales.SalesOrderHeader AS h
    GROUP BY h.CustomerID
)
SELECT
    CustomerID,
    FirstOrderDate,
    LastOrderDate,
    OrderCount,
    TotalPurchaseValue,
    AverageOrderValue,
    DATEDIFF(day, CONVERT(date, FirstOrderDate), CONVERT(date, LastOrderDate))
        AS CustomerLifetimeDays,
    DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd)
        AS DaysFromLastOrderToDatasetEnd
FROM CustomerBehavior
ORDER BY CustomerID;

-- Frequency distribution for purchasers, including every requested bucket.
WITH CustomerOrderCounts AS (
    SELECT CustomerID, COUNT_BIG(*) AS OrderCount
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
FrequencyBuckets AS (
    SELECT
        CASE
            WHEN OrderCount BETWEEN 1 AND 5 THEN CONVERT(varchar(10), OrderCount)
            WHEN OrderCount BETWEEN 6 AND 10 THEN '6-10'
            ELSE '11+'
        END AS OrderFrequency,
        CASE
            WHEN OrderCount BETWEEN 1 AND 5 THEN CONVERT(int, OrderCount)
            WHEN OrderCount BETWEEN 6 AND 10 THEN 6
            ELSE 11
        END AS SortOrder
    FROM CustomerOrderCounts
)
SELECT
    OrderFrequency,
    COUNT_BIG(*) AS CustomerCount,
    CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS decimal(7, 3))
        AS PercentOfPurchasingCustomers
FROM FrequencyBuckets
GROUP BY OrderFrequency, SortOrder
ORDER BY SortOrder;

-- Date and span summaries. DATEDIFF(day) counts calendar-day boundaries.
WITH CustomerBehavior AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate,
           MAX(OrderDate) AS LastOrderDate
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
)
SELECT DISTINCT
    MIN(FirstOrderDate) OVER () AS FirstOrderDate_Min,
    CONVERT(datetime, PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY CONVERT(float, FirstOrderDate)) OVER ()) AS FirstOrderDate_Median,
    MAX(FirstOrderDate) OVER () AS FirstOrderDate_Max,
    MIN(LastOrderDate) OVER () AS LastOrderDate_Min,
    CONVERT(datetime, PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY CONVERT(float, LastOrderDate)) OVER ()) AS LastOrderDate_Median,
    MAX(LastOrderDate) OVER () AS LastOrderDate_Max,
    MIN(CustomerLifetimeDays) OVER () AS CustomerLifetimeDays_Min,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY CustomerLifetimeDays) OVER ()
        AS CustomerLifetimeDays_Median,
    AVG(CONVERT(decimal(19, 4), CustomerLifetimeDays))
        OVER () AS CustomerLifetimeDays_Mean,
    MAX(CustomerLifetimeDays) OVER () AS CustomerLifetimeDays_Max,
    MIN(DaysFromLastOrderToDatasetEnd) OVER () AS DaysFromLastOrderToDatasetEnd_Min,
    PERCENTILE_CONT(0.50) WITHIN GROUP
        (ORDER BY DaysFromLastOrderToDatasetEnd) OVER ()
        AS DaysFromLastOrderToDatasetEnd_Median,
    AVG(CONVERT(decimal(19, 4), DaysFromLastOrderToDatasetEnd))
        OVER () AS DaysFromLastOrderToDatasetEnd_Mean,
    MAX(DaysFromLastOrderToDatasetEnd) OVER () AS DaysFromLastOrderToDatasetEnd_Max
FROM (
    SELECT
        FirstOrderDate,
        LastOrderDate,
        DATEDIFF(day, CONVERT(date, FirstOrderDate), CONVERT(date, LastOrderDate))
            AS CustomerLifetimeDays,
        DATEDIFF(day, CONVERT(date, LastOrderDate), CONVERT(date, '20140630'))
            AS DaysFromLastOrderToDatasetEnd
    FROM CustomerBehavior
) AS summarized;

-- Population, order-count, and raw SubTotal reconciliation to Phase 3.
WITH CustomerBehavior AS (
    SELECT
        CustomerID,
        COUNT_BIG(*) AS OrderCount,
        SUM(SubTotal) AS TotalPurchaseValue
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
)
SELECT
    COUNT_BIG(*) AS PurchasingCustomers,
    SUM(OrderCount) AS OrderCount,
    SUM(TotalPurchaseValue) AS TotalPurchaseValue_StoredUnconverted,
    SUM(CASE WHEN OrderCount = 1 THEN 1 ELSE 0 END) AS OneTimeCustomers,
    SUM(CASE WHEN OrderCount > 1 THEN 1 ELSE 0 END) AS RepeatCustomers
FROM CustomerBehavior;
