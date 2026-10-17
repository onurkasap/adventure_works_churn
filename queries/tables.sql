SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

select top 10 * from sales.Customer
select top 10 * from sales.SalesOrderHeader
SELECT TOP 10 * FROM Sales.SalesOrderDetail;
SELECT TOP 10 * FROM Production.Product;

SELECT
    MIN(OrderDate) AS FirstOrderDate,
    MAX(OrderDate) AS LastOrderDate,
    COUNT(*) AS TotalOrders,
    COUNT(DISTINCT CustomerID) AS CustomersWithOrders
FROM Sales.SalesOrderHeader;

SELECT
    COUNT(*) AS TotalCustomers
FROM Sales.Customer;

SELECT
    COUNT(*) AS TotalOrderLines
FROM Sales.SalesOrderDetail;

SELECT
    COUNT(*) AS TotalProducts
FROM Production.Product;