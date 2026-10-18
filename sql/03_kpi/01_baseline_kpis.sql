/*
AdventureWorks2022 baseline customer and sales KPIs.
Read-only SELECT statements. Grain is stated in the comments; no detail-level
join is used for order/customer counts.
*/

-- 1. Inspect order statuses before interpreting header amounts as realized
-- sales. Status values and amount totals are shown without assuming a filter.
SELECT
    Status,
    COUNT_BIG(*) AS orders,
    SUM(SubTotal) AS subtotal_before_tax_freight,
    SUM(TaxAmt) AS tax_amount,
    SUM(Freight) AS freight_amount,
    SUM(TotalDue) AS total_due
FROM Sales.SalesOrderHeader
GROUP BY Status
ORDER BY Status;

-- 1b. The header has a verified CurrencyRateID relationship. Show whether
-- each order has a rate reference before presenting monetary results with a
-- currency symbol or assuming a single reporting currency.
SELECT
    CASE WHEN CurrencyRateID IS NULL THEN N'no currency-rate reference'
         ELSE N'currency-rate reference present' END AS currency_rate_group,
    COUNT_BIG(*) AS orders,
    SUM(SubTotal) AS subtotal,
    SUM(TotalDue) AS total_due
FROM Sales.SalesOrderHeader
GROUP BY CASE WHEN CurrencyRateID IS NULL THEN N'no currency-rate reference'
              ELSE N'currency-rate reference present' END;

-- 1c. Inspect the exchange-rate dimension columns before making any currency
-- conversion assumptions. These catalog fields are read-only metadata.
SELECT c.name AS column_name, ty.name AS data_type, c.is_nullable
FROM sys.tables AS t
INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c ON c.object_id = t.object_id
INNER JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE s.name = N'Sales' AND t.name = N'CurrencyRate'
ORDER BY c.column_id;

-- 1d. Inspect currency-pair references on orders. The output is descriptive;
-- choose a conversion direction/rate type only after confirming business rules.
SELECT
    cr.FromCurrencyCode,
    cr.ToCurrencyCode,
    COUNT_BIG(*) AS orders,
    SUM(h.SubTotal) AS recorded_subtotal
FROM Sales.SalesOrderHeader AS h
INNER JOIN Sales.CurrencyRate AS cr
    ON cr.CurrencyRateID = h.CurrencyRateID
GROUP BY cr.FromCurrencyCode, cr.ToCurrencyCode
ORDER BY cr.FromCurrencyCode, cr.ToCurrencyCode;

-- 2. Baseline population and money-field reconciliation.
-- SubTotal is chosen as merchandise sales before tax/freight. TotalDue is
-- reported separately because it includes tax and freight. LineTotal is an
-- independent line-grain cross-check of header SubTotal. Because some orders
-- have CurrencyRateID, these amounts are raw stored values, not FX-normalized.
WITH OrderAmounts AS (
    SELECT SalesOrderID, SubTotal, TaxAmt, Freight, TotalDue
    FROM Sales.SalesOrderHeader
),
LineTotals AS (
    SELECT SalesOrderID, SUM(LineTotal) AS sum_line_total
    FROM Sales.SalesOrderDetail
    GROUP BY SalesOrderID
),
CustomerOrderCounts AS (
    SELECT c.CustomerID, COUNT_BIG(h.SalesOrderID) AS order_count
    FROM Sales.Customer AS c
    LEFT JOIN Sales.SalesOrderHeader AS h
        ON h.CustomerID = c.CustomerID
    GROUP BY c.CustomerID
)
SELECT
    (SELECT COUNT_BIG(*) FROM Sales.Customer) AS registered_customers,
    (SELECT COUNT_BIG(*) FROM Sales.SalesOrderHeader) AS total_orders,
    (SELECT COUNT_BIG(DISTINCT CustomerID) FROM Sales.SalesOrderHeader) AS purchasing_customers,
    (SELECT COUNT_BIG(*) FROM CustomerOrderCounts WHERE order_count = 0) AS customers_without_orders,
    (SELECT SUM(SubTotal) FROM OrderAmounts) AS total_revenue_subtotal,
    CAST((SELECT SUM(SubTotal) FROM OrderAmounts) AS decimal(19,4))
        / NULLIF(CAST((SELECT COUNT_BIG(*) FROM OrderAmounts) AS decimal(19,4)), 0) AS aov_raw_unconverted,
    (SELECT SUM(TotalDue) FROM OrderAmounts) AS alternative_total_due,
    (SELECT SUM(sum_line_total) FROM LineTotals) AS independently_summed_line_total,
    (SELECT SUM(SubTotal) - SUM(TotalDue) FROM OrderAmounts) AS subtotal_minus_total_due;

-- 3. Customer repeat-purchase metrics. The intermediate table has exactly
-- one row per registered customer; COUNT(order ID) counts headers, not lines.
WITH CustomerOrderCounts AS (
    SELECT c.CustomerID, COUNT_BIG(h.SalesOrderID) AS order_count
    FROM Sales.Customer AS c
    LEFT JOIN Sales.SalesOrderHeader AS h
        ON h.CustomerID = c.CustomerID
    GROUP BY c.CustomerID
),
PurchasingCustomerCounts AS (
    SELECT order_count
    FROM CustomerOrderCounts
    WHERE order_count > 0
)
SELECT
    SUM(order_count) AS orders_from_purchasing_customers,
    COUNT_BIG(*) AS purchasing_customers,
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    CAST(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS decimal(19,6))
        / NULLIF(COUNT_BIG(*), 0) AS repeat_customer_rate,
    CAST(SUM(order_count) AS decimal(19,6))
        / NULLIF(COUNT_BIG(*), 0) AS orders_per_purchasing_customer
FROM PurchasingCustomerCounts;

-- 4. Independent order-grain comparison: header SubTotal vs. the sum of
-- line-level LineTotal. This also reports the largest absolute order gap.
WITH LineTotals AS (
    SELECT SalesOrderID, SUM(LineTotal) AS sum_line_total
    FROM Sales.SalesOrderDetail
    GROUP BY SalesOrderID
),
OrderReconciliation AS (
    SELECT
        h.SalesOrderID,
        h.SubTotal,
        COALESCE(l.sum_line_total, 0) AS sum_line_total,
        h.SubTotal - COALESCE(l.sum_line_total, 0) AS difference
    FROM Sales.SalesOrderHeader AS h
    LEFT JOIN LineTotals AS l
        ON l.SalesOrderID = h.SalesOrderID
)
SELECT
    COUNT_BIG(*) AS orders_compared,
    SUM(SubTotal) AS sum_header_subtotal,
    SUM(sum_line_total) AS sum_detail_line_totals,
    SUM(difference) AS total_difference,
    SUM(CASE WHEN ABS(difference) > 0.01 THEN 1 ELSE 0 END) AS orders_over_one_cent_difference,
    MAX(ABS(difference)) AS largest_absolute_order_difference
FROM OrderReconciliation;
