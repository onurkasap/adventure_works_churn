/*
Currency evidence review only. This does not convert or score MonetaryRaw.
Inspect the declared relationship, the order-header reference, rate pairs,
stored rate ranges, and headers without rate references. Database metadata and
observed values alone may not establish business conversion convention.
*/
-- Catalog definition of CurrencyRate and declared foreign-key path.
SELECT s.name AS SchemaName, t.name AS TableName, c.column_id, c.name AS ColumnName,
       TYPE_NAME(c.user_type_id) AS DataType, c.max_length, c.precision, c.scale, c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c ON c.object_id = t.object_id
WHERE s.name = N'Sales' AND t.name IN (N'SalesOrderHeader', N'CurrencyRate')
  AND c.name IN (N'CurrencyRateID', N'OrderDate', N'SubTotal', N'FromCurrencyCode', N'ToCurrencyCode',
                 N'CurrencyRateDate', N'AverageRate', N'EndOfDayRate')
ORDER BY t.name, c.column_id;

SELECT fk.name AS ForeignKeyName,
       OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ChildSchema,
       OBJECT_NAME(fk.parent_object_id) AS ChildTable,
       pc.name AS ChildColumn,
       OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ParentSchema,
       OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
       rc.name AS ParentColumn
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.columns AS pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.columns AS rc ON rc.object_id = fkc.referenced_object_id AND rc.column_id = fkc.referenced_column_id
WHERE fk.parent_object_id = OBJECT_ID(N'Sales.SalesOrderHeader')
  AND fk.referenced_object_id = OBJECT_ID(N'Sales.CurrencyRate');

-- Count null/non-null references and show linked currency-pair/rate ranges.
SELECT CASE WHEN h.CurrencyRateID IS NULL THEN N'No CurrencyRateID' ELSE N'Has CurrencyRateID' END AS RateReference,
       COUNT_BIG(*) AS OrderHeaders, SUM(h.SubTotal) AS SubTotalStoredUnconverted
FROM Sales.SalesOrderHeader AS h
GROUP BY CASE WHEN h.CurrencyRateID IS NULL THEN N'No CurrencyRateID' ELSE N'Has CurrencyRateID' END;

SELECT r.FromCurrencyCode, r.ToCurrencyCode, COUNT_BIG(*) AS RateRows,
       MIN(r.CurrencyRateDate) AS FirstRateDate, MAX(r.CurrencyRateDate) AS LastRateDate,
       MIN(r.AverageRate) AS MinimumAverageRate, MAX(r.AverageRate) AS MaximumAverageRate,
       MIN(r.EndOfDayRate) AS MinimumEndOfDayRate, MAX(r.EndOfDayRate) AS MaximumEndOfDayRate
FROM Sales.CurrencyRate AS r
GROUP BY r.FromCurrencyCode, r.ToCurrencyCode
ORDER BY r.FromCurrencyCode, r.ToCurrencyCode;

-- Confirm order dates and pair/rate context on representative linked headers.
SELECT TOP (20) h.SalesOrderID, h.OrderDate, h.CurrencyRateID,
       h.SubTotal AS SubTotalStoredUnconverted,
       r.FromCurrencyCode, r.ToCurrencyCode, r.CurrencyRateDate, r.AverageRate, r.EndOfDayRate
FROM Sales.SalesOrderHeader AS h
LEFT JOIN Sales.CurrencyRate AS r ON r.CurrencyRateID = h.CurrencyRateID
WHERE h.CurrencyRateID IS NOT NULL
ORDER BY h.OrderDate, h.SalesOrderID;

-- A grouped mapping highlights what NULL CurrencyRateID means empirically;
-- no-rate orders cannot be assigned a currency based on this FK alone.
SELECT CASE WHEN h.CurrencyRateID IS NULL THEN N'NULL' ELSE N'Not NULL' END AS CurrencyRateIDState,
       COUNT_BIG(*) AS OrderHeaders,
       MIN(h.OrderDate) AS FirstOrderDate, MAX(h.OrderDate) AS LastOrderDate,
       COUNT(DISTINCT r.FromCurrencyCode) AS DistinctFromCurrencies,
       COUNT(DISTINCT r.ToCurrencyCode) AS DistinctToCurrencies
FROM Sales.SalesOrderHeader AS h
LEFT JOIN Sales.CurrencyRate AS r ON r.CurrencyRateID = h.CurrencyRateID
GROUP BY CASE WHEN h.CurrencyRateID IS NULL THEN N'NULL' ELSE N'Not NULL' END;
