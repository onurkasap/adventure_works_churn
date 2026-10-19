/* Product/category and order behavior, using only cutoff-period detail rows.
   Category is assigned through the validated composite offer/product join. */
WITH S AS (
 SELECT * FROM (VALUES ('A_2012',CONVERT(date,'20120630')),('B_2013',CONVERT(date,'20130630'))) v(SnapshotID,SnapshotDate)
), O AS (
 SELECT s.SnapshotID,s.SnapshotDate,h.CustomerID,h.SalesOrderID,h.OnlineOrderFlag
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
), D AS (
 SELECT o.SnapshotID,o.SnapshotDate,o.CustomerID,o.SalesOrderID,d.SalesOrderDetailID,d.ProductID,d.OrderQty,d.UnitPriceDiscount,
 COALESCE(pc.Name,'Uncategorized') Category
 FROM O o JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=o.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
), Cat AS (
 SELECT SnapshotID,CustomerID,COUNT(DISTINCT ProductID) DistinctProducts,COUNT(DISTINCT Category) DistinctCategories,
 SUM(CASE WHEN Category='Bikes' THEN 1 ELSE 0 END) BikesLines,SUM(CASE WHEN Category='Accessories' THEN 1 ELSE 0 END) AccessoriesLines,
 SUM(CASE WHEN Category='Clothing' THEN 1 ELSE 0 END) ClothingLines,SUM(CASE WHEN Category='Components' THEN 1 ELSE 0 END) ComponentsLines,
 COUNT_BIG(*) TotalLines,SUM(OrderQty) TotalQuantity,
 SUM(CASE WHEN Category='Bikes' THEN OrderQty ELSE 0 END) BikesQty,
 SUM(CASE WHEN Category='Accessories' THEN OrderQty ELSE 0 END) AccessoriesQty,
 SUM(CASE WHEN Category='Clothing' THEN OrderQty ELSE 0 END) ClothingQty,
 SUM(CASE WHEN Category='Components' THEN OrderQty ELSE 0 END) ComponentsQty,
 COUNT(DISTINCT SalesOrderID) DetailOrders,
 SUM(CASE WHEN UnitPriceDiscount>0 THEN 1 ELSE 0 END) DiscountedLines
 FROM D GROUP BY SnapshotID,CustomerID
), Dom AS (
 SELECT SnapshotID,CustomerID,Category,ROW_NUMBER() OVER(PARTITION BY SnapshotID,CustomerID ORDER BY COUNT_BIG(*) DESC,Category) rn
 FROM D GROUP BY SnapshotID,CustomerID,Category
), OL AS (
 SELECT SnapshotID,CustomerID,SalesOrderID,COUNT_BIG(*) LinesPerOrder,SUM(OrderQty) QtyPerOrder,COUNT(DISTINCT ProductID) ProductsPerOrder
 FROM D GROUP BY SnapshotID,CustomerID,SalesOrderID
), OA AS (
 SELECT SnapshotID,CustomerID,AVG(CONVERT(float,LinesPerOrder)) MeanLinesPerOrder,
 AVG(CONVERT(float,QtyPerOrder)) MeanQuantityPerOrder,AVG(CONVERT(float,ProductsPerOrder)) MeanDistinctProductsPerOrder
 FROM OL GROUP BY SnapshotID,CustomerID
)
SELECT c.SnapshotID,c.CustomerID,c.DistinctProducts,c.DistinctCategories,d.Category DominantCategory,
 c.TotalLines,c.TotalQuantity,oa.MeanLinesPerOrder,oa.MeanQuantityPerOrder,oa.MeanDistinctProductsPerOrder,
 1.0*c.DiscountedLines/NULLIF(c.TotalLines,0) DiscountedLineShare,
 1.0*c.BikesLines/NULLIF(c.TotalLines,0) BikesLineShare,1.0*c.AccessoriesLines/NULLIF(c.TotalLines,0) AccessoriesLineShare,
 1.0*c.ClothingLines/NULLIF(c.TotalLines,0) ClothingLineShare,1.0*c.ComponentsLines/NULLIF(c.TotalLines,0) ComponentsLineShare,
 1.0*c.BikesQty/NULLIF(c.TotalQuantity,0) BikesQuantityShare,1.0*c.AccessoriesQty/NULLIF(c.TotalQuantity,0) AccessoriesQuantityShare,
 1.0*c.ClothingQty/NULLIF(c.TotalQuantity,0) ClothingQuantityShare,1.0*c.ComponentsQty/NULLIF(c.TotalQuantity,0) ComponentsQuantityShare
FROM Cat c JOIN OA oa ON oa.SnapshotID=c.SnapshotID AND oa.CustomerID=c.CustomerID
LEFT JOIN Dom d ON d.SnapshotID=c.SnapshotID AND d.CustomerID=c.CustomerID AND d.rn=1
ORDER BY c.SnapshotID,c.CustomerID;
