/* Analytical label table at SnapshotID x CustomerID grain. Every feature CTE
   is cutoff-filtered; the separate Outcome CTE alone reads future orders. */
WITH S AS (
 SELECT * FROM (VALUES
 ('A_2012',CONVERT(date,'20120630'),CONVERT(date,'20120701'),CONVERT(date,'20130630')),
 ('B_2013',CONVERT(date,'20130630'),CONVERT(date,'20130701'),CONVERT(date,'20140630'))
 )v(SnapshotID,SnapshotDate,OutcomeStart,OutcomeEnd)
), O AS (
 SELECT s.SnapshotID,s.SnapshotDate,h.CustomerID,h.SalesOrderID,CONVERT(date,h.OrderDate) OrderDate,h.OnlineOrderFlag
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
), L AS (
 SELECT *,LAG(OrderDate) OVER(PARTITION BY SnapshotID,CustomerID ORDER BY OrderDate,SalesOrderID) PriorDate,
 ROW_NUMBER() OVER(PARTITION BY SnapshotID,CustomerID ORDER BY OrderDate,SalesOrderID) rn1,
 ROW_NUMBER() OVER(PARTITION BY SnapshotID,CustomerID ORDER BY OrderDate DESC,SalesOrderID DESC) rnn
 FROM O
), H AS (
 SELECT SnapshotID,SnapshotDate,CustomerID,MIN(OrderDate) FirstOrderDateAsOfCutoff,MAX(OrderDate) LastOrderDateAsOfCutoff,
 COUNT_BIG(*) Frequency,DATEDIFF(day,MIN(OrderDate),MAX(OrderDate)) CustomerLifetimeDays,
 DATEDIFF(day,MAX(OrderDate),SnapshotDate) RecencyDays,DATEDIFF(day,MIN(OrderDate),SnapshotDate) DaysSinceFirstOrder,
 AVG(CASE WHEN PriorDate IS NOT NULL THEN CONVERT(float,DATEDIFF(day,PriorDate,OrderDate)) END) AverageDaysBetweenOrders,
 MAX(CASE WHEN rn1=1 THEN CONVERT(int,OnlineOrderFlag) END) FirstOrderOnlineFlag,
 MAX(CASE WHEN rnn=1 THEN CONVERT(int,OnlineOrderFlag) END) LastOrderOnlineFlag,
 SUM(CASE WHEN OnlineOrderFlag=1 THEN 1 ELSE 0 END) OnlineOrderCount,
 SUM(CASE WHEN OnlineOrderFlag=0 THEN 1 ELSE 0 END) OfflineOrderCount
 FROM L GROUP BY SnapshotID,SnapshotDate,CustomerID
), Med AS (
 SELECT DISTINCT SnapshotID,CustomerID,PERCENTILE_CONT(.5) WITHIN GROUP(ORDER BY CONVERT(float,DATEDIFF(day,PriorDate,OrderDate)))
 OVER(PARTITION BY SnapshotID,CustomerID) MedianDaysBetweenOrders FROM L WHERE PriorDate IS NOT NULL
), D AS (
 SELECT o.SnapshotID,o.SnapshotDate,o.CustomerID,o.SalesOrderID,d.ProductID,d.OrderQty,d.UnitPriceDiscount,
 COALESCE(pc.Name,'Uncategorized') Category
 FROM O o JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=o.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
), DA AS (
 SELECT SnapshotID,CustomerID,COUNT(DISTINCT ProductID) DistinctProducts,COUNT(DISTINCT Category) DistinctCategories,
 COUNT_BIG(*) TotalOrderLines,SUM(OrderQty) TotalQuantity,
 1.0*SUM(CASE WHEN UnitPriceDiscount>0 THEN 1 ELSE 0 END)/COUNT_BIG(*) DiscountedLineShare,
 1.0*SUM(CASE WHEN Category='Bikes' THEN 1 ELSE 0 END)/COUNT_BIG(*) BikesLineShare,
 1.0*SUM(CASE WHEN Category='Accessories' THEN 1 ELSE 0 END)/COUNT_BIG(*) AccessoriesLineShare,
 1.0*SUM(CASE WHEN Category='Clothing' THEN 1 ELSE 0 END)/COUNT_BIG(*) ClothingLineShare,
 1.0*SUM(CASE WHEN Category='Components' THEN 1 ELSE 0 END)/COUNT_BIG(*) ComponentsLineShare
 FROM D GROUP BY SnapshotID,CustomerID
), DC AS (
 SELECT SnapshotID,CustomerID,Category,ROW_NUMBER() OVER(PARTITION BY SnapshotID,CustomerID ORDER BY COUNT_BIG(*) DESC,Category) rn
 FROM D GROUP BY SnapshotID,CustomerID,Category
), OL AS (
 SELECT SnapshotID,CustomerID,SalesOrderID,COUNT_BIG(*) Lines,SUM(OrderQty) Qty,COUNT(DISTINCT ProductID) Products
 FROM D GROUP BY SnapshotID,CustomerID,SalesOrderID
), OA AS (
 SELECT SnapshotID,CustomerID,AVG(CONVERT(float,Lines)) MeanLinesPerOrder,AVG(CONVERT(float,Qty)) MeanQuantityPerOrder,
 AVG(CONVERT(float,Products)) MeanDistinctProductsPerOrder FROM OL GROUP BY SnapshotID,CustomerID
), RF0 AS (
 SELECT SnapshotID,CustomerID,RecencyDays,Frequency FROM H
), RP AS (
 SELECT DISTINCT SnapshotID,
 PERCENTILE_CONT(.2) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P20,
 PERCENTILE_CONT(.4) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P40,
 PERCENTILE_CONT(.6) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P60,
 PERCENTILE_CONT(.8) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P80 FROM RF0
), RF AS (
 SELECT r.SnapshotID,r.CustomerID,
 CASE WHEN r.RecencyDays<=p.P20 THEN 5 WHEN r.RecencyDays<=p.P40 THEN 4 WHEN r.RecencyDays<=p.P60 THEN 3 WHEN r.RecencyDays<=p.P80 THEN 2 ELSE 1 END RScore,
 CASE WHEN r.Frequency=1 THEN 1 WHEN r.Frequency=2 THEN 2 WHEN r.Frequency=3 THEN 3 WHEN r.Frequency<=5 THEN 4 ELSE 5 END FScore
 FROM RF0 r JOIN RP p ON p.SnapshotID=r.SnapshotID
), Y AS (
 SELECT s.SnapshotID,h.CustomerID,CONVERT(bit,CASE WHEN EXISTS(
 SELECT 1 FROM Sales.SalesOrderHeader f WHERE f.CustomerID=h.CustomerID AND f.OrderDate>=s.OutcomeStart AND f.OrderDate<DATEADD(day,1,s.OutcomeEnd)
 ) THEN 1 ELSE 0 END) ReturnedInNext365Days
 FROM S s JOIN H h ON h.SnapshotID=s.SnapshotID
)
SELECT h.SnapshotID,h.SnapshotDate,h.CustomerID,h.FirstOrderDateAsOfCutoff,h.LastOrderDateAsOfCutoff,h.RecencyDays,h.Frequency,
 h.CustomerLifetimeDays,h.DaysSinceFirstOrder,h.AverageDaysBetweenOrders,m.MedianDaysBetweenOrders,
 CONVERT(bit,CASE WHEN h.Frequency=1 THEN 1 ELSE 0 END) OneOrderSoFar,CONVERT(bit,CASE WHEN h.Frequency>1 THEN 1 ELSE 0 END) RepeatSoFar,
 h.FirstOrderOnlineFlag,h.LastOrderOnlineFlag,h.OnlineOrderCount,h.OfflineOrderCount,1.0*h.OnlineOrderCount/h.Frequency OnlineOrderShare,
 CASE WHEN c.PersonID IS NOT NULL AND c.StoreID IS NULL THEN 'Person only' WHEN c.PersonID IS NOT NULL AND c.StoreID IS NOT NULL THEN 'Person and Store'
 WHEN c.PersonID IS NULL AND c.StoreID IS NOT NULL THEN 'Store only' ELSE 'Neither/unknown' END CustomerStructure,
 da.DistinctProducts,da.DistinctCategories,dc.Category DominantCategory,da.TotalOrderLines,da.TotalQuantity,oa.MeanLinesPerOrder,oa.MeanQuantityPerOrder,
 oa.MeanDistinctProductsPerOrder,da.DiscountedLineShare,da.BikesLineShare,da.AccessoriesLineShare,da.ClothingLineShare,da.ComponentsLineShare,
 rf.RScore,rf.FScore,CONCAT('R',rf.RScore,'F',rf.FScore) RFCode,
 CASE WHEN rf.RScore>=4 AND rf.FScore>=4 THEN 'Recent/high-frequency RF'
      WHEN rf.RScore>=4 AND rf.FScore<=2 THEN 'Recent first/low-frequency'
      WHEN rf.RScore=3 THEN 'Middle RF'
      WHEN rf.RScore<=2 AND rf.FScore>=4 THEN 'At-risk high-frequency'
      WHEN rf.RScore<=2 AND rf.FScore<=2 THEN 'Hibernating/low-frequency'
      ELSE 'Other RF' END RFSegment,
 CONVERT(bit,1-y.ReturnedInNext365Days) AnalyticalChurn,
 y.ReturnedInNext365Days,
 s.OutcomeStart,s.OutcomeEnd
FROM H h JOIN S s ON s.SnapshotID=h.SnapshotID
JOIN Y y ON y.SnapshotID=h.SnapshotID AND y.CustomerID=h.CustomerID
LEFT JOIN Med m ON m.SnapshotID=h.SnapshotID AND m.CustomerID=h.CustomerID
LEFT JOIN DA da ON da.SnapshotID=h.SnapshotID AND da.CustomerID=h.CustomerID
LEFT JOIN DC dc ON dc.SnapshotID=h.SnapshotID AND dc.CustomerID=h.CustomerID AND dc.rn=1
LEFT JOIN OA oa ON oa.SnapshotID=h.SnapshotID AND oa.CustomerID=h.CustomerID
LEFT JOIN Sales.Customer c ON c.CustomerID=h.CustomerID
LEFT JOIN RF rf ON rf.SnapshotID=h.SnapshotID AND rf.CustomerID=h.CustomerID
ORDER BY h.SnapshotDate,h.CustomerID;
