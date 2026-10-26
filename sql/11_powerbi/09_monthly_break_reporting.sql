/* Month-grain descriptive dataset (one row per observed month). Counts use
   header grain; basket/category measures use order-line grain and are joined
   only after being aggregated to month. No monetary values are selected. */
WITH Orders AS (
 SELECT SalesOrderID,CustomerID,CONVERT(date,OrderDate) OrderDate,OnlineOrderFlag
 FROM Sales.SalesOrderHeader WHERE OrderDate>='20110531' AND OrderDate<'20140701'
), FirstOrder AS (SELECT CustomerID,MIN(OrderDate) FirstOrderDate FROM Orders GROUP BY CustomerID),
 MonthlyOrders AS (
 SELECT DATEFROMPARTS(YEAR(o.OrderDate),MONTH(o.OrderDate),1) MonthStart,
 COUNT_BIG(*) Orders,COUNT(DISTINCT o.CustomerID) MonthlyActiveCustomers,
 COUNT(DISTINCT CASE WHEN f.FirstOrderDate=o.OrderDate THEN o.CustomerID END) FirstObservedPurchasers,
 SUM(CASE WHEN o.OnlineOrderFlag=1 THEN CONVERT(bigint,1) ELSE 0 END) OnlineFlagOrders,
 SUM(CASE WHEN o.OnlineOrderFlag=0 THEN CONVERT(bigint,1) ELSE 0 END) OfflineFlagOrders
 FROM Orders o JOIN FirstOrder f ON f.CustomerID=o.CustomerID
 GROUP BY DATEFROMPARTS(YEAR(o.OrderDate),MONTH(o.OrderDate),1)
), LineBase AS (
 SELECT DATEFROMPARTS(YEAR(o.OrderDate),MONTH(o.OrderDate),1) MonthStart,o.SalesOrderID,
 COALESCE(pc.Name,'Uncategorized') ProductCategory,COUNT_BIG(*) Lines
 FROM Orders o JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=o.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
 GROUP BY DATEFROMPARTS(YEAR(o.OrderDate),MONTH(o.OrderDate),1),o.SalesOrderID,COALESCE(pc.Name,'Uncategorized')
), Basket AS (
 SELECT MonthStart,SUM(Lines) OrderLines,COUNT(DISTINCT SalesOrderID) LineOrders,
 SUM(CASE WHEN ProductCategory='Bikes' THEN Lines ELSE 0 END) BikeLines,
 SUM(CASE WHEN ProductCategory='Accessories' THEN Lines ELSE 0 END) AccessoryLines,
 SUM(CASE WHEN ProductCategory='Clothing' THEN Lines ELSE 0 END) ClothingLines,
 SUM(CASE WHEN ProductCategory='Components' THEN Lines ELSE 0 END) ComponentLines
 FROM LineBase GROUP BY MonthStart
)
SELECT m.MonthStart,m.Orders,m.MonthlyActiveCustomers,m.FirstObservedPurchasers,
 m.OnlineFlagOrders,m.OfflineFlagOrders,
 CAST(m.OnlineFlagOrders*1.0/NULLIF(m.Orders,0) AS decimal(9,6)) OnlineFlagOrderShare,
 b.OrderLines,CAST(b.OrderLines*1.0/NULLIF(b.LineOrders,0) AS decimal(9,4)) AverageLinesPerOrder,
 CAST(b.BikeLines*1.0/NULLIF(b.OrderLines,0) AS decimal(9,6)) BikeLineShare,
 CAST(b.AccessoryLines*1.0/NULLIF(b.OrderLines,0) AS decimal(9,6)) AccessoryLineShare,
 CAST(b.ClothingLines*1.0/NULLIF(b.OrderLines,0) AS decimal(9,6)) ClothingLineShare,
 CAST(b.ComponentLines*1.0/NULLIF(b.OrderLines,0) AS decimal(9,6)) ComponentLineShare,
 CASE WHEN m.MonthStart<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END PeriodLabel
FROM MonthlyOrders m LEFT JOIN Basket b ON b.MonthStart=m.MonthStart;

/* Matched Jan-Jun vs Jul-Dec 2013 summary. Equal six-month windows; no causal
   interpretation is implied. Customer counts across flag values may overlap. */
WITH M AS (
 SELECT CASE WHEN OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END Period,
 COUNT_BIG(*) Orders,COUNT(DISTINCT CustomerID) ActiveCustomers,
 COUNT(DISTINCT CASE WHEN OnlineOrderFlag=1 THEN CustomerID END) CustomersWithOnlineFlagOrder,
 SUM(CASE WHEN OnlineOrderFlag=1 THEN 1 ELSE 0 END) OnlineFlagOrders
 FROM Sales.SalesOrderHeader WHERE OrderDate>='20130101' AND OrderDate<'20140101'
 GROUP BY CASE WHEN OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END
)
SELECT *,OnlineFlagOrders*1.0/NULLIF(Orders,0) OnlineFlagOrderShare FROM M;

/* Monthly customer structure. These are current PersonID/StoreID links,
   attributed to observed orders, not historically effective-dated labels. */
WITH C AS (
 SELECT CustomerID,CASE WHEN PersonID IS NOT NULL AND StoreID IS NOT NULL THEN 'Both Person and Store'
 WHEN PersonID IS NOT NULL THEN 'Person only' WHEN StoreID IS NOT NULL THEN 'Store only'
 ELSE 'Neither / unknown' END CustomerStructure FROM Sales.Customer
), F AS (SELECT CustomerID,MIN(OrderDate) FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID)
SELECT DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1) MonthStart,c.CustomerStructure,
 COUNT_BIG(*) Orders,COUNT(DISTINCT h.CustomerID) MonthlyActiveCustomers,
 COUNT(DISTINCT CASE WHEN f.FirstOrderDate=h.OrderDate THEN h.CustomerID END) FirstObservedPurchasers
FROM Sales.SalesOrderHeader h JOIN C c ON c.CustomerID=h.CustomerID JOIN F f ON f.CustomerID=h.CustomerID
WHERE h.OrderDate>='20110531' AND h.OrderDate<'20140701'
GROUP BY DATEFROMPARTS(YEAR(h.OrderDate),MONTH(h.OrderDate),1),c.CustomerStructure;
