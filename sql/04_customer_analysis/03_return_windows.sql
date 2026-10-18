/*
Observed repeat purchase within fixed windows after first observed purchase.
Eligibility requires FirstOrderDate <= 2014-06-30 minus the full window, so
every eligible customer has the complete requested follow-up time. A return
is a distinct later order dated after the first order and on/before the window
end. This is observed return behavior, not a churn label or a causal measure.
*/

DECLARE @DatasetEnd date = '20140630';

WITH CustomerFirstOrder AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate
    FROM Sales.SalesOrderHeader
    GROUP BY CustomerID
),
Windows AS (
    SELECT window_days
    FROM (VALUES (30), (60), (90), (180), (365)) AS v(window_days)
),
Eligibility AS (
    SELECT
        f.CustomerID,
        f.FirstOrderDate,
        w.window_days,
        DATEADD(day, w.window_days, f.FirstOrderDate) AS FollowUpEndDate
    FROM CustomerFirstOrder AS f
    CROSS JOIN Windows AS w
    WHERE CONVERT(date, f.FirstOrderDate)
        <= DATEADD(day, -w.window_days, @DatasetEnd)
),
EligibilityWithReturn AS (
    SELECT
        e.CustomerID,
        e.window_days,
        CASE WHEN EXISTS (
            SELECT 1
            FROM Sales.SalesOrderHeader AS later_order
            WHERE later_order.CustomerID = e.CustomerID
              AND later_order.OrderDate > e.FirstOrderDate
              AND later_order.OrderDate <= e.FollowUpEndDate
        ) THEN 1 ELSE 0 END AS ReturnedWithinWindow
    FROM Eligibility AS e
)
SELECT
    window_days AS FollowUpWindowDays,
    COUNT_BIG(*) AS EligibleCustomers,
    SUM(ReturnedWithinWindow) AS CustomersWhoReturned,
    CAST(100.0 * SUM(ReturnedWithinWindow) / NULLIF(COUNT_BIG(*), 0) AS decimal(7, 3))
        AS ReturnRatePercent
FROM EligibilityWithReturn
GROUP BY window_days
ORDER BY window_days;
