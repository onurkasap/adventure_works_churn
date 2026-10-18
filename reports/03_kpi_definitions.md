# Phase 3: Baseline KPI definitions and results

## Scope and conventions

These baseline calculations use the verified AdventureWorks2022 relationships and the read-only queries in [01_baseline_kpis.sql](../sql/03_kpi/01_baseline_kpis.sql) and [02_monthly_kpis.sql](../sql/03_kpi/02_monthly_kpis.sql). The observed order period is **2011-05-31 through 2014-06-30**.

The population distinction is important:

- **Registered customers** are rows in `Sales.Customer`, whether or not they ordered.
- **Purchasing customers** are distinct `CustomerID` values represented in `Sales.SalesOrderHeader`.

All **31,465** observed order headers have `Status = 5`. No status filter was applied, so the baseline includes every order header in the observed extract. The query confirms the actual status value, but it does not join a status description; confirm status semantics with the project owner before using this as a policy for later data.

## Monetary field choice

The selected raw sales field is **header `SubTotal`**, summed once per order. This is the order-level merchandise subtotal before tax and freight and avoids counting an order header once per detail line. However, this database has foreign-currency order references, so the raw sum is **not consolidated revenue** until a conversion basis is chosen.

The fields are not interchangeable:

- `SalesOrderHeader.SubTotal` is the selected merchandise sales value.
- `SalesOrderHeader.TotalDue` includes tax and freight and is reported as a separate alternative total due; it is not the selected revenue measure.
- `SalesOrderDetail.LineTotal` is a line-level amount. Its sum provides an independent reconciliation to header `SubTotal`; due to stored numeric precision, it is not bit-for-bit identical.
- Of 31,465 headers, **17,489** have no `CurrencyRateID` and **13,976** do. Referenced pairs are USD to AUD, USD to CAD, USD to DEM, USD to EUR, USD to FRF, and USD to GBP. The `Sales.CurrencyRate` table provides both `AverageRate` and `EndOfDayRate`. This phase does not choose a rate or assume conversion direction; raw monetary totals and monthly revenue are sums of stored values across currency contexts.

No returns, refunds, cost of goods, or accounting recognition rules were inferred from these fields. Therefore, "revenue" here means **recorded order subtotal before tax and freight**, not audited or net recognized revenue.

## KPI definitions and calculated values

| KPI | Business meaning | Formula | Tables and columns | Grain | Assumptions | Result |
|---|---|---|---|---|---|---:|
| Total Revenue / Sales (raw subtotal baseline) | Arithmetic sum of merchandise subtotals recorded before tax and freight during the observed period. | `SUM(SubTotal)` | `Sales.SalesOrderHeader.SubTotal` | One header row per order | Include all headers (all have observed `Status = 5`). Because currency-rate references exist, the value is **unconverted and must not be treated as consolidated revenue**. | **109,846,381.4039 stored currency units (unconverted)** |
| Total Orders | Number of order headers placed/recorded. | `COUNT(*)` | `Sales.SalesOrderHeader.SalesOrderID` | One row per order header | No detail join and no status/date exclusions. | **31,465** |
| Purchasing Customers | Registered customers with at least one order in the observed period. | `COUNT(DISTINCT CustomerID)` over order headers | `Sales.SalesOrderHeader.CustomerID` | Distinct customer | Customer IDs are non-NULL and all order customers match `Sales.Customer` in the prior quality checks. | **19,119** |
| Registered Customers Without Orders | Registered customers with no matching order header. | Count customers for which no header exists by `CustomerID` | `Sales.Customer.CustomerID`; `Sales.SalesOrderHeader.CustomerID` | One row per registered customer | Includes all registered customers, not just purchasers. | **701** |
| Average Order Value (AOV, raw) | Arithmetic mean of stored pre-tax, pre-freight subtotals per order. | `SUM(SubTotal) / COUNT(SalesOrderID)` | `Sales.SalesOrderHeader.SubTotal`, `SalesOrderID` | Order header | Uses all headers once. Because currency contexts are mixed and unconverted, this is not a comparable single-currency AOV. | **3,491.07 stored currency units per order (unconverted)** |
| Orders per Purchasing Customer | Average recorded orders per distinct customer who ordered. | `COUNT(order headers) / purchasing customers` | `Sales.SalesOrderHeader.SalesOrderID`, `CustomerID` | Order headers divided by distinct purchasing customers | Uses only customers with at least one order; this is a descriptive average, not a repeat-purchase interval. | **1.6457** |
| One-Time Customers | Purchasing customers with exactly one recorded order. | Count customers whose order-header count equals 1 | `Sales.SalesOrderHeader.CustomerID`, `SalesOrderID` | One row per purchasing customer | The count is only within this finite observed window. | **11,649** |
| Repeat Customers | Purchasing customers with at least two recorded orders. | Count customers whose order-header count is greater than 1 | `Sales.SalesOrderHeader.CustomerID`, `SalesOrderID` | One row per purchasing customer | "Repeat" means 2+ observed orders in the extract; it is not a churn definition. | **7,470** |
| Repeat Customer Rate | Share of observed purchasing customers with 2+ observed orders. | `Repeat Customers / Purchasing Customers` | Same order-header fields as above | Purchasing-customer population | Rounded to 2 decimal places for display. | **39.07%** |

The customer frequency calculation first produces one order count per registered `CustomerID`, then classifies those counts. It therefore includes zero-order customers in the separately reported registered-customer count without including them in the repeat-rate denominator.

## Validation and reconciliation

- `SUM(SubTotal)` across order headers is **109,846,381.4039 stored units, unconverted**.
- Independently summing `SalesOrderDetail.LineTotal` by order and then across orders gives **109,846,381.399888 stored units, unconverted**.
- Header subtotal minus line-total sum is **0.004012** overall; the largest absolute per-order difference is **0.000050**. **Zero** of 31,465 orders differ by more than one cent. This tiny precision difference supports using header subtotal for this baseline.
- `SUM(TotalDue)` is **123,216,786.1159 stored units, unconverted**, which is **13,370,404.7120** above subtotal. `TotalDue` also includes tax and freight, so it answers a different monetary question.
- The one-time and repeat customer counts reconcile to all purchasing customers: 11,649 + 7,470 = 19,119. Registered customers reconcile as 19,119 purchasers + 701 without orders = 19,820.
- Baseline order and customer counts are calculated directly from order headers, not from a header-to-detail join. This prevents line multiplicity from inflating orders or distinct customers.

## Monthly results

Revenue is monthly `SUM(SubTotal)`, orders are the count of order headers, and purchasing customers are distinct `CustomerID` values within each month. Monthly customer counts are not additive across months because the same customer may purchase in multiple months.

| Order month | Raw subtotal before tax/freight (unconverted stored units) | Orders | Purchasing customers |
|---|---:|---:|---:|
| 2011-05 | 503,805.9169 | 43 | 43 |
| 2011-06 | 458,910.8248 | 141 | 141 |
| 2011-07 | 2,044,600.0034 | 231 | 231 |
| 2011-08 | 2,495,816.7335 | 250 | 250 |
| 2011-09 | 502,073.8458 | 157 | 157 |
| 2011-10 | 4,588,761.8160 | 327 | 327 |
| 2011-11 | 737,839.8214 | 230 | 230 |
| 2011-12 | 1,309,863.2511 | 228 | 228 |
| 2012-01 | 3,970,627.2790 | 336 | 336 |
| 2012-02 | 1,475,426.9100 | 219 | 219 |
| 2012-03 | 2,975,748.2385 | 304 | 304 |
| 2012-04 | 1,634,600.7984 | 269 | 269 |
| 2012-05 | 3,074,602.8138 | 293 | 293 |
| 2012-06 | 4,099,354.3572 | 390 | 390 |
| 2012-07 | 3,417,953.8699 | 385 | 385 |
| 2012-08 | 2,175,637.2180 | 285 | 285 |
| 2012-09 | 3,454,151.9405 | 352 | 352 |
| 2012-10 | 2,544,091.1056 | 321 | 321 |
| 2012-11 | 1,872,701.9762 | 383 | 383 |
| 2012-12 | 2,829,404.8189 | 378 | 378 |
| 2013-01 | 2,087,872.4623 | 400 | 400 |
| 2013-02 | 2,316,922.1516 | 325 | 325 |
| 2013-03 | 3,412,068.9676 | 441 | 441 |
| 2013-04 | 2,532,265.9123 | 428 | 428 |
| 2013-05 | 3,245,623.7551 | 428 | 426 |
| 2013-06 | 5,081,069.1319 | 719 | 713 |
| 2013-07 | 4,896,353.7386 | 1,740 | 1,675 |
| 2013-08 | 3,333,964.0677 | 1,789 | 1,727 |
| 2013-09 | 4,532,908.7054 | 1,791 | 1,741 |
| 2013-10 | 4,795,813.2898 | 1,968 | 1,893 |
| 2013-11 | 3,312,130.2457 | 2,103 | 2,041 |
| 2013-12 | 4,075,486.6257 | 2,050 | 1,970 |
| 2014-01 | 4,289,817.9514 | 2,141 | 2,073 |
| 2014-02 | 1,337,725.0356 | 1,756 | 1,713 |
| 2014-03 | 7,217,531.0920 | 2,399 | 2,342 |
| 2014-04 | 1,797,173.9230 | 2,115 | 2,058 |
| 2014-05 | 5,366,674.9693 | 2,411 | 2,350 |
| 2014-06 | 49,005.8400 | 939 | 898 |

These monthly values reflect the observed rows only and are unconverted across currency contexts. May 2011 is partial at the start of the observed date range. The maximum observed date is June 30, 2014, but a month-end maximum alone does not prove the source captured the full month.
