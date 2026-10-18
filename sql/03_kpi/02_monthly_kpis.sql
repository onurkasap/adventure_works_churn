/*
Monthly baseline trends for AdventureWorks2022.
Uses OrderDate as the transaction date and the header grain for revenue and
orders. COUNT(DISTINCT CustomerID) prevents multiple orders in a month from
counting the same customer more than once in that monthly period.
The SubTotal sum is pre-tax/pre-freight but unconverted: some orders reference
foreign currency rates. Do not interpret the summed amount as consolidated
revenue until a currency conversion rule is selected.
*/

SELECT
    DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS order_month,
    SUM(SubTotal) AS revenue_subtotal_before_tax_freight,
    COUNT_BIG(*) AS order_count,
    COUNT_BIG(DISTINCT CustomerID) AS purchasing_customers
FROM Sales.SalesOrderHeader
GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1)
ORDER BY order_month;
