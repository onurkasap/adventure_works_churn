/* Independent return-rate reconciliation. Population membership is established
only by at least one order on/before cutoff. Future customers cannot enter.
Returned means EXISTS a later order during the following 365 calendar days. */
DECLARE @DatasetEnd date='20140630';
WITH Cutoffs AS (SELECT CutoffDate FROM (VALUES(CONVERT(date,'20120630')),(CONVERT(date,'20130630')))v(CutoffDate)),
Baseline AS (
 SELECT c.CutoffDate,h.CustomerID,MIN(h.OrderDate) AS FirstOrderBeforeCutoff,MAX(h.OrderDate) AS LastOrderBeforeCutoff,
        COUNT_BIG(*) AS OrdersBeforeCutoff
 FROM Cutoffs c JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,c.CutoffDate)
 GROUP BY c.CutoffDate,h.CustomerID
), Outcome AS (
 SELECT b.CutoffDate,b.CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h
                         WHERE h.CustomerID=b.CustomerID
                           AND h.OrderDate>=DATEADD(day,1,b.CutoffDate)
                           AND h.OrderDate<=DATEADD(day,365,b.CutoffDate)
                           AND h.OrderDate<DATEADD(day,1,@DatasetEnd)) THEN 1 ELSE 0 END AS Returned
 FROM Baseline b
)
SELECT CutoffDate,COUNT_BIG(*) AS BaselineCustomers,
       SUM(Returned) AS ReturnedExistingCustomers,
       SUM(CASE WHEN Returned=0 THEN 1 ELSE 0 END) AS NoObservedReturn,
       CAST(100.0*SUM(Returned)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM Outcome GROUP BY CutoffDate ORDER BY CutoffDate;

-- Independent join-based reconciliation; DISTINCT CustomerID prevents one
-- returning customer with many future orders from being counted repeatedly.
WITH Cutoffs AS (SELECT CutoffDate FROM (VALUES(CONVERT(date,'20120630')),(CONVERT(date,'20130630')))v(CutoffDate)),
BaselineCustomers AS (
 SELECT DISTINCT c.CutoffDate,h.CustomerID
 FROM Cutoffs c JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,c.CutoffDate)
), ReturnCustomers AS (
 SELECT DISTINCT b.CutoffDate,b.CustomerID
 FROM BaselineCustomers b JOIN Sales.SalesOrderHeader h ON h.CustomerID=b.CustomerID
 JOIN Cutoffs c ON c.CutoffDate=b.CutoffDate
 WHERE h.OrderDate>=DATEADD(day,1,b.CutoffDate) AND h.OrderDate<=DATEADD(day,365,b.CutoffDate)
   AND h.OrderDate<DATEADD(day,1,@DatasetEnd)
)
SELECT b.CutoffDate,COUNT_BIG(*) AS BaselineDistinctCustomers,COUNT_BIG(r.CustomerID) AS ReturnedDistinctCustomers
FROM BaselineCustomers b LEFT JOIN ReturnCustomers r ON r.CutoffDate=b.CutoffDate AND r.CustomerID=b.CustomerID
GROUP BY b.CutoffDate ORDER BY b.CutoffDate;

-- Customer cohort at cutoff by channel and customer structure; decomposes the
-- historical outcome rate without allowing customers acquired afterward in.
WITH Cutoffs AS (SELECT CutoffDate FROM (VALUES(CONVERT(date,'20120630')),(CONVERT(date,'20130630')))v(CutoffDate)),
FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID),
FirstOrderChannel AS (
 SELECT CustomerID,CONVERT(int,OnlineOrderFlag) AS FirstOrderOnlineFlag
 FROM (SELECT h.CustomerID,h.OnlineOrderFlag,ROW_NUMBER() OVER(PARTITION BY h.CustomerID ORDER BY h.OrderDate,h.SalesOrderID) AS rn
       FROM Sales.SalesOrderHeader h) x WHERE rn=1
),
Baseline AS (
 SELECT c.CutoffDate,h.CustomerID,MIN(h.OrderDate) AS FirstOrderDate,fc.FirstOrderOnlineFlag
 FROM Cutoffs c JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,c.CutoffDate)
 JOIN FirstOrderChannel fc ON fc.CustomerID=h.CustomerID
 GROUP BY c.CutoffDate,h.CustomerID,fc.FirstOrderOnlineFlag
), Tagged AS (
 SELECT b.*,c.TerritoryID,CASE WHEN c.PersonID IS NOT NULL AND c.StoreID IS NOT NULL THEN 'Both Person and Store'
                 WHEN c.PersonID IS NOT NULL THEN 'Person only' ELSE 'Store only' END AS CustomerStructure,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=b.CustomerID
                         AND h.OrderDate>=DATEADD(day,1,b.CutoffDate)
                         AND h.OrderDate<=DATEADD(day,365,b.CutoffDate)) THEN 1 ELSE 0 END AS Returned
 FROM Baseline b JOIN Sales.Customer c ON c.CustomerID=b.CustomerID
)
SELECT CutoffDate,CustomerStructure,FirstOrderOnlineFlag,COUNT_BIG(*) AS BaselineCustomers,
       SUM(Returned) AS ReturnedCustomers,
       CAST(100.0*SUM(Returned)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM Tagged GROUP BY CutoffDate,CustomerStructure,FirstOrderOnlineFlag
ORDER BY CutoffDate,CustomerStructure,FirstOrderOnlineFlag;

-- Geography decomposition uses the customer's assigned territory, not the
-- order-header territory; NULL remains a visible category if encountered.
WITH Cutoffs AS (SELECT CutoffDate FROM (VALUES(CONVERT(date,'20120630')),(CONVERT(date,'20130630')))v(CutoffDate)),
Baseline AS (
 SELECT c.CutoffDate,h.CustomerID,cust.TerritoryID
 FROM Cutoffs c JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,c.CutoffDate)
 JOIN Sales.Customer cust ON cust.CustomerID=h.CustomerID
 GROUP BY c.CutoffDate,h.CustomerID,cust.TerritoryID
), Tagged AS (
 SELECT b.*,CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=b.CustomerID
                      AND h.OrderDate>=DATEADD(day,1,b.CutoffDate) AND h.OrderDate<=DATEADD(day,365,b.CutoffDate)) THEN 1 ELSE 0 END AS Returned
 FROM Baseline b
)
SELECT t.CutoffDate,t.TerritoryID,st.Name AS CustomerTerritory,st.CountryRegionCode,st.[Group] AS TerritoryGroup,
       COUNT_BIG(*) AS BaselineCustomers,SUM(t.Returned) AS ReturnedCustomers,
       CAST(100.0*SUM(t.Returned)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM Tagged t LEFT JOIN Sales.SalesTerritory st ON st.TerritoryID=t.TerritoryID
GROUP BY t.CutoffDate,t.TerritoryID,st.Name,st.CountryRegionCode,st.[Group]
ORDER BY t.CutoffDate,BaselineCustomers DESC;

-- Decompose return outcomes by categories represented in each customer's
-- pre-cutoff line history. A customer can belong to multiple product categories.
WITH Cutoffs AS (SELECT CutoffDate FROM (VALUES(CONVERT(date,'20120630')),(CONVERT(date,'20130630')))v(CutoffDate)),
Baseline AS (
 SELECT DISTINCT c.CutoffDate,h.CustomerID
 FROM Cutoffs c JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,c.CutoffDate)
), Outcomes AS (
 SELECT b.CutoffDate,b.CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=b.CustomerID
                         AND h.OrderDate>=DATEADD(day,1,b.CutoffDate) AND h.OrderDate<=DATEADD(day,365,b.CutoffDate)) THEN 1 ELSE 0 END AS Returned
 FROM Baseline b
), CustomerCategories AS (
 SELECT DISTINCT b.CutoffDate,b.CustomerID,COALESCE(pc.Name,'Uncategorized') AS ProductCategory
 FROM Baseline b JOIN Sales.SalesOrderHeader h ON h.CustomerID=b.CustomerID AND h.OrderDate<DATEADD(day,1,b.CutoffDate)
 JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 JOIN Sales.SpecialOfferProduct sop ON sop.SpecialOfferID=d.SpecialOfferID AND sop.ProductID=d.ProductID
 JOIN Production.Product p ON p.ProductID=sop.ProductID
 LEFT JOIN Production.ProductSubcategory ps ON ps.ProductSubcategoryID=p.ProductSubcategoryID
 LEFT JOIN Production.ProductCategory pc ON pc.ProductCategoryID=ps.ProductCategoryID
)
SELECT cc.CutoffDate,cc.ProductCategory,COUNT_BIG(*) AS BaselineCustomers,SUM(o.Returned) AS ReturnedCustomers,
       CAST(100.0*SUM(o.Returned)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM CustomerCategories cc JOIN Outcomes o ON o.CutoffDate=cc.CutoffDate AND o.CustomerID=cc.CustomerID
GROUP BY cc.CutoffDate,cc.ProductCategory ORDER BY cc.CutoffDate,cc.ProductCategory;

-- Leakage/exclusion check: how many first-ever customers appear during outcome
-- windows, and confirm none is present in the preceding cutoff population.
WITH Cutoffs AS (SELECT CutoffDate FROM (VALUES(CONVERT(date,'20120630')),(CONVERT(date,'20130630')))v(CutoffDate)),
FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID)
SELECT c.CutoffDate,COUNT_BIG(*) AS NewCustomersAcquiredDuringOutcomeWindow
FROM Cutoffs c JOIN FirstOrder f ON f.FirstOrderDate>=DATEADD(day,1,c.CutoffDate)
 AND f.FirstOrderDate<=DATEADD(day,365,c.CutoffDate)
GROUP BY c.CutoffDate ORDER BY c.CutoffDate;

-- Explain the denominator expansion between cutoff experiments. Partition the
-- 2013 cutoff baseline by first observed acquisition vintage. Both groups sum
-- to 5,156 returns in Jul 2013-Jun 2014.
WITH FirstOrder AS (SELECT CustomerID,MIN(OrderDate) AS FirstOrderDate FROM Sales.SalesOrderHeader GROUP BY CustomerID),
Vintage AS (
 SELECT CASE WHEN f.FirstOrderDate<'20120701' THEN 'First observed by 2012-06-30'
             ELSE 'First observed 2012-07-01 through 2013-06-30' END AS AcquisitionVintage,
        f.CustomerID
 FROM FirstOrder f WHERE f.FirstOrderDate<'20130701'
), Followup AS (
 SELECT v.AcquisitionVintage,v.CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=v.CustomerID
                         AND h.OrderDate>='20130701' AND h.OrderDate<'20140701') THEN 1 ELSE 0 END AS ReturnedJul13Jun14
 FROM Vintage v
)
SELECT AcquisitionVintage,COUNT_BIG(*) AS ExistingCustomersAt2013Cutoff,
       SUM(ReturnedJul13Jun14) AS ReturnedDuringJul13Jun14,
       CAST(100.0*SUM(ReturnedJul13Jun14)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM Followup GROUP BY AcquisitionVintage ORDER BY AcquisitionVintage;

-- Follow the same 2012 cutoff population in consecutive years.
WITH Baseline2012 AS (
 SELECT DISTINCT CustomerID FROM Sales.SalesOrderHeader WHERE OrderDate<'20120701'
), ConsecutiveWindows AS (
 SELECT '2012-07-01 to 2013-06-30' AS OutcomeWindow,CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=b.CustomerID
                         AND h.OrderDate>='20120701' AND h.OrderDate<'20130701') THEN 1 ELSE 0 END AS Returned
 FROM Baseline2012 b
 UNION ALL
 SELECT '2013-07-01 to 2014-06-30',CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=b.CustomerID
                         AND h.OrderDate>='20130701' AND h.OrderDate<'20140701') THEN 1 ELSE 0 END
 FROM Baseline2012 b
)
SELECT OutcomeWindow,COUNT_BIG(*) AS SameBaselineCustomers,SUM(Returned) AS ReturnedCustomers,
       CAST(100.0*SUM(Returned)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM ConsecutiveWindows GROUP BY OutcomeWindow ORDER BY OutcomeWindow;

-- Decompose the consecutive-window shift for the same 2012 baseline customers
-- by customer structure and first-order channel.
WITH Baseline2012 AS (
 SELECT DISTINCT h.CustomerID FROM Sales.SalesOrderHeader h WHERE h.OrderDate<'20120701'
), FirstOrderChannel AS (
 SELECT CustomerID,CONVERT(int,OnlineOrderFlag) AS FirstOrderOnlineFlag
 FROM (SELECT h.CustomerID,h.OnlineOrderFlag,
              ROW_NUMBER() OVER(PARTITION BY h.CustomerID ORDER BY h.OrderDate,h.SalesOrderID) AS rn
       FROM Sales.SalesOrderHeader h) x WHERE rn=1
), CustomerTraits AS (
 SELECT b.CustomerID,fc.FirstOrderOnlineFlag,
        CASE WHEN c.PersonID IS NOT NULL AND c.StoreID IS NOT NULL THEN 'Both Person and Store'
             WHEN c.PersonID IS NOT NULL THEN 'Person only' ELSE 'Store only' END AS CustomerStructure
 FROM Baseline2012 b JOIN FirstOrderChannel fc ON fc.CustomerID=b.CustomerID
 JOIN Sales.Customer c ON c.CustomerID=b.CustomerID
), WindowResults AS (
 SELECT '2012-07-01 to 2013-06-30' AS OutcomeWindow,CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=t.CustomerID
                         AND h.OrderDate>='20120701' AND h.OrderDate<'20130701') THEN 1 ELSE 0 END AS Returned
 FROM CustomerTraits t
 UNION ALL
 SELECT '2013-07-01 to 2014-06-30',CustomerID,
        CASE WHEN EXISTS(SELECT 1 FROM Sales.SalesOrderHeader h WHERE h.CustomerID=t.CustomerID
                         AND h.OrderDate>='20130701' AND h.OrderDate<'20140701') THEN 1 ELSE 0 END
 FROM CustomerTraits t
)
SELECT w.OutcomeWindow,t.CustomerStructure,t.FirstOrderOnlineFlag,COUNT_BIG(*) AS SameBaselineCustomers,
       SUM(w.Returned) AS ReturnedCustomers,CAST(100.0*SUM(w.Returned)/COUNT_BIG(*) AS decimal(7,3)) AS ReturnRate
FROM WindowResults w JOIN CustomerTraits t ON t.CustomerID=w.CustomerID
GROUP BY w.OutcomeWindow,t.CustomerStructure,t.FirstOrderOnlineFlag
ORDER BY w.OutcomeWindow,t.CustomerStructure,t.FirstOrderOnlineFlag;
