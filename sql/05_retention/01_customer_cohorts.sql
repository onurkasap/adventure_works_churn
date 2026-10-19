/*
Phase 5: first-observed-purchase cohort assignment (read-only).

The extract starts 2011-05-31, so FirstObservedOrderDate is not necessarily
the customer's true first-ever purchase. This query includes purchasers only;
registered customers without orders remain outside post-purchase retention.
One row per CustomerID is preserved by aggregating order headers first.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerFirstOrder AS (
    SELECT
        h.CustomerID,
        MIN(h.OrderDate) AS FirstObservedOrderDate,
        COUNT_BIG(*) AS ObservedOrderCount
    FROM Sales.SalesOrderHeader AS h
    WHERE h.OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY h.CustomerID
)
SELECT
    CustomerID,
    FirstObservedOrderDate,
    DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1)
        AS CohortMonth,
    ObservedOrderCount
FROM CustomerFirstOrder
ORDER BY CustomerID;

-- Cohort sizes and boundaries; a separate aggregation for easy reporting.
WITH CustomerFirstOrder AS (
    SELECT h.CustomerID, MIN(h.OrderDate) AS FirstObservedOrderDate
    FROM Sales.SalesOrderHeader AS h
    WHERE h.OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY h.CustomerID
), Cohorts AS (
    SELECT DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1)
        AS CohortMonth, COUNT_BIG(*) AS CohortSize
    FROM CustomerFirstOrder
    GROUP BY DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1)
)
SELECT CohortMonth, CohortSize,
       MIN(CohortMonth) OVER () AS EarliestCohortMonth,
       MAX(CohortMonth) OVER () AS LatestCohortMonth
FROM Cohorts
ORDER BY CohortMonth;

-- Population reconciliation, including the separate zero-order population.
SELECT
    (SELECT COUNT_BIG(*) FROM Sales.Customer) AS RegisteredCustomers,
    (SELECT COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd))
        AS ObservedOrders,
    (SELECT COUNT_BIG(DISTINCT CustomerID) FROM Sales.SalesOrderHeader
      WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)) AS PurchasingCustomers,
    (SELECT COUNT_BIG(*) FROM Sales.Customer AS c
      WHERE NOT EXISTS (SELECT 1 FROM Sales.SalesOrderHeader AS h WHERE h.CustomerID = c.CustomerID))
        AS RegisteredCustomersWithoutOrders;
