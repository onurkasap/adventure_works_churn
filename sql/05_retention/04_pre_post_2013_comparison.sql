/*
Exploratory retention by first-observed purchase before vs. from July 2013.
This is a descriptive grouping around an observed volume shift; it does not
imply an intervention or causal effect. Rates are weighted across all eligible
customers in each group. Month horizons require complete calendar-month
observability through June 2014.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerFirstOrder AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstObservedOrderDate
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), CustomerCohort AS (
    SELECT CustomerID,
           DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1) AS CohortMonth,
           CASE WHEN DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1) < '20130701'
                THEN 'Before July 2013' ELSE 'July 2013 or later' END AS AcquisitionPeriod
    FROM CustomerFirstOrder
), CohortSizes AS (
    SELECT AcquisitionPeriod, CohortMonth, COUNT_BIG(*) AS CohortSize
    FROM CustomerCohort GROUP BY AcquisitionPeriod, CohortMonth
), CustomerOrderMonths AS (
    SELECT DISTINCT CustomerID, DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS OrderMonth
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
), ActiveCounts AS (
    SELECT c.AcquisitionPeriod, c.CohortMonth,
           DATEDIFF(month, c.CohortMonth, m.OrderMonth) AS MonthIndex,
           COUNT_BIG(*) AS ActiveCustomers
    FROM CustomerCohort AS c INNER JOIN CustomerOrderMonths AS m ON m.CustomerID = c.CustomerID
    WHERE DATEDIFF(month, c.CohortMonth, m.OrderMonth) IN (1, 3, 6, 12)
    GROUP BY c.AcquisitionPeriod, c.CohortMonth, DATEDIFF(month, c.CohortMonth, m.OrderMonth)
), Horizons AS (
    SELECT MonthIndex FROM (VALUES (1),(3),(6),(12)) AS v(MonthIndex)
), Eligible AS (
    SELECT s.AcquisitionPeriod, s.CohortMonth, s.CohortSize, h.MonthIndex
    FROM CohortSizes AS s CROSS JOIN Horizons AS h
    WHERE DATEADD(month, h.MonthIndex, s.CohortMonth)
          <= DATEFROMPARTS(YEAR(@DatasetEnd), MONTH(@DatasetEnd), 1)
)
SELECT e.AcquisitionPeriod, e.MonthIndex, COUNT_BIG(*) AS EligibleCohortCount,
       MIN(e.CohortMonth) AS EarliestEligibleCohort,
       MAX(e.CohortMonth) AS LatestEligibleCohort,
       SUM(e.CohortSize) AS EligibleCustomers,
       SUM(COALESCE(a.ActiveCustomers, CONVERT(bigint, 0))) AS ActiveCustomers,
       CAST(100.0 * SUM(COALESCE(a.ActiveCustomers, CONVERT(bigint, 0)))
            / NULLIF(SUM(e.CohortSize), 0) AS decimal(8, 3)) AS WeightedRetentionPercent
FROM Eligible AS e LEFT JOIN ActiveCounts AS a
  ON a.AcquisitionPeriod = e.AcquisitionPeriod
 AND a.CohortMonth = e.CohortMonth AND a.MonthIndex = e.MonthIndex
GROUP BY e.AcquisitionPeriod, e.MonthIndex
ORDER BY e.MonthIndex, e.AcquisitionPeriod;

-- Cohort acquisition sizes, to inspect new-purchaser volume over time.
WITH CustomerFirstOrder AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstObservedOrderDate
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
)
SELECT DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1) AS CohortMonth,
       COUNT_BIG(*) AS NewPurchasingCustomers
FROM CustomerFirstOrder
GROUP BY DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1)
ORDER BY CohortMonth;
