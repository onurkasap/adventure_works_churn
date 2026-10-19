/* Descriptive customer-level distributions; raw monetary figures are unconverted. */
DECLARE @DatasetEnd date = '20140630';

WITH CustomerRFM AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency, SUM(SubTotal) AS MonetaryRaw
    FROM Sales.SalesOrderHeader
    WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), RFMValues AS (
    SELECT CustomerID, 'RecencyDays' AS MetricName,
           CONVERT(float, DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd)) AS MetricValue
    FROM CustomerRFM
    UNION ALL
    SELECT CustomerID, 'Frequency', CONVERT(float, Frequency) FROM CustomerRFM
    UNION ALL
    SELECT CustomerID, 'MonetaryRaw_StoredUnconverted', CONVERT(float, MonetaryRaw) FROM CustomerRFM
), Distribution AS (
    SELECT MetricName, MetricValue,
           MIN(MetricValue) OVER (PARTITION BY MetricName) AS MinimumValue,
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY MetricValue) OVER (PARTITION BY MetricName) AS P25,
           PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY MetricValue) OVER (PARTITION BY MetricName) AS MedianValue,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY MetricValue) OVER (PARTITION BY MetricName) AS P75,
           PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY MetricValue) OVER (PARTITION BY MetricName) AS P90,
           AVG(MetricValue) OVER (PARTITION BY MetricName) AS MeanValue,
           MAX(MetricValue) OVER (PARTITION BY MetricName) AS MaximumValue
    FROM RFMValues
)
SELECT DISTINCT MetricName, MinimumValue, P25, MedianValue, P75, P90, MeanValue, MaximumValue
FROM Distribution
ORDER BY MetricName;

-- Preserve and expand the validated Phase 4 frequency distribution.
WITH CustomerOrders AS (
    SELECT CustomerID, COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader
    WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
)
SELECT Frequency, COUNT_BIG(*) AS CustomerCount,
       CAST(100.0 * COUNT_BIG(*) / SUM(COUNT_BIG(*)) OVER () AS decimal(7, 3)) AS PercentOfPurchasers
FROM CustomerOrders
GROUP BY Frequency
ORDER BY Frequency;
