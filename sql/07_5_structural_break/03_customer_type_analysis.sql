/* Customer structure follows nullable PersonID/StoreID links; labels do not
assert B2B/B2C. Acquisition is assigned to first observed order; active/repeat
metrics use distinct customer keys. */
WITH CustomerType AS (
 SELECT CustomerID,CASE WHEN PersonID IS NOT NULL AND StoreID IS NOT NULL THEN 'Both Person and Store'
                        WHEN PersonID IS NOT NULL THEN 'Person only' ELSE 'Store only' END AS CustomerStructure
 FROM Sales.Customer
), FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), PeriodCounts AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END AS Period,
        t.CustomerStructure,COUNT_BIG(*) AS Orders,COUNT(DISTINCT h.CustomerID) AS ActiveCustomers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate=h.OrderDate THEN h.CustomerID END) AS FirstObservedCustomers,
        COUNT(DISTINCT CASE WHEN f.FirstOrderDate<h.OrderDate THEN h.CustomerID END) AS RepeatCustomers
 FROM Sales.SalesOrderHeader h JOIN CustomerType t ON t.CustomerID=h.CustomerID
 JOIN FirstOrder f ON f.CustomerID=h.CustomerID
 GROUP BY CASE WHEN h.OrderDate<'20130701' THEN 'Before July 2013' ELSE 'July 2013 onward' END,t.CustomerStructure
)
SELECT *,CAST(100.0*FirstObservedCustomers/SUM(FirstObservedCustomers) OVER(PARTITION BY Period) AS decimal(7,3)) AS NewCustomerShare,
 CAST(100.0*ActiveCustomers/SUM(ActiveCustomers) OVER(PARTITION BY Period) AS decimal(7,3)) AS ActiveCustomerShare
FROM PeriodCounts ORDER BY Period,CustomerStructure;

-- Monthly new-purchaser counts by validated customer structure, Jan-Dec 2013.
WITH CustomerType AS (
 SELECT CustomerID,CASE WHEN PersonID IS NOT NULL AND StoreID IS NOT NULL THEN 'Both Person and Store'
                        WHEN PersonID IS NOT NULL THEN 'Person only' ELSE 'Store only' END AS CustomerStructure
 FROM Sales.Customer
), FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
)
SELECT DATEFROMPARTS(YEAR(f.FirstOrderDate),MONTH(f.FirstOrderDate),1) AS CohortMonth,t.CustomerStructure,
 COUNT_BIG(*) AS FirstObservedCustomers
FROM FirstOrder f JOIN CustomerType t ON t.CustomerID=f.CustomerID
WHERE f.FirstOrderDate>='20130101' AND f.FirstOrderDate<'20140101'
GROUP BY DATEFROMPARTS(YEAR(f.FirstOrderDate),MONTH(f.FirstOrderDate),1),t.CustomerStructure
ORDER BY CohortMonth,t.CustomerStructure;

-- Full registered/purchaser structural mix; exact base split validates zero orders are separate.
WITH PurchasingCustomers AS (SELECT DISTINCT CustomerID FROM Sales.SalesOrderHeader)
SELECT CASE WHEN c.PersonID IS NOT NULL AND c.StoreID IS NOT NULL THEN 'Both Person and Store'
            WHEN c.PersonID IS NOT NULL THEN 'Person only' ELSE 'Store only' END AS CustomerStructure,
       COUNT_BIG(*) AS RegisteredCustomers,
       COUNT(p.CustomerID) AS PurchasingCustomers
FROM Sales.Customer c LEFT JOIN PurchasingCustomers p ON p.CustomerID=c.CustomerID
GROUP BY CASE WHEN c.PersonID IS NOT NULL AND c.StoreID IS NOT NULL THEN 'Both Person and Store'
              WHEN c.PersonID IS NOT NULL THEN 'Person only' ELSE 'Store only' END
ORDER BY CustomerStructure;
