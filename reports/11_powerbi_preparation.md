# Phase 11: Power BI data model and dashboard preparation

## Work completed

Prepared ten SELECT-only SQL Server extraction/validation files under `sql/11_powerbi/`, semantic-model and DAX documentation, a five-page dashboard specification, and a Desktop import guide. The SQL follows validated prior phase logic for header/line grain, 2014-06-30 RF scores, exact-month cohorts, historical 365-day non-return snapshots, and July 2013 structural-break reporting. It avoids monetary fields in reporting outputs.

The model design uses FactOrders at SalesOrderHeader grain and FactOrderLines at SalesOrderDetail grain, with dimensions for customer, product and territory. Date is created in Power BI. Cohort and snapshot facts remain disconnected from a report date dimension so slicers cannot silently recalculate fixed historical denominators or introduce leakage. Current product/customer attributes have explicit historical validity caveats.

## Validated figures to reconcile after import

| Measure | Validated result |
|---|---:|
| Registered customers | 19,820 |
| Purchasing customers | 19,119 |
| Registered customers with zero orders | 701 |
| Order headers | 31,465 |
| Order detail lines | 121,317 |
| One-time purchasers | 11,649 |
| Repeat purchasers | 7,470 |
| Repeat customer rate | 39.07% |
| Weighted exact-month retention M1 / M3 / M6 / M12 | 1.863% / 5.387% / 5.986% / 10.055% |
| A_2012 eligible / returned / non-return | 2,799 / 457 / 2,342 |
| B_2013 eligible / returned / non-return | 6,206 / 5,156 / 1,050 |
| A_2012 later returned among non-returners | 2,003 / 2,342 |
| Customer overlap between eligible A_2012 and B_2013 populations | 2,799 (all A customers also occur in B) |

## Important interpretation boundaries

Registered customers include non-purchasers; purchasing customers are distinct order-header customers in the observation period. One-time and repeat are full-window order-frequency classes. Monthly active customers are distinct within a month and are not additive across months. RF scores are a fixed 2014-06-30 RF snapshot, not full RFM and not churn. Cohort retention is activity in an exact calendar month divided by the original cohort size; future unobservable cells are NULL, not zero, and exact-month retention is not cumulative return within a year. Historical no-return labels are period-specific proxies, not permanent churn; A/B should be shown separately. No ML score is approved as an operational risk indicator.

Several measurable changes coincide around late June/July 2013, including order/customer volume, online flag mix, customer structure, category mix and non-monetary basket size. The data does not establish a single cause. Use matched Jan-Jun and Jul-Dec comparisons and do not claim a campaign, migration, or website launch.

Stored SubTotal, TotalDue, UnitPrice, and AOV lack a validated common-currency interpretation. The primary report excludes consolidated monetary KPIs and revenue conclusions.

## Execution and status

This preparation created SQL and documentation only. No AdventureWorks data was modified. No CSV/Parquet exports were generated. No `.pbix` was created or verified in Power BI Desktop; report construction and visual validation remain. Import FactOrders first, then the dimensions and line fact, followed by snapshot/aggregate tables as detailed in `powerbi/import_guide.md`.

SQL execution status: the ten files `01_fact_orders.sql` through `10_validation.sql` were executed successfully against the configured AdventureWorks2022 connection. Dataset results returned 31,465 orders, 121,317 lines, 19,820 customers, 504 products, 10 territories, 19,119 RF rows, 494 cohort cells, 9,005 historical snapshot rows, and 38 monthly rows. The validation query and separate read-only reconciliations confirmed 19,119 purchasers, 701 zero-order registered customers, snapshot labels, and weighted retention M1/M3/M6/M12 of 1.863%/5.387%/5.986%/10.055%. The connection attempt initially failed in the sandbox; the successful run used the approved outside-sandbox connection. Credentials were not printed or added to project files.
