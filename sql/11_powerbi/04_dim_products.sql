/* Current product hierarchy; not effective-dated, so historical categories
   are the hierarchy as currently stored. One row per product. */
SELECT p.ProductID, p.Name AS ProductName,
       COALESCE(ps.ProductSubcategoryID,-1) AS ProductSubcategoryID,
       COALESCE(ps.Name,'Uncategorized') AS ProductSubcategory,
       COALESCE(pc.ProductCategoryID,-1) AS ProductCategoryID,
       COALESCE(pc.Name,'Uncategorized') AS ProductCategory
FROM Production.Product AS p
LEFT JOIN Production.ProductSubcategory AS ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
LEFT JOIN Production.ProductCategory AS pc ON pc.ProductCategoryID=ps.ProductCategoryID;
