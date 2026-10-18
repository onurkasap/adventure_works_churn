/*
Database discovery for AdventureWorks2022.
All statements below read SQL Server catalog metadata; they do not modify data.
Run each SELECT in order to inspect schemas, tables, columns, primary keys,
and foreign-key relationships before designing customer analytics queries.
*/

-- 1. Schemas visible in this database.
SELECT
    s.name AS schema_name,
    s.schema_id
FROM sys.schemas AS s
WHERE s.schema_id < 16384 -- Excludes SQL Server's built-in system schemas.
ORDER BY s.name;

-- 2. User tables, grouped by their schema.
SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
ORDER BY s.name, t.name;

-- 3. Column names and data types in tables central to customer analytics.
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,
    ty.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
WHERE (s.name + N'.' + t.name) IN (
    N'Sales.Customer', N'Sales.Person', N'Person.Person',
    N'Sales.SalesOrderHeader', N'Sales.SalesOrderDetail',
    N'Production.Product', N'Production.ProductSubcategory',
    N'Production.ProductCategory', N'Sales.SalesTerritory',
    N'Sales.CustomerAddress', N'Person.Address',
    N'Sales.SalesTerritoryHistory', N'Sales.SalesReason'
)
ORDER BY s.name, t.name, c.column_id;

-- 4. Primary and unique key columns, in their defined key order.
-- A key may contain multiple columns, so key_ordinal is included.
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    kc.name AS constraint_name,
    kc.type_desc AS constraint_type,
    c.name AS column_name,
    ic.key_ordinal
FROM sys.key_constraints AS kc
INNER JOIN sys.tables AS t
    ON t.object_id = kc.parent_object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.index_columns AS ic
    ON ic.object_id = t.object_id
    AND ic.index_id = kc.unique_index_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
    AND c.column_id = ic.column_id
WHERE kc.type = 'PK'
ORDER BY s.name, t.name, kc.name, ic.key_ordinal;

-- 5. Foreign keys with their exact column mappings.
-- The child (parent_*) row references the primary/unique parent (referenced_*).
SELECT
    ps.name AS child_schema,
    pt.name AS child_table,
    pc.name AS child_column,
    rs.name AS referenced_schema,
    rt.name AS referenced_table,
    rc.name AS referenced_column,
    f.name AS foreign_key_name
FROM sys.foreign_key_columns AS fkc
INNER JOIN sys.foreign_keys AS f
    ON f.object_id = fkc.constraint_object_id
INNER JOIN sys.tables AS pt
    ON pt.object_id = fkc.parent_object_id
INNER JOIN sys.schemas AS ps
    ON ps.schema_id = pt.schema_id
INNER JOIN sys.columns AS pc
    ON pc.object_id = pt.object_id
    AND pc.column_id = fkc.parent_column_id
INNER JOIN sys.tables AS rt
    ON rt.object_id = fkc.referenced_object_id
INNER JOIN sys.schemas AS rs
    ON rs.schema_id = rt.schema_id
INNER JOIN sys.columns AS rc
    ON rc.object_id = rt.object_id
    AND rc.column_id = fkc.referenced_column_id
ORDER BY ps.name, pt.name, f.name, fkc.constraint_column_id;
