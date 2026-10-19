/* Equal six-month 2013 windows. Header-level and detail-level measures are
explicitly aggregated separately before joining. */
WITH HeaderStats AS (
 SELECT CASE WHEN OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        SalesOrderID,CustomerID,COUNT_BIG(*) AS HeaderRow
 FROM Sales.SalesOrderHeader WHERE OrderDate>='20130101' AND OrderDate<'20140101'
 GROUP BY CASE WHEN OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,SalesOrderID,CustomerID
), LineStats AS (
 SELECT h.SalesOrderID,COUNT_BIG(*) AS OrderLines,SUM(d.OrderQty) AS TotalQuantity,COUNT(DISTINCT d.ProductID) AS UniqueProducts
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101' GROUP BY h.SalesOrderID
), OrderBehavior AS (
 SELECT hs.Period,hs.SalesOrderID,hs.CustomerID,ls.OrderLines,ls.TotalQuantity,ls.UniqueProducts
 FROM HeaderStats hs JOIN LineStats ls ON ls.SalesOrderID=hs.SalesOrderID
), PeriodCustomers AS (
 SELECT Period,COUNT(DISTINCT CustomerID) AS Customers FROM OrderBehavior GROUP BY Period
), PeriodStats AS (
 SELECT DISTINCT Period,COUNT_BIG(*) OVER(PARTITION BY Period) AS Orders,
       AVG(CONVERT(float,OrderLines)) OVER(PARTITION BY Period) AS MeanLinesPerOrder,
       PERCENTILE_CONT(.50) WITHIN GROUP(ORDER BY CONVERT(float,OrderLines)) OVER(PARTITION BY Period) AS MedianLinesPerOrder,
       AVG(CONVERT(float,TotalQuantity)) OVER(PARTITION BY Period) AS MeanUnitsPerOrder,
       PERCENTILE_CONT(.50) WITHIN GROUP(ORDER BY CONVERT(float,TotalQuantity)) OVER(PARTITION BY Period) AS MedianUnitsPerOrder,
       AVG(CONVERT(float,UniqueProducts)) OVER(PARTITION BY Period) AS MeanUniqueProductsPerOrder
 FROM OrderBehavior
)
SELECT s.*,p.Customers FROM PeriodStats s JOIN PeriodCustomers p ON p.Period=s.Period ORDER BY s.Period;

-- Orders per active customer, repeat share, same-day multi-order customers.
;WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID),
PerCustomer AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        h.CustomerID,COUNT_BIG(*) AS Orders,
        MAX(CASE WHEN f.FirstOrderDate<h.OrderDate THEN 1 ELSE 0 END) AS HadPriorOrderInExtract,
        COUNT(DISTINCT CONVERT(date,h.OrderDate)) AS ActiveOrderDates
 FROM Sales.SalesOrderHeader h JOIN FirstOrder f ON f.CustomerID=h.CustomerID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
 GROUP BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,h.CustomerID
)
SELECT Period,COUNT_BIG(*) AS ActiveCustomers,SUM(Orders) AS Orders,
       AVG(CONVERT(float,Orders)) AS MeanOrdersPerActiveCustomer,
       SUM(HadPriorOrderInExtract) AS CustomersWithPriorOrder,
       SUM(CASE WHEN ActiveOrderDates<Orders THEN 1 ELSE 0 END) AS CustomersWithSameDayMultipleOrders
FROM PerCustomer GROUP BY Period ORDER BY Period;

-- Completed repeat-gap distribution by the date of the later order.
;WITH Ordered AS (
 SELECT CustomerID,OrderDate,LAG(OrderDate) OVER(PARTITION BY CustomerID ORDER BY OrderDate,SalesOrderID) AS PreviousOrderDate
 FROM Sales.SalesOrderHeader
), Gaps AS (
 SELECT CASE WHEN OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        DATEDIFF(day,CONVERT(date,PreviousOrderDate),CONVERT(date,OrderDate)) AS GapDays
 FROM Ordered WHERE PreviousOrderDate IS NOT NULL AND OrderDate>='20130101' AND OrderDate<'20140101'
)
SELECT DISTINCT Period,COUNT_BIG(*) OVER(PARTITION BY Period) AS CompletedIntervals,
 PERCENTILE_CONT(.50) WITHIN GROUP(ORDER BY CONVERT(float,GapDays)) OVER(PARTITION BY Period) AS MedianGapDays,
 PERCENTILE_CONT(.75) WITHIN GROUP(ORDER BY CONVERT(float,GapDays)) OVER(PARTITION BY Period) AS P75GapDays,
 AVG(CONVERT(float,GapDays)) OVER(PARTITION BY Period) AS MeanGapDays
FROM Gaps ORDER BY Period;
