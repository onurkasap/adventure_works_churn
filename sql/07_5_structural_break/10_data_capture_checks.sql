/* Read-only checks for abrupt field/category/date/identifier coverage changes. */
-- Monthly order-header population, IDs, null coverage, status and channel mix.
SELECT DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1) AS OrderMonth,
       COUNT_BIG(*) AS Orders,MIN(SalesOrderID) AS MinSalesOrderID,MAX(SalesOrderID) AS MaxSalesOrderID,
       MIN(CustomerID) AS MinCustomerID,MAX(CustomerID) AS MaxCustomerID,
       SUM(CASE WHEN CurrencyRateID IS NULL THEN 1 ELSE 0 END) AS NullCurrencyRateID,
       SUM(CASE WHEN SalesPersonID IS NULL THEN 1 ELSE 0 END) AS NullSalesPersonID,
       SUM(CASE WHEN PurchaseOrderNumber IS NULL THEN 1 ELSE 0 END) AS NullPurchaseOrderNumber,
       SUM(CASE WHEN OnlineOrderFlag=1 THEN 1 ELSE 0 END) AS OnlineOrders,
       SUM(CASE WHEN Status<>5 THEN 1 ELSE 0 END) AS NonStatus5Orders
FROM Sales.SalesOrderHeader WHERE OrderDate>='20130101' AND OrderDate<'20140101'
GROUP BY DATEFROMPARTS(YEAR(OrderDate),MONTH(OrderDate),1) ORDER BY OrderMonth;

-- Monthly territory first appearance and order-header territory distribution.
SELECT h.TerritoryID,MIN(h.OrderDate) AS FirstOrderDate,MAX(h.OrderDate) AS LastOrderDate,
       COUNT_BIG(*) AS Orders,COUNT(DISTINCT h.CustomerID) AS Customers
FROM Sales.SalesOrderHeader h GROUP BY h.TerritoryID ORDER BY FirstOrderDate;

-- Customer ID ranges and person/store nullable-link proportions by first-order cohort.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID)
SELECT CASE WHEN f.FirstOrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END AS FirstOrderPeriod,
       MIN(c.CustomerID) AS MinCustomerID,MAX(c.CustomerID) AS MaxCustomerID,COUNT_BIG(*) AS Purchasers,
       SUM(CASE WHEN c.PersonID IS NULL THEN 1 ELSE 0 END) AS PersonIDNull,
       SUM(CASE WHEN c.StoreID IS NULL THEN 1 ELSE 0 END) AS StoreIDNull
FROM FirstOrder f JOIN Sales.Customer c ON c.CustomerID=f.CustomerID
GROUP BY CASE WHEN f.FirstOrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END;

-- Order detail monthly grain, quantities, discounts, and offer identifiers.
SELECT DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1) AS OrderMonth,
       COUNT_BIG(*) AS OrderLines,SUM(d.OrderQty) AS Units,
       SUM(CASE WHEN d.UnitPriceDiscount>0 THEN 1 ELSE 0 END) AS DiscountedLines,
       COUNT(DISTINCT d.SpecialOfferID) AS OffersUsed,COUNT(DISTINCT d.ProductID) AS ProductsSold
FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
GROUP BY DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1) ORDER BY OrderMonth;
