/* Pre-cutoff product/category descriptive cross-check. Shares use lines as
   denominator; customers can have lines in several categories. */
WITH S AS (
 SELECT * FROM (VALUES
 ('A_2012',CONVERT(date,'20120630'),CONVERT(date,'20120701'),CONVERT(date,'20130630')),
 ('B_2013',CONVERT(date,'20130630'),CONVERT(date,'20130701'),CONVERT(date,'20140630'))
 )v(SnapshotID,Cutoff,OutcomeStart,OutcomeEnd)
), O AS (
 SELECT s.SnapshotID,s.Cutoff,h.CustomerID,h.SalesOrderID
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.Cutoff)
), D AS (
 SELECT o.SnapshotID,o.Cutoff,o.CustomerID,d.ProductID,d.OrderQty,d.UnitPriceDiscount,
 COALESCE(pc.Name,'Uncategorized') Category
 FROM O o JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=o.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
), C AS (
 SELECT SnapshotID,Cutoff,CustomerID,COUNT_BIG(*) TotalLines,COUNT(DISTINCT ProductID) DistinctProductCount,
 COUNT(DISTINCT Category) DistinctCategoryCount,
 1.0*SUM(CASE WHEN Category='Bikes' THEN 1 ELSE 0 END)/COUNT_BIG(*) BikesShare,
 1.0*SUM(CASE WHEN Category='Accessories' THEN 1 ELSE 0 END)/COUNT_BIG(*) AccessoriesShare,
  1.0*SUM(CASE WHEN Category='Clothing' THEN 1 ELSE 0 END)/COUNT_BIG(*) ClothingShare,
  1.0*SUM(CASE WHEN Category='Components' THEN 1 ELSE 0 END)/COUNT_BIG(*) ComponentsShare,
  1.0*SUM(CASE WHEN UnitPriceDiscount>0 THEN 1 ELSE 0 END)/COUNT_BIG(*) DiscountedLineShare
 FROM D GROUP BY SnapshotID,Cutoff,CustomerID
), Y AS (
 SELECT s.SnapshotID,c.CustomerID,CONVERT(int,CASE WHEN EXISTS(
 SELECT 1 FROM Sales.SalesOrderHeader x WHERE x.CustomerID=c.CustomerID AND x.OrderDate>=s.OutcomeStart AND x.OrderDate<DATEADD(day,1,s.OutcomeEnd)
 ) THEN 0 ELSE 1 END) AnalyticalChurn FROM S s JOIN C c ON c.SnapshotID=s.SnapshotID
)
SELECT c.SnapshotID,y.AnalyticalChurn,COUNT_BIG(*) Customers,
 AVG(CONVERT(float,c.DistinctProductCount)) MeanDistinctProducts,
 AVG(CONVERT(float,c.DistinctCategoryCount)) MeanDistinctCategories,
 AVG(c.BikesShare) MeanBikesShare,AVG(c.AccessoriesShare) MeanAccessoriesShare,
 AVG(c.ClothingShare) MeanClothingShare,AVG(c.ComponentsShare) MeanComponentsShare,
 AVG(c.DiscountedLineShare) MeanDiscountedLineShare
FROM C c JOIN Y y ON y.SnapshotID=c.SnapshotID AND y.CustomerID=c.CustomerID
GROUP BY c.SnapshotID,y.AnalyticalChurn ORDER BY c.SnapshotID,y.AnalyticalChurn;
