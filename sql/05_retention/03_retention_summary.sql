/*
Weighted retention at selected calendar-month horizons. A cohort is eligible
only when its entire target calendar month is at or before 2014-06-30. The
weighted rate is sum(active customers) / sum(cohort sizes), not an average of
cohort percentages. Eligible cohorts and component totals are returned.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerFirstOrder AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstObservedOrderDate
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), CustomerCohort AS (
    SELECT CustomerID, DATEFROMPARTS(YEAR(FirstObservedOrderDate), MONTH(FirstObservedOrderDate), 1) AS CohortMonth
    FROM CustomerFirstOrder
), CohortSizes AS (
    SELECT CohortMonth, COUNT_BIG(*) AS CohortSize FROM CustomerCohort GROUP BY CohortMonth
), CustomerOrderMonths AS (
    SELECT DISTINCT CustomerID, DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS OrderMonth
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
), ActiveCounts AS (
    SELECT c.CohortMonth, DATEDIFF(month, c.CohortMonth, m.OrderMonth) AS MonthIndex,
           COUNT_BIG(*) AS ActiveCustomers
    FROM CustomerCohort AS c INNER JOIN CustomerOrderMonths AS m ON m.CustomerID = c.CustomerID
    WHERE DATEDIFF(month, c.CohortMonth, m.OrderMonth) IN (1, 3, 6, 12)
    GROUP BY c.CohortMonth, DATEDIFF(month, c.CohortMonth, m.OrderMonth)
), Horizons AS (
    SELECT MonthIndex FROM (VALUES (1),(3),(6),(12)) AS v(MonthIndex)
), Eligible AS (
    SELECT s.CohortMonth, s.CohortSize, h.MonthIndex
    FROM CohortSizes AS s CROSS JOIN Horizons AS h
    WHERE DATEADD(month, h.MonthIndex, s.CohortMonth)
          <= DATEFROMPARTS(YEAR(@DatasetEnd), MONTH(@DatasetEnd), 1)
)
SELECT e.MonthIndex,
       COUNT_BIG(*) AS EligibleCohortCount,
       MIN(e.CohortMonth) AS EarliestEligibleCohort,
       MAX(e.CohortMonth) AS LatestEligibleCohort,
       SUM(e.CohortSize) AS EligibleCohortCustomers,
       SUM(COALESCE(a.ActiveCustomers, CONVERT(bigint, 0))) AS ActiveCustomers,
       CAST(100.0 * SUM(COALESCE(a.ActiveCustomers, CONVERT(bigint, 0)))
            / NULLIF(SUM(e.CohortSize), 0) AS decimal(8, 3)) AS WeightedRetentionPercent
FROM Eligible AS e LEFT JOIN ActiveCounts AS a
  ON a.CohortMonth = e.CohortMonth AND a.MonthIndex = e.MonthIndex
GROUP BY e.MonthIndex ORDER BY e.MonthIndex;
