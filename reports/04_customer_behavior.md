# Phase 4: Customer behavior analysis

## Scope and population

This phase moves from company totals to the behavior of purchasing customers. The behavior dataset has one row per customer with at least one observed order. The **701 registered customers with zero orders remain separate** because they have no observed purchase timeline. Source tables are read-only; the SQL uses `Sales.SalesOrderHeader` at one row per order and does not join order lines into customer-level counts or values.

The observed order period is **2011-05-31 through 2014-06-30**. The fixed dataset end is **2014-06-30**. Counts from Phase 3 establish **19,119 purchasing customers**, **31,465 orders**, **11,649 one-time customers**, and **7,470 repeat customers**. The SQL in this phase is designed to recheck these totals against the live database.

## Customer-level field definitions

The generated rowset is the first result set of [01_customer_behavior.sql](../sql/04_customer_analysis/01_customer_behavior.sql).

| Field | Meaning |
|---|---|
| `CustomerID` | AdventureWorks customer key. |
| `FirstOrderDate` | Earliest observed `OrderDate` for this customer in the extract. |
| `LastOrderDate` | Latest observed `OrderDate` for this customer in the extract. This is not evidence that the customer left. |
| `OrderCount` | Count of observed order-header rows for the customer. |
| `TotalPurchaseValue` | Sum of the customer’s order-header `SubTotal` values, before tax and freight, each counted once. Values are stored amounts and are not FX-converted. |
| `AverageOrderValue` | Arithmetic mean of the customer’s order-header `SubTotal` across observed orders, with the same stored-currency limitation. |
| `CustomerLifetimeDays` | Calendar-day boundaries between first and last observed order (`DATEDIFF(day)`). It is 0 for a customer whose observed orders fall on the same date or who has one order; it is not the customer's full relationship tenure. |
| `DaysFromLastOrderToDatasetEnd` | Calendar-day boundaries from the last observed order date to the fixed 2014-06-30 observation cutoff. This describes the gap inside this extract only; it is neither a churn label nor evidence of post-cutoff behavior. |

## Order-frequency distribution

The frequency result set in [01_customer_behavior.sql](../sql/04_customer_analysis/01_customer_behavior.sql) returned this complete distribution. Percentages are of 19,119 purchasing customers and round to 100.000% in total.

| Orders per customer | Customers | % of purchasers |
|---|---:|---:|
| 1 | 11,649 | 60.929% |
| 2 | 5,473 | 28.626% |
| 3 | 1,204 | 6.297% |
| 4 | 386 | 2.019% |
| 5 | 70 | 0.366% |
| 6–10 | 228 | 1.193% |
| 11+ | 109 | 0.570% |
| **All purchasers** | **19,119** | **100.000%** |

The Phase 3 repeat group contains 7,470 customers with at least two orders, or **39.07%** of purchasers. The frequency buckets should sum to 19,119 customers and 100% (subject to displayed rounding).

## First and last purchase behavior

The summary result set in [01_customer_behavior.sql](../sql/04_customer_analysis/01_customer_behavior.sql) returned the date ranges and lifetime/gap statistics below. Date fields show their observed minima and maxima; day-count fields include minimum, median, mean, and maximum.

| Measure | Minimum | Median | Mean | Maximum |
|---|---:|---:|---:|---:|
| `FirstOrderDate` | 2011-05-31 | 2013-09-25 | — | 2014-06-30 |
| `LastOrderDate` | 2011-05-31 | 2014-01-16 | — | 2014-06-30 |
| `CustomerLifetimeDays` | 0 days | 0 days | 168.555 days | 1,089 days |
| `DaysFromLastOrderToDatasetEnd` | 0 days | 165 days | 190.267 days | 1,126 days |

The query calculates median dates by taking the median of the underlying datetime values; date means are not included. Day-count means are shown to three decimals from the SQL results. In particular, `DaysFromLastOrderToDatasetEnd` is measured only through June 30, 2014; its spread partly reflects the fixed observation cutoff and does not establish that a customer stopped purchasing afterward.

## Purchase intervals

[02_purchase_intervals.sql](../sql/04_customer_analysis/02_purchase_intervals.sql) uses `LAG()` within each customer, ordered by `OrderDate` and `SalesOrderID`, to compare each purchase with the prior purchase. The interval is calendar-day boundaries between consecutive order dates. Separate orders on the same date produce a zero-day interval. One-order customers contribute no interval.

| Measure | Result |
|---|---:|
| Customers with measurable repeat intervals | 7,470 |
| Purchase intervals | 12,346 |
| Minimum interval | 0 days |
| 25th percentile | 91 days |
| Median (50th percentile) | 138 days |
| 75th percentile | 411 days |
| 90th percentile | 634.5 days |
| Mean interval | 261.024 days |
| Maximum interval | 1,089 days |

Interval distribution can help describe observed timing and inform a later retention discussion. It does not itself establish an appropriate inactivity threshold; the data are finite, and repeated orders may reflect differing product and customer needs.

## Return within fixed follow-up windows

[03_return_windows.sql](../sql/04_customer_analysis/03_return_windows.sql) includes a customer in a given window only when their first observed order is on or before **2014-06-30 minus the full window length**. A return is a later order strictly after the first order and on or before the first order plus the window. This provides each eligible first purchase the same complete follow-up opportunity for that window. A customer can be eligible for shorter windows but not longer ones.

| Follow-up after first observed purchase | Eligible customers | Returned within window | Return rate |
|---|---:|---:|---:|
| 30 days | 18,574 | 360 | 1.938% |
| 60 days | 17,437 | 624 | 3.579% |
| 90 days | 16,300 | 902 | 5.534% |
| 180 days | 13,134 | 1,897 | 14.443% |
| 365 days | 6,206 | 1,992 | 32.098% |

These rates measure observed repeat purchasing within the extract for customers with sufficient follow-up. They are not churn rates and do not say what customers did after the cutoff.

## Validation and reconciliation

The final result set in [01_customer_behavior.sql](../sql/04_customer_analysis/01_customer_behavior.sql) checks the customer-level aggregation against source orders. The prior baseline provides the values to reconcile:

| Check | Phase 3 baseline | Phase 4 status |
|---|---:|---|
| Purchasing customers | 19,119 | **Match** |
| Order count assigned to purchasers | 31,465 | **Match** |
| One-time customers | 11,649 | **Match** |
| Repeat customers (2+ orders) | 7,470 | **Match** |
| Sum of customer purchase values | 109,846,381.4039 stored monetary units, unconverted | **Matches** Phase 3 summed `SubTotal` exactly to four decimal places |

All three Phase 4 SQL files executed successfully on the final run. The return-window query initially failed because SQL Server disallows aggregating an expression containing a subquery; the same eligibility and return rule was retained with a row-level return flag, and the corrected file executed successfully. The customer behavior query also reports median first and last purchase dates. The validation result set confirms that customer aggregation preserves the full order count and purchasing-customer population. Summing the customer-level `TotalPurchaseValue` reconciles exactly to the Phase 3 header `SubTotal` total at the reported precision; this is an arithmetic reconciliation of unconverted stored amounts, not a consolidated-currency revenue result.

## Limitations

- The stored `SubTotal` values mix currency contexts. Phase 3 found 13,976 orders with a `CurrencyRateID`, covering six foreign-currency pairs; no FX conversion convention has been selected. Customer values are therefore **unconverted stored amounts**, not consolidated revenue. `SubTotal` is before tax and freight.
- The extract spans 2011-05-31 to 2014-06-30 only. A last observed order is not proof of inactivity afterward, much less churn.
- The first observed order may not be the customer's true first-ever purchase; purchases before this extract are not established by the analysis.
- Calendar-day `DATEDIFF` counts date boundaries, so timestamps within one day do not create fractional-day intervals. Same-date distinct orders yield a 0-day interval.
- All orders have `Status = 5` in the prior baseline and no status filter is applied here. Confirm status meaning before treating the resulting histories as an approved business population.
- Return rates are conditional on the complete follow-up eligibility rule and are not directly comparable without considering each window's eligible population.

## Plain-language interpretation

Almost six in ten purchasing customers have only one recorded order in the available history. Among customers with at least two orders, the median observed gap is 138 days, while the mean is 261 days; the long upper tail makes the mean much larger than the median. These are observed intervals, not an inactivity rule. Customers with no linked orders are a separate registered population and should not be folded into post-purchase behavior measures.

Among first purchases with enough follow-up, observed return rates range from 1.938% within 30 days to 32.098% within 365 days. The eligible population shrinks as the requested follow-up period grows, so the rates have different denominators. The June 2014 cutoff limits what can be said about recent first purchases and last purchases. No customer is labeled churned in this phase.

## Questions for the retention phase

1. What business follow-up horizon is appropriate for customers with different purchase patterns or product needs?
2. Should the initial purchase cohort be limited to customers whose first order is observed in this extract, given possible pre-2011 purchases?
3. Is the full order history captured consistently across all channels and across the sharp volume rise beginning July 2013?
4. Which reporting currency and conversion rate convention should govern value comparisons?
5. What is the approved meaning of order status 5, and does it represent the transactions that should count as purchases?
6. How should repeat behavior be interpreted for customers whose multiple orders occur on the same date?

## Five key takeaways

1. The purchasing population is 19,119 customers; the 701 registered customers without observed orders remain separate.
2. One-time purchasers are the largest group: 11,649 customers, or 60.929%; 7,470 customers have repeat orders.
3. The 12,346 repeat intervals have a median of 138 days, a mean of 261.024 days, and a 90th percentile of 634.5 days.
4. Among customers eligible for full follow-up, 360 of 18,574 returned within 30 days (1.938%); 1,992 of 6,206 returned within 365 days (32.098%).
5. The customer value total reconciles to 109,846,381.4039 stored unconverted `SubTotal` units. The 2014-06-30 cutoff limits observation; no churn definition or label is introduced here.
