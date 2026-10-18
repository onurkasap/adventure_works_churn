/*
AdventureWorks2022 data-quality discovery for customer transactions.
Every statement is a read-only SELECT. Results are diagnostics, not cleanup
instructions and not final KPI or churn-label calculations.
*/

-- 1. Row counts establish the size of each core source table.
SELECT N'Sales.Customer' AS table_name, COUNT_BIG(*) AS row_count FROM Sales.Customer
UNION ALL
SELECT N'Sales.SalesOrderHeader', COUNT_BIG(*) FROM Sales.SalesOrderHeader
UNION ALL
SELECT N'Sales.SalesOrderDetail', COUNT_BIG(*) FROM Sales.SalesOrderDetail;

-- 2. Duplicate checks for the requested identifiers.
-- SalesOrderDetailID is checked alone because the analytical question asks
-- whether it is unique; its declared primary key is composite (see discovery).
SELECT N'Sales.Customer.CustomerID' AS key_name, COUNT_BIG(*) AS duplicate_key_count
FROM (SELECT CustomerID FROM Sales.Customer GROUP BY CustomerID HAVING COUNT_BIG(*) > 1) AS d
UNION ALL
SELECT N'Sales.SalesOrderHeader.SalesOrderID', COUNT_BIG(*)
FROM (SELECT SalesOrderID FROM Sales.SalesOrderHeader GROUP BY SalesOrderID HAVING COUNT_BIG(*) > 1) AS d
UNION ALL
SELECT N'Sales.SalesOrderDetail.SalesOrderDetailID', COUNT_BIG(*)
FROM (SELECT SalesOrderDetailID FROM Sales.SalesOrderDetail GROUP BY SalesOrderDetailID HAVING COUNT_BIG(*) > 1) AS d;

-- 3. NULL counts for customer and order linkage / interpretation fields.
SELECT N'Sales.Customer.PersonID' AS column_name, COUNT_BIG(*) AS null_count FROM Sales.Customer WHERE PersonID IS NULL
UNION ALL SELECT N'Sales.Customer.StoreID', COUNT_BIG(*) FROM Sales.Customer WHERE StoreID IS NULL
UNION ALL SELECT N'Sales.Customer.TerritoryID', COUNT_BIG(*) FROM Sales.Customer WHERE TerritoryID IS NULL
UNION ALL SELECT N'Sales.SalesOrderHeader.CustomerID', COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE CustomerID IS NULL
UNION ALL SELECT N'Sales.SalesOrderHeader.OrderDate', COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE OrderDate IS NULL
UNION ALL SELECT N'Sales.SalesOrderHeader.ShipDate', COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE ShipDate IS NULL
UNION ALL SELECT N'Sales.SalesOrderHeader.TerritoryID', COUNT_BIG(*) FROM Sales.SalesOrderHeader WHERE TerritoryID IS NULL;

-- 4. NULL counts in order-line fields used to interpret purchases and value.
SELECT N'Sales.SalesOrderDetail.OrderQty' AS column_name, COUNT_BIG(*) AS null_count FROM Sales.SalesOrderDetail WHERE OrderQty IS NULL
UNION ALL SELECT N'Sales.SalesOrderDetail.ProductID', COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE ProductID IS NULL
UNION ALL SELECT N'Sales.SalesOrderDetail.UnitPrice', COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE UnitPrice IS NULL
UNION ALL SELECT N'Sales.SalesOrderDetail.UnitPriceDiscount', COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE UnitPriceDiscount IS NULL
UNION ALL SELECT N'Sales.SalesOrderDetail.LineTotal', COUNT_BIG(*) FROM Sales.SalesOrderDetail WHERE LineTotal IS NULL;

-- 5. Header date coverage and date-order consistency.
SELECT
    MIN(OrderDate) AS first_order_date,
    MAX(OrderDate) AS last_order_date,
    COUNT_BIG(*) AS header_rows,
    SUM(CASE WHEN OrderDate IS NULL THEN 1 ELSE 0 END) AS null_order_date_rows,
    SUM(CASE WHEN DueDate < OrderDate THEN 1 ELSE 0 END) AS due_before_order_rows,
    SUM(CASE WHEN ShipDate < OrderDate THEN 1 ELSE 0 END) AS ship_before_order_rows,
    SUM(CASE WHEN ShipDate IS NOT NULL AND ShipDate > DueDate THEN 1 ELSE 0 END) AS ship_after_due_rows
FROM Sales.SalesOrderHeader;

-- 6. Orders whose CustomerID has no matching customer.
-- NOT EXISTS tests each order without multiplying rows through a join.
SELECT COUNT_BIG(*) AS orders_with_missing_customer
FROM Sales.SalesOrderHeader AS h
WHERE NOT EXISTS (
    SELECT 1 FROM Sales.Customer AS c WHERE c.CustomerID = h.CustomerID
);

-- 7. Customer distribution by count of linked orders, including customers
-- with no orders. The LEFT JOIN preserves those customers as zero-order rows.
WITH CustomerOrderCounts AS (
    SELECT c.CustomerID, COUNT(h.SalesOrderID) AS order_count
    FROM Sales.Customer AS c
    LEFT JOIN Sales.SalesOrderHeader AS h ON h.CustomerID = c.CustomerID
    GROUP BY c.CustomerID
)
SELECT
    SUM(CASE WHEN order_count = 0 THEN 1 ELSE 0 END) AS customers_with_zero_orders,
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS customers_with_one_order,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS customers_with_multiple_orders,
    MAX(order_count) AS maximum_orders_for_one_customer
FROM CustomerOrderCounts;

-- 8. Order headers with no detail rows; EXISTS avoids duplicating headers.
SELECT COUNT_BIG(*) AS orders_with_no_details
FROM Sales.SalesOrderHeader AS h
WHERE NOT EXISTS (
    SELECT 1 FROM Sales.SalesOrderDetail AS d WHERE d.SalesOrderID = h.SalesOrderID
);

-- 9. Detail rows whose header is missing.
SELECT COUNT_BIG(*) AS details_with_missing_order_header
FROM Sales.SalesOrderDetail AS d
WHERE NOT EXISTS (
    SELECT 1 FROM Sales.SalesOrderHeader AS h WHERE h.SalesOrderID = d.SalesOrderID
);

-- 10. Numeric ranges and counts of zero / negative values.
-- Ranges help identify candidates for investigation; large values alone are
-- not classified as errors.
SELECT N'OrderQty' AS field_name, COUNT_BIG(*) AS row_count, MIN(CONVERT(decimal(19,4), OrderQty)) AS min_value,
       MAX(CONVERT(decimal(19,4), OrderQty)) AS max_value,
       SUM(CASE WHEN OrderQty = 0 THEN 1 ELSE 0 END) AS zero_count,
       SUM(CASE WHEN OrderQty < 0 THEN 1 ELSE 0 END) AS negative_count
FROM Sales.SalesOrderDetail
UNION ALL SELECT N'UnitPrice', COUNT_BIG(*), MIN(UnitPrice), MAX(UnitPrice),
       SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderDetail
UNION ALL SELECT N'UnitPriceDiscount', COUNT_BIG(*), MIN(UnitPriceDiscount), MAX(UnitPriceDiscount),
       SUM(CASE WHEN UnitPriceDiscount = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN UnitPriceDiscount < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderDetail
UNION ALL SELECT N'LineTotal', COUNT_BIG(*), MIN(LineTotal), MAX(LineTotal),
       SUM(CASE WHEN LineTotal = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN LineTotal < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderDetail
UNION ALL SELECT N'SubTotal', COUNT_BIG(*), MIN(SubTotal), MAX(SubTotal),
       SUM(CASE WHEN SubTotal = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN SubTotal < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderHeader
UNION ALL SELECT N'TaxAmt', COUNT_BIG(*), MIN(TaxAmt), MAX(TaxAmt),
       SUM(CASE WHEN TaxAmt = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN TaxAmt < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderHeader
UNION ALL SELECT N'Freight', COUNT_BIG(*), MIN(Freight), MAX(Freight),
       SUM(CASE WHEN Freight = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN Freight < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderHeader
UNION ALL SELECT N'TotalDue', COUNT_BIG(*), MIN(TotalDue), MAX(TotalDue),
       SUM(CASE WHEN TotalDue = 0 THEN 1 ELSE 0 END), SUM(CASE WHEN TotalDue < 0 THEN 1 ELSE 0 END)
FROM Sales.SalesOrderHeader;

-- 11. Review the largest line totals with their parent order dates.
-- This surfaces context for investigation and does not label high values as bad.
SELECT TOP (20)
    d.SalesOrderID, d.SalesOrderDetailID, h.OrderDate,
    d.OrderQty, d.UnitPrice, d.UnitPriceDiscount, d.LineTotal
FROM Sales.SalesOrderDetail AS d
INNER JOIN Sales.SalesOrderHeader AS h ON h.SalesOrderID = d.SalesOrderID
ORDER BY d.LineTotal DESC;

-- 12. Sample suspicious zero / negative transaction values for context.
SELECT TOP (50)
    d.SalesOrderID, d.SalesOrderDetailID, h.OrderDate, d.OrderQty,
    d.UnitPrice, d.UnitPriceDiscount, d.LineTotal
FROM Sales.SalesOrderDetail AS d
INNER JOIN Sales.SalesOrderHeader AS h ON h.SalesOrderID = d.SalesOrderID
WHERE d.OrderQty <= 0 OR d.UnitPrice <= 0 OR d.UnitPriceDiscount < 0 OR d.LineTotal <= 0
ORDER BY h.OrderDate, d.SalesOrderID, d.SalesOrderDetailID;

-- 13. Verify whether order and customer records are connected via declared FK
-- columns in the actual data (counts only; does not infer beyond the join key).
SELECT
    COUNT_BIG(*) AS customer_rows,
    SUM(CASE WHEN PersonID IS NULL THEN 1 ELSE 0 END) AS no_person_link,
    SUM(CASE WHEN StoreID IS NULL THEN 1 ELSE 0 END) AS no_store_link,
    SUM(CASE WHEN TerritoryID IS NULL THEN 1 ELSE 0 END) AS no_customer_territory
FROM Sales.Customer;

-- 14. Check the actual overlap between optional person and store links.
-- NULL counts alone do not establish that the two customer types are exclusive.
SELECT
    CASE
        WHEN PersonID IS NULL AND StoreID IS NULL THEN N'neither link'
        WHEN PersonID IS NOT NULL AND StoreID IS NULL THEN N'person only'
        WHEN PersonID IS NULL AND StoreID IS NOT NULL THEN N'store only'
        ELSE N'both links'
    END AS identity_link_pattern,
    COUNT_BIG(*) AS customer_count
FROM Sales.Customer
GROUP BY
    CASE
        WHEN PersonID IS NULL AND StoreID IS NULL THEN N'neither link'
        WHEN PersonID IS NOT NULL AND StoreID IS NULL THEN N'person only'
        WHEN PersonID IS NULL AND StoreID IS NOT NULL THEN N'store only'
        ELSE N'both links'
    END;
