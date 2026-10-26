/* Read-only validation result sets for the Phase 11 import. */
-- Baseline: registered, purchasers, orders, and lines at their native grains.
SELECT (SELECT COUNT_BIG(*) FROM Sales.Customer) RegisteredCustomers,
 (SELECT COUNT_BIG(DISTINCT CustomerID) FROM Sales.SalesOrderHeader WHERE OrderDate>='20110531' AND OrderDate<'20140701') PurchasingCustomers,
 (SELECT COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE OrderDate>='20110531' AND OrderDate<'20140701') Orders,
 (SELECT COUNT_BIG(*) FROM Sales.SalesOrderDetail) OrderLines;

-- Customer frequency classes reproduce Phase 3.
WITH F AS (SELECT CustomerID,COUNT_BIG(*) Frequency FROM Sales.SalesOrderHeader
 WHERE OrderDate>='20110531' AND OrderDate<'20140701' GROUP BY CustomerID)
SELECT COUNT_BIG(*) PurchasingCustomers,
 SUM(CASE WHEN Frequency=1 THEN 1 ELSE 0 END) OneTimePurchasers,
 SUM(CASE WHEN Frequency>1 THEN 1 ELSE 0 END) RepeatPurchasers,
 SUM(Frequency) OrdersReconciled FROM F;

-- Detail key/grain and order coverage. No order count is inferred by summing lines.
SELECT COUNT_BIG(*) DetailRows,COUNT_BIG(DISTINCT SalesOrderDetailID) UniqueLineIDs,
 COUNT_BIG(DISTINCT SalesOrderID) OrdersWithLines FROM Sales.SalesOrderDetail;

-- RF: one row per purchaser by construction; compare counts to 19,119 and 6 segments.
DECLARE @End date='20140630';
WITH F AS (SELECT CustomerID,MIN(OrderDate) FirstOrderDate,MAX(OrderDate) LastOrderDate,COUNT_BIG(*) Frequency
 FROM Sales.SalesOrderHeader WHERE OrderDate<DATEADD(day,1,@End) GROUP BY CustomerID),
 R AS (SELECT *,DATEDIFF(day,CONVERT(date,LastOrderDate),@End) RecencyDays FROM F),
 C AS (SELECT DISTINCT PERCENTILE_CONT(.2) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P20,
 PERCENTILE_CONT(.4) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P40,
 PERCENTILE_CONT(.6) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P60,
 PERCENTILE_CONT(.8) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER() P80 FROM R),
 S AS (SELECT r.CustomerID,CASE WHEN RecencyDays<=P20 THEN 5 WHEN RecencyDays<=P40 THEN 4
 WHEN RecencyDays<=P60 THEN 3 WHEN RecencyDays<=P80 THEN 2 ELSE 1 END RScore,
 CASE WHEN Frequency=1 THEN 1 WHEN Frequency=2 THEN 2 WHEN Frequency=3 THEN 3 WHEN Frequency<=5 THEN 4 ELSE 5 END FScore
 FROM R r CROSS JOIN C), L AS (SELECT CustomerID,CASE WHEN RScore>=4 AND FScore>=4 THEN 'Highly engaged repeat buyers'
 WHEN RScore<=3 AND FScore>=4 THEN 'Repeat buyers, longer since purchase'
 WHEN RScore>=4 AND FScore BETWEEN 2 AND 3 THEN 'Recent developing repeat buyers'
 WHEN RScore<=3 AND FScore BETWEEN 2 AND 3 THEN 'Developing repeat buyers, longer gap'
 WHEN RScore>=4 AND FScore=1 THEN 'Recent one-time buyers' ELSE 'One-time buyers, longer since purchase' END Segment FROM S)
SELECT Segment,COUNT_BIG(*) Customers FROM L GROUP BY Segment;

-- Cohort population and critical weighted exact-month retention check.
WITH F AS (SELECT CustomerID,MIN(OrderDate) FirstDate FROM Sales.SalesOrderHeader
 WHERE OrderDate<'20140701' GROUP BY CustomerID), C AS (
 SELECT CustomerID,DATEFROMPARTS(YEAR(FirstDate),MONTH(FirstDate),1) CohortMonth FROM F),
 M AS (SELECT DISTINCT CustomerID,DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1) ActiveMonth
 FROM Sales.SalesOrderHeader WHERE OrderDate<'20140701'),
 A AS (SELECT c.CohortMonth,DATEDIFF(month,c.CohortMonth,m.ActiveMonth) MonthIndex,
 COUNT_BIG(*) ActiveCustomers FROM C c JOIN M m ON m.CustomerID=c.CustomerID
 GROUP BY c.CohortMonth,DATEDIFF(month,c.CohortMonth,m.ActiveMonth)),
 Z AS (SELECT CohortMonth,COUNT_BIG(*) CohortSize FROM C GROUP BY CohortMonth),
 I AS (SELECT MonthIndex FROM (VALUES(1),(3),(6),(12)) v(MonthIndex)),
 E AS (SELECT z.CohortMonth,z.CohortSize,i.MonthIndex,
 DATEADD(month,i.MonthIndex,z.CohortMonth) TargetMonth
 FROM Z z CROSS JOIN I i
 WHERE DATEADD(month,i.MonthIndex,z.CohortMonth)<='20140601')
SELECT e.MonthIndex,SUM(COALESCE(a.ActiveCustomers,0))*1.0/SUM(e.CohortSize) WeightedExactMonthRetention
FROM E e LEFT JOIN A a ON a.CohortMonth=e.CohortMonth AND a.MonthIndex=e.MonthIndex
GROUP BY e.MonthIndex ORDER BY e.MonthIndex;

-- Snapshot labels and overlap (intersection only; counts remain separate).
WITH A AS (SELECT DISTINCT CustomerID FROM Sales.SalesOrderHeader WHERE OrderDate<'20120701'),
B AS (SELECT DISTINCT CustomerID FROM Sales.SalesOrderHeader WHERE OrderDate<'20130701')
SELECT (SELECT COUNT_BIG(*) FROM A) CustomersInA,
 (SELECT COUNT_BIG(*) FROM B) CustomersInB,
 (SELECT COUNT_BIG(*) FROM A JOIN B ON B.CustomerID=A.CustomerID) CustomerOverlap;
