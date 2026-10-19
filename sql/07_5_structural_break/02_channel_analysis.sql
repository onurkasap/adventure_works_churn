/* OnlineOrderFlag is an order-level observed channel field. Customer counts by
channel may overlap when a customer orders both online and offline. */
DECLARE @Cut date='20130701';
WITH FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), Period AS (
 SELECT CASE WHEN h.OrderDate<@Cut THEN 'Before July 2013' ELSE 'July 2013 onward' END AS Period,
        h.OnlineOrderFlag, COUNT_BIG(*) AS Orders, COUNT(DISTINCT h.CustomerID) AS Customers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate=h.OrderDate THEN h.CustomerID END) AS FirstObservedCustomers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate<h.OrderDate THEN h.CustomerID END) AS RepeatCustomers
 FROM Sales.SalesOrderHeader h JOIN FirstOrder f ON f.CustomerID=h.CustomerID
 GROUP BY CASE WHEN h.OrderDate<@Cut THEN 'Before July 2013' ELSE 'July 2013 onward' END,h.OnlineOrderFlag
)
SELECT Period,OnlineOrderFlag,Orders,Customers,FirstObservedCustomers,RepeatCustomers,
 CAST(100.0*Orders/SUM(Orders) OVER(PARTITION BY Period) AS decimal(7,3)) AS OrderShareWithinPeriod,
 CAST(100.0*FirstObservedCustomers/NULLIF(SUM(FirstObservedCustomers) OVER(PARTITION BY Period),0) AS decimal(7,3)) AS NewCustomerShareWithinPeriod
FROM Period ORDER BY Period,OnlineOrderFlag;

-- Matched six-month comparison, avoiding unequal full-history period lengths.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID),
Matched AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        h.OnlineOrderFlag,COUNT_BIG(*) AS Orders,COUNT(DISTINCT h.CustomerID) AS Customers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate=h.OrderDate THEN h.CustomerID END) AS NewCustomers
 FROM Sales.SalesOrderHeader h JOIN FirstOrder f ON f.CustomerID=h.CustomerID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
 GROUP BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,h.OnlineOrderFlag
)
SELECT Period,OnlineOrderFlag,Orders,Customers,NewCustomers,
       CAST(100.0*Orders/SUM(Orders) OVER(PARTITION BY Period) AS decimal(7,3)) AS OrderShare,
       CAST(100.0*NewCustomers/SUM(NewCustomers) OVER(PARTITION BY Period) AS decimal(7,3)) AS NewCustomerShare
FROM Matched ORDER BY Period,OnlineOrderFlag;

-- Monthly channel trend Jan-Dec 2013; first-observed customers attributed to their first order channel.
WITH FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
)
SELECT DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1) AS OrderMonth,h.OnlineOrderFlag,
 COUNT_BIG(*) AS Orders,COUNT(DISTINCT h.CustomerID) AS ActiveCustomers,
 COUNT(DISTINCT CASE WHEN f.FirstOrderDate=h.OrderDate THEN h.CustomerID END) AS FirstObservedCustomers
FROM Sales.SalesOrderHeader h JOIN FirstOrder f ON f.CustomerID=h.CustomerID
WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
GROUP BY DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1),h.OnlineOrderFlag
ORDER BY OrderMonth,h.OnlineOrderFlag;

-- Flag coverage/null check, though schema metadata marks OnlineOrderFlag NOT NULL.
SELECT OnlineOrderFlag,COUNT_BIG(*) AS Orders,MIN(OrderDate) AS FirstOrderDate,MAX(OrderDate) AS LastOrderDate
FROM Sales.SalesOrderHeader GROUP BY OnlineOrderFlag ORDER BY OnlineOrderFlag;
