/* Phase 11 | FactOrders: one row per SalesOrderHeader.
   Do not join detail rows here: that would multiply order counts. */
SELECT h.SalesOrderID, h.CustomerID, h.TerritoryID,
       CONVERT(date,h.OrderDate) AS OrderDate,
       h.OnlineOrderFlag, h.Status
FROM Sales.SalesOrderHeader AS h
WHERE h.OrderDate >= '20110531' AND h.OrderDate < '20140701';
