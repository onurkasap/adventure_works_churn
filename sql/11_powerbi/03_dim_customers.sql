/* One row per registered customer. Purchasing status is a current-extract flag. */
SELECT c.CustomerID, c.PersonID, c.StoreID, c.TerritoryID,
       CASE WHEN c.PersonID IS NOT NULL AND c.StoreID IS NOT NULL THEN 'Both Person and Store'
            WHEN c.PersonID IS NOT NULL THEN 'Person only'
            WHEN c.StoreID IS NOT NULL THEN 'Store only' ELSE 'Neither / unknown' END AS CustomerStructure,
       CASE WHEN p.CustomerID IS NULL THEN 0 ELSE 1 END AS HasObservedOrder
FROM Sales.Customer AS c
LEFT JOIN (SELECT DISTINCT CustomerID FROM Sales.SalesOrderHeader
           WHERE OrderDate >= '20110531' AND OrderDate < '20140701') AS p
  ON p.CustomerID=c.CustomerID;
