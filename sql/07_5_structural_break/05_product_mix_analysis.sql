/* Detail grain. The composite offer/product relationship is preserved before
joining product hierarchy. Customer counts are DISTINCT because customers can
place many orders and buy many lines/products. */
WITH LineMix AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        COALESCE(pc.Name,'Uncategorized') AS ProductCategory,COALESCE(ps.Name,'Uncategorized') AS Subcategory,
        d.SalesOrderID,h.CustomerID,d.ProductID,d.OrderQty
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
)
SELECT Period,ProductCategory,COUNT_BIG(*) AS OrderLines,SUM(OrderQty) AS Units,
       COUNT(DISTINCT CustomerID) AS PurchasingCustomers,COUNT(DISTINCT SalesOrderID) AS Orders,
       CAST(100.0*COUNT_BIG(*)/SUM(COUNT_BIG(*)) OVER(PARTITION BY Period) AS decimal(7,3)) AS LineShare,
       CAST(100.0*SUM(OrderQty)/SUM(SUM(OrderQty)) OVER(PARTITION BY Period) AS decimal(7,3)) AS UnitShare
FROM LineMix GROUP BY Period,ProductCategory ORDER BY Period,OrderLines DESC;

-- Subcategory-level product mix to identify concentrated changes.
WITH LineMix AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        COALESCE(pc.Name,'Uncategorized') AS ProductCategory,COALESCE(ps.Name,'Uncategorized') AS Subcategory,
        d.SalesOrderID,h.CustomerID,d.ProductID,d.OrderQty
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
)
SELECT Period,ProductCategory,Subcategory,COUNT_BIG(*) AS OrderLines,SUM(OrderQty) AS Units,
       COUNT(DISTINCT CustomerID) AS PurchasingCustomers,COUNT(DISTINCT ProductID) AS Products
FROM LineMix GROUP BY Period,ProductCategory,Subcategory
ORDER BY ProductCategory,Subcategory,Period;

-- New customer first-order category mix; cohort attribution at customer grain.
WITH FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), FirstOrderLines AS (
 SELECT f.CustomerID,f.FirstOrderDate,COALESCE(pc.Name,'Uncategorized') AS ProductCategory,
        d.SalesOrderID,d.SalesOrderDetailID
 FROM FirstOrder f JOIN Sales.SalesOrderHeader h ON h.CustomerID=f.CustomerID AND h.OrderDate=f.FirstOrderDate
 JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
 WHERE f.FirstOrderDate>='20130101' AND f.FirstOrderDate<'20140101'
)
SELECT CASE WHEN FirstOrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
       ProductCategory,COUNT(DISTINCT CustomerID) AS NewCustomers,COUNT_BIG(*) AS FirstOrderLines
FROM FirstOrderLines GROUP BY CASE WHEN FirstOrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,ProductCategory
ORDER BY Period,NewCustomers DESC;
