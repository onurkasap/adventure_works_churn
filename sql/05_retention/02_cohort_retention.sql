/*
Phase 5: monthly cohort retention (read-only).

Order grain is SalesOrderHeader. DISTINCT customer/month pairs ensure a
customer with multiple orders in a month counts once. MonthIndex uses calendar
month boundaries. Cells whose target month is beyond June 2014 are NULL (not
observable); zero is reserved for an observable month with no active buyers.
*/
DECLARE @DatasetEnd date = '20140630';
DECLARE @MaxMonthIndex int = 12;

WITH CustomerFirstOrder AS (
    SELECT h.CustomerID, MIN(h.OrderDate) AS FirstObservedOrderDate
    FROM Sales.SalesOrderHeader AS h
    WHERE h.OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY h.CustomerID
), CustomerCohort AS (
    SELECT CustomerID,
           DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1) AS CohortMonth
    FROM CustomerFirstOrder
), CohortSizes AS (
    SELECT CohortMonth, COUNT_BIG(*) AS CohortSize
    FROM CustomerCohort
    GROUP BY CohortMonth
), CustomerOrderMonths AS (
    SELECT DISTINCT h.CustomerID,
           DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1) AS OrderMonth
    FROM Sales.SalesOrderHeader AS h
    WHERE h.OrderDate < DATEADD(day, 1, @DatasetEnd)
), CustomerMonthActivity AS (
    SELECT c.CohortMonth, m.OrderMonth, c.CustomerID,
           DATEDIFF(month, c.CohortMonth, m.OrderMonth) AS MonthIndex
    FROM CustomerCohort AS c
    INNER JOIN CustomerOrderMonths AS m ON m.CustomerID = c.CustomerID
), ActiveCounts AS (
    SELECT CohortMonth, MonthIndex, COUNT_BIG(*) AS ActiveCustomers
    FROM CustomerMonthActivity
    WHERE MonthIndex BETWEEN 0 AND @MaxMonthIndex
    GROUP BY CohortMonth, MonthIndex
), MonthIndexes AS (
    SELECT MonthIndex FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) AS v(MonthIndex)
), CohortGrid AS (
    SELECT s.CohortMonth, s.CohortSize, i.MonthIndex,
           DATEADD(month, i.MonthIndex, s.CohortMonth) AS TargetMonth
    FROM CohortSizes AS s CROSS JOIN MonthIndexes AS i
)
SELECT g.CohortMonth, g.MonthIndex, g.CohortSize,
       CASE WHEN g.TargetMonth > DATEFROMPARTS(YEAR(@DatasetEnd), MONTH(@DatasetEnd), 1)
            THEN CAST(NULL AS bigint) ELSE COALESCE(a.ActiveCustomers, CONVERT(bigint, 0)) END
            AS ActiveCustomers,
       CASE WHEN g.TargetMonth > DATEFROMPARTS(YEAR(@DatasetEnd), MONTH(@DatasetEnd), 1)
            THEN CAST(NULL AS decimal(9, 6))
            ELSE CAST(COALESCE(a.ActiveCustomers, 0) * 1.0 / NULLIF(g.CohortSize, 0) AS decimal(9, 6))
       END AS RetentionRate
FROM CohortGrid AS g
LEFT JOIN ActiveCounts AS a
  ON a.CohortMonth = g.CohortMonth AND a.MonthIndex = g.MonthIndex
ORDER BY g.CohortMonth, g.MonthIndex;

-- Validation: each purchaser has one cohort; MonthIndex never negative;
-- month zero equals cohort size; each customer/month is unique by construction.
WITH CustomerFirstOrder AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstObservedOrderDate
    FROM Sales.SalesOrderHeader
    WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), CustomerCohort AS (
    SELECT CustomerID, DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1) AS CohortMonth
    FROM CustomerFirstOrder
), CohortSizes AS (
    SELECT CohortMonth, COUNT_BIG(*) AS CohortSize FROM CustomerCohort GROUP BY CohortMonth
), MonthZeroActivity AS (
    SELECT c.CohortMonth, COUNT_BIG(DISTINCT h.CustomerID) AS ActiveCustomers
    FROM CustomerCohort AS c
    INNER JOIN Sales.SalesOrderHeader AS h
      ON h.CustomerID = c.CustomerID
     AND DATEFROMPARTS(YEAR(h.OrderDate), MONTH(h.OrderDate), 1) = c.CohortMonth
    WHERE h.OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY c.CohortMonth
), MonthlyPairs AS (
    SELECT DISTINCT CustomerID,
           DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS OrderMonth
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
)
SELECT
    (SELECT COUNT_BIG(*) FROM CustomerCohort) AS CohortCustomerRows,
    (SELECT COUNT_BIG(DISTINCT CustomerID) FROM CustomerCohort) AS UniqueCohortCustomers,
    (SELECT COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)) AS ObservedOrders,
    (SELECT COUNT_BIG(DISTINCT CustomerID) FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)) AS SourcePurchasers,
    (SELECT COUNT_BIG(*) FROM CustomerCohort AS c
      WHERE EXISTS (SELECT 1 FROM MonthlyPairs AS p WHERE p.CustomerID = c.CustomerID AND p.OrderMonth < c.CohortMonth))
      AS CustomersWithNegativeMonthIndex,
    (SELECT COUNT_BIG(*) FROM CohortSizes AS s
      LEFT JOIN MonthZeroActivity AS z ON z.CohortMonth = s.CohortMonth
      WHERE s.CohortSize <> COALESCE(z.ActiveCustomers, 0)) AS CohortsFailingMonthZero,
    (SELECT COUNT_BIG(*) FROM (
        SELECT CustomerID, OrderMonth FROM MonthlyPairs GROUP BY CustomerID, OrderMonth HAVING COUNT_BIG(*) > 1
      ) AS duplicated_pairs) AS DuplicateCustomerMonthPairs;
