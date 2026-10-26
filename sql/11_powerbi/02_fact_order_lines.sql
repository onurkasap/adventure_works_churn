/* Phase 11 | FactOrderLines: one row per SalesOrderDetail.
   Product is joined using the validated composite SpecialOfferProduct key. */
SELECT d.SalesOrderID, d.SalesOrderDetailID, d.ProductID,
       d.SpecialOfferID, d.OrderQty, d.UnitPriceDiscount,
       COALESCE(pc.ProductCategoryID,-1) AS ProductCategoryID,
       COALESCE(pc.Name,'Uncategorized') AS ProductCategory,
       COALESCE(ps.ProductSubcategoryID,-1) AS ProductSubcategoryID,
       COALESCE(ps.Name,'Uncategorized') AS ProductSubcategory
FROM Sales.SalesOrderDetail AS d
JOIN Sales.SpecialOfferProduct AS sop
  ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
JOIN Production.Product AS p ON p.ProductID=sop.ProductID
LEFT JOIN Production.ProductSubcategory AS ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
LEFT JOIN Production.ProductCategory AS pc ON pc.ProductCategoryID=ps.ProductCategoryID;
