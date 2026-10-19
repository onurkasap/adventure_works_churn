/* Customer territory answers customer acquisition composition. Order-header
territory answers where orders were recorded. They are not interchangeable. */
WITH FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), Acquisition AS (
 SELECT CASE WHEN f.FirstOrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END AS Period,
        c.TerritoryID,COUNT_BIG(*) AS NewCustomers
 FROM FirstOrder f JOIN Sales.Customer c ON c.CustomerID=f.CustomerID
 GROUP BY CASE WHEN f.FirstOrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END,c.TerritoryID
)
SELECT a.Period,a.TerritoryID,t.Name AS Territory,t.CountryRegionCode,t.[Group] AS TerritoryGroup,
       a.NewCustomers,CAST(100.0*a.NewCustomers/SUM(a.NewCustomers) OVER(PARTITION BY a.Period) AS decimal(7,3)) AS NewCustomerShare
FROM Acquisition a LEFT JOIN Sales.SalesTerritory t ON t.TerritoryID=a.TerritoryID
ORDER BY a.Period,a.NewCustomers DESC;

-- Order territory contribution by equal Jan-Jun/Jul-Dec 2013 windows.
WITH OrderCounts AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        h.TerritoryID,COUNT_BIG(*) AS Orders,COUNT(DISTINCT h.CustomerID) AS PurchasingCustomers
 FROM Sales.SalesOrderHeader h WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
 GROUP BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,h.TerritoryID
)
SELECT o.Period,o.TerritoryID,t.Name AS Territory,t.CountryRegionCode,t.[Group] AS TerritoryGroup,
       o.Orders,o.PurchasingCustomers,
       CAST(100.0*o.Orders/SUM(o.Orders) OVER(PARTITION BY o.Period) AS decimal(7,3)) AS OrderShare,
       CAST(100.0*o.PurchasingCustomers/SUM(o.PurchasingCustomers) OVER(PARTITION BY o.Period) AS decimal(7,3)) AS CustomerTerritoryShare
FROM OrderCounts o LEFT JOIN Sales.SalesTerritory t ON t.TerritoryID=o.TerritoryID
ORDER BY o.Period,o.Orders DESC;

-- Country/region and group via customer territory for new customer counts.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID)
SELECT CASE WHEN f.FirstOrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END AS Period,
       t.CountryRegionCode,cr.Name AS CountryRegion,t.[Group] AS TerritoryGroup,COUNT_BIG(*) AS NewCustomers
FROM FirstOrder f JOIN Sales.Customer c ON c.CustomerID=f.CustomerID
LEFT JOIN Sales.SalesTerritory t ON t.TerritoryID=c.TerritoryID
LEFT JOIN Person.CountryRegion cr ON cr.CountryRegionCode=t.CountryRegionCode
GROUP BY CASE WHEN f.FirstOrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END,
         t.CountryRegionCode,cr.Name,t.[Group]
ORDER BY Period,NewCustomers DESC;

-- Matched-window acquisition by the customer's assigned territory.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID),
NewByTerritory AS (
 SELECT CASE WHEN f.FirstOrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        c.TerritoryID,COUNT_BIG(*) AS NewCustomers
 FROM FirstOrder f JOIN Sales.Customer c ON c.CustomerID=f.CustomerID
 WHERE f.FirstOrderDate>='20130101' AND f.FirstOrderDate<'20140101'
 GROUP BY CASE WHEN f.FirstOrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,c.TerritoryID
)
SELECT n.Period,n.TerritoryID,t.Name AS CustomerTerritory,t.CountryRegionCode,t.[Group] AS TerritoryGroup,
       n.NewCustomers,CAST(100.0*n.NewCustomers/SUM(n.NewCustomers) OVER(PARTITION BY n.Period) AS decimal(7,3)) AS NewCustomerShare
FROM NewByTerritory n LEFT JOIN Sales.SalesTerritory t ON t.TerritoryID=n.TerritoryID
ORDER BY n.Period,n.NewCustomers DESC;
