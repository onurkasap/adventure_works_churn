/* Documentation output: feature eligibility rules for any later modeling. */
SELECT * FROM (VALUES
('RecencyDays','Cutoff minus last pre-cutoff order date','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','Recomputed at each cutoff.'),
('Frequency','Count of pre-cutoff orders','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','Never use full-extract frequency.'),
('OneOrderSoFar / RepeatSoFar','Frequency equals one / greater than one','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','Derived only from historical frequency.'),
('LastOrderDate','Maximum pre-cutoff order date','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','Future last order would leak outcome.'),
('Purchase-gap statistics','Mean/median day gaps between pre-cutoff orders','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','Null with fewer than two orders.'),
('RScore / FScore / RFCode','Snapshot-specific recency quantiles and tied frequency bands','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','Recalculate per snapshot; no Monetary.'),
('Channel features','First/last online flag, online/offline counts/share','Sales.SalesOrderHeader','Customer x snapshot','<= SnapshotDate','Yes','OnlineOrderFlag semantics are not business-channel proof.'),
('Customer structure','PersonID/StoreID link category','Sales.Customer','Customer x snapshot','Current record; historical validity unknown','Conditional','Attribute may have changed; source is not effective-dated.'),
('Product/category features','Distinct products/categories, dominant category and shares','Sales.SalesOrderHeader, Sales.SalesOrderDetail, Sales.SpecialOfferProduct, Production.Product, Production.ProductSubcategory, Production.ProductCategory','Customer x snapshot','OrderDate <= SnapshotDate','Yes','Composite offer/product join; hierarchy is current.'),
('Order behavior','Lines, units, mean basket sizes, discounted-line share','Sales.SalesOrderHeader, Sales.SalesOrderDetail','Customer x snapshot','OrderDate <= SnapshotDate','Yes','No monetary value used.'),
('AnalyticalChurn / ReturnedInNext365Days','Any order/no order during fixed following 365 days','Sales.SalesOrderHeader','Customer x snapshot','OutcomeStart through OutcomeEnd','Target only','Must never be used as a feature for the same snapshot.'),
('MonetaryRaw, SubTotal, UnitPrice, AOV','Monetary totals or averages','Sales.SalesOrderHeader, Sales.SalesOrderDetail','Customer x snapshot','Not applicable','No','Excluded: common-currency interpretation unresolved.')
) v(FeatureName,Definition,SourceTables,Grain,MaximumAllowedDate,SafeForHistoricalPrediction,LeakageRiskNotes)
ORDER BY FeatureName;
