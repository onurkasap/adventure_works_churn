/* Break timing at order-header/customer grain; first-observed means extract start. */
DECLARE @Start date='20130101', @End date='20131231', @ExtractStart date='20110531';
WITH FirstOrder AS (
 SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), Monthly AS (
 SELECT DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1) AS OrderMonth,
        COUNT_BIG(*) AS Orders, COUNT(DISTINCT h.CustomerID) AS PurchasingCustomers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate >= @Start AND f.FirstOrderDate < DATEADD(day,1,@End)
                                  AND DATEFROMPARTS(YEAR(f.FirstOrderDate),MONTH(f.FirstOrderDate),1)=DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1)
                            THEN h.CustomerID END) AS FirstObservedPurchasers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate < DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1)
                            THEN h.CustomerID END) AS RepeatPurchasersActive
 FROM Sales.SalesOrderHeader h JOIN FirstOrder f ON f.CustomerID=h.CustomerID
 WHERE h.OrderDate >= @Start AND h.OrderDate < DATEADD(day,1,@End)
 GROUP BY DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1)
)
SELECT OrderMonth, Orders, PurchasingCustomers, FirstObservedPurchasers, RepeatPurchasersActive,
       CAST(1.0*Orders/NULLIF(PurchasingCustomers,0) AS decimal(8,3)) AS OrdersPerActiveCustomer
FROM Monthly ORDER BY OrderMonth;

-- Equal six-month windows around the break; counts and per-month rates together.
WITH FirstOrder AS (
 SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), PeriodOrders AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        COUNT_BIG(*) AS Orders, COUNT(DISTINCT h.CustomerID) AS ActiveCustomerMonths,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate>=CASE WHEN h.OrderDate<'20130701' THEN '20130101' ELSE '20130701' END
                              AND f.FirstOrderDate<CASE WHEN h.OrderDate<'20130701' THEN '20130701' ELSE '20140101' END
                         THEN h.CustomerID END) AS NewPurchasers
 FROM Sales.SalesOrderHeader h JOIN FirstOrder f ON f.CustomerID=h.CustomerID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
 GROUP BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END
)
SELECT Period, Orders, ActiveCustomerMonths, NewPurchasers,
       CAST(Orders/6.0 AS decimal(10,2)) AS OrdersPerMonth,
       CAST(ActiveCustomerMonths/6.0 AS decimal(10,2)) AS CustomerMonthsPerMonth
FROM PeriodOrders ORDER BY Period;

-- Weekly order counts around May-August 2013. Week starts Monday (date arithmetic).
SELECT DATEADD(day,-(DATEDIFF(day,'19000101',CONVERT(date,OrderDate))%7),CONVERT(date,OrderDate)) AS WeekStartMonday,
       COUNT_BIG(*) AS Orders, COUNT(DISTINCT CustomerID) AS PurchasingCustomers
FROM Sales.SalesOrderHeader
WHERE OrderDate>='20130501' AND OrderDate<'20130901'
GROUP BY DATEADD(day,-(DATEDIFF(day,'19000101',CONVERT(date,OrderDate))%7),CONVERT(date,OrderDate))
ORDER BY WeekStartMonday;

-- First-observed acquisitions by week in the same window.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID)
SELECT DATEADD(day,-(DATEDIFF(day,'19000101',CONVERT(date,FirstOrderDate))%7),CONVERT(date,FirstOrderDate)) AS WeekStartMonday,
       COUNT_BIG(*) AS FirstObservedPurchasers
FROM FirstOrder WHERE FirstOrderDate>='20130501' AND FirstOrderDate<'20130901'
GROUP BY DATEADD(day,-(DATEDIFF(day,'19000101',CONVERT(date,FirstOrderDate))%7),CONVERT(date,FirstOrderDate))
ORDER BY WeekStartMonday;

-- Validate first-observed cohorts.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID)
SELECT DATEFROMPARTS(YEAR(FirstOrderDate),MONTH(FirstOrderDate),1) AS CohortMonth,COUNT_BIG(*) AS NewCustomers
FROM FirstOrder WHERE FirstOrderDate>='20130601' AND FirstOrderDate<'20130801'
GROUP BY DATEFROMPARTS(YEAR(FirstOrderDate),MONTH(FirstOrderDate),1) ORDER BY CohortMonth;

-- Whole-extract reconciliation to the previously validated phase totals.
SELECT COUNT_BIG(*) AS OrderHeaders,COUNT(DISTINCT CustomerID) AS PurchasingCustomers,
       MIN(OrderDate) AS FirstObservedOrderDate,MAX(OrderDate) AS LastObservedOrderDate
FROM Sales.SalesOrderHeader;
