/* Pricing amounts can have mixed currency context. Discount rates, quantities,
and within-product comparisons are emphasized; no consolidated revenue claim. */
WITH DetailBase AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        d.ProductID,d.SalesOrderID,d.OrderQty,d.UnitPrice,d.UnitPriceDiscount,d.LineTotal,
        CASE WHEN d.UnitPriceDiscount>0 THEN 1 ELSE 0 END AS DiscountedLine
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
)
SELECT DISTINCT Period,COUNT_BIG(*) OVER(PARTITION BY Period) AS OrderLines,
       SUM(OrderQty) OVER(PARTITION BY Period) AS Units,
       SUM(DiscountedLine) OVER(PARTITION BY Period) AS DiscountedLines,
       CAST(100.0*SUM(DiscountedLine) OVER(PARTITION BY Period)/COUNT_BIG(*) OVER(PARTITION BY Period) AS decimal(7,3)) AS DiscountedLineShare,
       AVG(CONVERT(float,UnitPriceDiscount)) OVER(PARTITION BY Period) AS MeanDiscountFraction,
       PERCENTILE_CONT(.50) WITHIN GROUP(ORDER BY CONVERT(float,UnitPriceDiscount)) OVER(PARTITION BY Period) AS MedianDiscountFraction,
       AVG(CONVERT(float,OrderQty)) OVER(PARTITION BY Period) AS MeanUnitsPerLine,
       PERCENTILE_CONT(.50) WITHIN GROUP(ORDER BY CONVERT(float,OrderQty)) OVER(PARTITION BY Period) AS MedianUnitsPerLine
FROM DetailBase ORDER BY Period;

-- Product-matched unit price and discount summaries reduce mix confounding.
WITH DetailBase AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        d.ProductID,d.UnitPrice,d.UnitPriceDiscount,d.OrderQty
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
), ProductPeriod AS (
 SELECT Period,ProductID,COUNT_BIG(*) AS Lines,AVG(CONVERT(float,UnitPrice)) AS MeanUnitPriceRaw,
        AVG(CONVERT(float,UnitPriceDiscount)) AS MeanDiscountFraction,
        AVG(CONVERT(float,OrderQty)) AS MeanUnitsPerLine
 FROM DetailBase GROUP BY Period,ProductID
)
SELECT a.ProductID,p.Name AS Product,a.Lines AS PreLines,b.Lines AS PostLines,
       a.MeanUnitPriceRaw AS PreMeanUnitPriceRaw,b.MeanUnitPriceRaw AS PostMeanUnitPriceRaw,
       a.MeanDiscountFraction AS PreMeanDiscount,b.MeanDiscountFraction AS PostMeanDiscount,
       a.MeanUnitsPerLine AS PreMeanUnits,b.MeanUnitsPerLine AS PostMeanUnits
FROM ProductPeriod a JOIN ProductPeriod b ON b.ProductID=a.ProductID AND b.Period='Jul-Dec 2013'
JOIN Production.Product p ON p.ProductID=a.ProductID
WHERE a.Period='Jan-Jun 2013'
ORDER BY (a.Lines+b.Lines) DESC;

-- Currency context and line values: descriptive cross-tab, no conversion.
WITH LineValues AS (
 SELECT CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END AS Period,
        CASE WHEN h.CurrencyRateID IS NULL THEN 'No CurrencyRateID' ELSE 'Has CurrencyRateID' END AS RateReference,
        d.UnitPrice,
        COUNT_BIG(*) OVER(PARTITION BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,
                                      CASE WHEN h.CurrencyRateID IS NULL THEN 'No CurrencyRateID' ELSE 'Has CurrencyRateID' END) AS OrderLines,
        AVG(CONVERT(float,d.UnitPrice)) OVER(PARTITION BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,
                                             CASE WHEN h.CurrencyRateID IS NULL THEN 'No CurrencyRateID' ELSE 'Has CurrencyRateID' END) AS MeanUnitPriceRaw,
        PERCENTILE_CONT(.50) WITHIN GROUP(ORDER BY CONVERT(float,d.UnitPrice)) OVER
          (PARTITION BY CASE WHEN h.OrderDate<'20130701' THEN 'Jan-Jun 2013' ELSE 'Jul-Dec 2013' END,
                        CASE WHEN h.CurrencyRateID IS NULL THEN 'No CurrencyRateID' ELSE 'Has CurrencyRateID' END) AS MedianUnitPriceRaw
 FROM Sales.SalesOrderHeader h JOIN Sales.SalesOrderDetail d ON d.SalesOrderID=h.SalesOrderID
 WHERE h.OrderDate>='20130101' AND h.OrderDate<'20140101'
)
SELECT DISTINCT Period,RateReference,OrderLines,MeanUnitPriceRaw,MedianUnitPriceRaw FROM LineValues ORDER BY Period,RateReference;
