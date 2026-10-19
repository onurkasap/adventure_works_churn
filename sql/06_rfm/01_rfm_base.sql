/*
Phase 6: one row per purchasing customer at the 2014-06-30 cutoff.
MonetaryRaw and AverageOrderValueRaw are stored SubTotal amounts before tax
and freight. They are not converted to a common currency and must not be
presented as directly comparable consolidated customer value.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerOrders AS (
    SELECT h.CustomerID, h.SalesOrderID, h.OrderDate, h.SubTotal
    FROM Sales.SalesOrderHeader AS h
    WHERE h.OrderDate < DATEADD(day, 1, @DatasetEnd)
), CustomerRFM AS (
    SELECT CustomerID,
           MIN(OrderDate) AS FirstOrderDate,
           MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency,
           SUM(SubTotal) AS MonetaryRaw,
           AVG(CONVERT(decimal(19, 4), SubTotal)) AS AverageOrderValueRaw
    FROM CustomerOrders
    GROUP BY CustomerID
)
SELECT CustomerID, FirstOrderDate, LastOrderDate,
       DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays,
       Frequency,
       MonetaryRaw AS MonetaryRaw_StoredUnconverted,
       AverageOrderValueRaw AS AverageOrderValueRaw_StoredUnconverted,
       DATEDIFF(day, CONVERT(date, FirstOrderDate), CONVERT(date, LastOrderDate)) AS CustomerLifetimeDays
FROM CustomerRFM
ORDER BY CustomerID;

-- Reconcile RFM base population, frequency, recency bounds and stored subtotal.
WITH CustomerRFM AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency, SUM(SubTotal) AS MonetaryRaw
    FROM Sales.SalesOrderHeader
    WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
)
SELECT COUNT_BIG(*) AS PurchasingCustomers,
       SUM(Frequency) AS ObservedOrders,
       SUM(CASE WHEN Frequency = 1 THEN 1 ELSE 0 END) AS OneTimeCustomers,
       SUM(CASE WHEN Frequency > 1 THEN 1 ELSE 0 END) AS RepeatCustomers,
       MIN(DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd)) AS MinimumRecencyDays,
       SUM(MonetaryRaw) AS MonetaryRawTotal_StoredUnconverted
FROM CustomerRFM;
