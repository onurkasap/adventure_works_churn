/* SpecialOfferID is observed on each detail row and references the offer/product
bridge. Offer descriptions are source metadata, not evidence of a campaign. */
WITH OfferLines AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        d.SpecialOfferID,d.SalesOrderID,h.CustomerID,d.OrderQty,d.UnitPriceDiscount,
        so.Description,so.Type,so.Category,so.DiscountPct AS OfferDiscountPct,so.StartDate,so.EndDate
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 JOIN Sales.SpecialOffer so ON so.SpecialOfferID=d.SpecialOfferID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
)
SELECT Period,SpecialOfferID,Description,Type,Category,OfferDiscountPct,StartDate,EndDate,
       COUNT_BIG(*) AS OrderLines,COUNT(DISTINCT SalesOrderID) AS Orders,
       COUNT(DISTINCT CustomerID) AS PurchasingCustomers,SUM(OrderQty) AS Units,
       CAST(100.0*COUNT_BIG(*)/SUM(COUNT_BIG(*)) OVER(PARTITION BY Period) AS decimal(7,3)) AS LineShare
FROM OfferLines
GROUP BY Period,SpecialOfferID,Description,Type,Category,OfferDiscountPct,StartDate,EndDate
ORDER BY Period,OrderLines DESC;

-- Offer usage on first-observed customer orders; distinct customers avoid line multiplication.
WITH FirstOrder AS (
 SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID
), FirstOrderOffers AS (
 SELECT CASE WHEN f.FirstOrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        f.CustomerID,d.SpecialOfferID,so.Description,so.Type,so.Category,
        CASE WHEN d.UnitPriceDiscount>0 THEN 1 ELSE 0 END AS DiscountedLine
 FROM FirstOrder f JOIN Sales.SalesOrderHeader h ON h.CustomerID=f.CustomerID AND h.OrderDate=f.FirstOrderDate
 JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID JOIN Sales.SpecialOffer so ON so.SpecialOfferID=d.SpecialOfferID
 WHERE f.FirstOrderDate>='20130101' AND f.FirstOrderDate<'20140101'
)
SELECT Period,SpecialOfferID,Description,Type,Category,COUNT(DISTINCT CustomerID) AS NewCustomers,
       COUNT_BIG(*) AS FirstOrderLines,SUM(DiscountedLine) AS DiscountedLines
FROM FirstOrderOffers GROUP BY Period,SpecialOfferID,Description,Type,Category
ORDER BY Period,NewCustomers DESC;
