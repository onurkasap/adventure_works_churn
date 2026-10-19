# Phase 5: Retention and cohort analysis

## Scope and definitions

This analysis uses read-only `Sales.SalesOrderHeader` order history through the fixed cutoff **2014-06-30**. Population is the **19,119 customers with at least one observed order**; the **701 registered customers with zero orders** remain separate and have no post-purchase cohort. This matches Phases 3–4 customer/order counts (31,465 orders, 19,119 purchasers, 11,649 one-order customers, 7,470 customers with multiple orders).

A customer's cohort is the calendar month of their first observed `OrderDate` in this extract. Since order history begins **2011-05-31**, first observed purchase may not be the customer's true first-ever purchase. Orders are counted at header grain. A customer is active in a month if they have at least one order in that month; multiple orders in the same customer/month count once. `MonthIndex` is the calendar-month difference from cohort month. Retention is monthly activity in that specific month, not cumulative return by that month; therefore month rates may rise and fall.

A cell is observable only when its target calendar month is no later than June 2014. Unobservable future cells are `NULL` in SQL and shown as `—` below; observed months with no active customers are 0%. The first observed May 2011 cohort is partial (history starts May 31). Amounts are excluded, so the unresolved currency issue does not affect these activity measures.

## Cohort sizes

The earliest cohort is **2011-05** (43 customers, partial month); the latest is **2014-06** (545 customers, with only MonthIndex 0 observable).

| CohortMonth | CohortSize |
|---|---:|
| 2011-05 | 43 |
| 2011-06 | 141 |
| 2011-07 | 231 |
| 2011-08 | 214 |
| 2011-09 | 157 |
| 2011-10 | 200 |
| 2011-11 | 230 |
| 2011-12 | 190 |
| 2012-01 | 194 |
| 2012-02 | 182 |
| 2012-03 | 219 |
| 2012-04 | 203 |
| 2012-05 | 265 |
| 2012-06 | 330 |
| 2012-07 | 345 |
| 2012-08 | 215 |
| 2012-09 | 226 |
| 2012-10 | 215 |
| 2012-11 | 318 |
| 2012-12 | 249 |
| 2013-01 | 295 |
| 2013-02 | 252 |
| 2013-03 | 308 |
| 2013-04 | 328 |
| 2013-05 | 353 |
| 2013-06 | 303 |
| 2013-07 | 1,284 |
| 2013-08 | 1,168 |
| 2013-09 | 1,089 |
| 2013-10 | 1,143 |
| 2013-11 | 1,154 |
| 2013-12 | 1,053 |
| 2014-01 | 1,075 |
| 2014-02 | 956 |
| 2014-03 | 1,134 |
| 2014-04 | 1,144 |
| 2014-05 | 1,168 |
| 2014-06 | 545 |

## Monthly cohort retention matrix

Values are retention percentages (`ActiveCustomers / CohortSize`). The companion SQL returns the long-form heatmap-ready data with cohort size, active count, and rate for all MonthIndex 0–12.

| CohortMonth | CohortSize | M0 | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 | M10 | M11 | M12 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2011-05 | 43 | 100.0% | 0.0% | 0.0% | 83.7% | 0.0% | 0.0% | 0.0% | 83.7% | 0.0% | 81.4% | 0.0% | 0.0% | 55.8% |
| 2011-06 | 141 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2011-07 | 231 | 100.0% | 0.0% | 0.0% | 31.6% | 0.0% | 0.0% | 30.3% | 0.0% | 31.2% | 0.0% | 0.0% | 21.6% | 0.0% |
| 2011-08 | 214 | 100.0% | 0.0% | 25.2% | 0.0% | 0.9% | 26.2% | 0.9% | 0.0% | 26.2% | 1.4% | 0.0% | 15.0% | 0.9% |
| 2011-09 | 157 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2011-10 | 200 | 100.0% | 0.0% | 0.0% | 8.0% | 0.0% | 6.5% | 4.5% | 0.0% | 5.0% | 3.5% | 0.0% | 4.5% | 3.5% |
| 2011-11 | 230 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2011-12 | 190 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.5% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2012-01 | 194 | 100.0% | 0.0% | 0.0% | 0.5% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2012-02 | 182 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2012-03 | 219 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2012-04 | 203 | 100.0% | 0.0% | 0.0% | 0.5% | 0.0% | 0.0% | 0.5% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% |
| 2012-05 | 265 | 100.0% | 0.0% | 0.0% | 16.2% | 0.0% | 0.0% | 14.3% | 0.0% | 0.0% | 15.5% | 0.0% | 0.0% | 12.1% |
| 2012-06 | 330 | 100.0% | 0.0% | 0.0% | 21.8% | 0.0% | 0.0% | 20.6% | 0.0% | 0.0% | 21.8% | 0.0% | 0.0% | 21.2% |
| 2012-07 | 345 | 100.0% | 0.0% | 0.0% | 19.4% | 0.0% | 0.0% | 17.7% | 0.0% | 0.0% | 17.7% | 0.0% | 1.2% | 17.1% |
| 2012-08 | 215 | 100.0% | 0.0% | 0.0% | 0.5% | 0.0% | 0.0% | 0.5% | 0.0% | 0.0% | 0.9% | 4.2% | 4.7% | 4.7% |
| 2012-09 | 226 | 100.0% | 0.0% | 0.0% | 1.8% | 0.0% | 0.0% | 2.2% | 0.0% | 0.0% | 3.5% | 1.3% | 5.3% | 10.2% |
| 2012-10 | 215 | 100.0% | 0.0% | 0.0% | 2.3% | 0.0% | 0.0% | 1.9% | 0.5% | 2.8% | 2.3% | 5.6% | 7.9% | 11.2% |
| 2012-11 | 318 | 100.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 4.7% | 1.9% | 3.8% | 2.5% | 8.5% | 13.2% |
| 2012-12 | 249 | 100.0% | 0.0% | 0.0% | 0.8% | 0.0% | 0.0% | 8.0% | 4.0% | 4.4% | 2.8% | 10.0% | 13.7% | 18.9% |
| 2013-01 | 295 | 100.0% | 0.0% | 0.0% | 0.0% | 0.7% | 6.8% | 9.2% | 6.8% | 6.8% | 7.5% | 12.5% | 12.2% | 19.0% |
| 2013-02 | 252 | 100.0% | 0.0% | 0.0% | 0.4% | 5.2% | 4.4% | 7.9% | 6.0% | 8.3% | 14.3% | 7.9% | 21.8% | 21.4% |
| 2013-03 | 308 | 100.0% | 0.0% | 0.3% | 3.9% | 2.6% | 4.9% | 1.9% | 3.6% | 16.2% | 4.5% | 7.1% | 19.2% | 20.8% |
| 2013-04 | 328 | 100.0% | 0.0% | 1.5% | 4.0% | 3.4% | 2.4% | 8.2% | 11.0% | 13.1% | 4.6% | 7.3% | 23.5% | 15.9% |
| 2013-05 | 353 | 100.0% | 2.5% | 3.1% | 14.2% | 2.3% | 4.0% | 13.3% | 11.9% | 6.8% | 7.6% | 17.8% | 20.1% | 15.3% |
| 2013-06 | 303 | 100.0% | 1.3% | 1.0% | 23.8% | 2.0% | 1.7% | 21.8% | 0.7% | 1.0% | 23.4% | 2.6% | 1.3% | 1.3% |
| 2013-07 | 1,284 | 100.0% | 5.6% | 5.3% | 11.2% | 5.1% | 5.8% | 11.4% | 4.4% | 5.8% | 5.8% | 12.0% | 5.0% | — |
| 2013-08 | 1,168 | 100.0% | 3.8% | 3.8% | 3.2% | 4.2% | 3.6% | 2.8% | 3.5% | 3.8% | 3.3% | 3.0% | — | — |
| 2013-09 | 1,089 | 100.0% | 2.8% | 3.5% | 3.4% | 3.0% | 3.0% | 3.5% | 2.3% | 2.7% | 3.2% | — | — | — |
| 2013-10 | 1,143 | 100.0% | 3.5% | 2.7% | 3.6% | 2.7% | 2.0% | 3.2% | 2.6% | 3.1% | — | — | — | — |
| 2013-11 | 1,154 | 100.0% | 2.0% | 2.7% | 3.2% | 3.8% | 2.7% | 2.7% | 2.2% | — | — | — | — | — |
| 2013-12 | 1,053 | 100.0% | 2.1% | 2.6% | 3.2% | 2.6% | 4.2% | 2.5% | — | — | — | — | — | — |
| 2014-01 | 1,075 | 100.0% | 1.6% | 3.3% | 2.2% | 3.1% | 2.1% | — | — | — | — | — | — | — |
| 2014-02 | 956 | 100.0% | 2.2% | 2.7% | 2.8% | 2.9% | — | — | — | — | — | — | — | — |
| 2014-03 | 1,134 | 100.0% | 2.0% | 2.3% | 2.3% | — | — | — | — | — | — | — | — | — |
| 2014-04 | 1,144 | 100.0% | 1.8% | 2.8% | — | — | — | — | — | — | — | — | — | — |
| 2014-05 | 1,168 | 100.0% | 1.7% | — | — | — | — | — | — | — | — | — | — | — |
| 2014-06 | 545 | 100.0% | — | — | — | — | — | — | — | — | — | — | — | — |

## Weighted retention summary

Weighted retention uses total active customers divided by total customers in eligible cohorts. Eligibility requires observing the entire horizon month through the dataset cutoff. Thus cohort sizes differ by horizon; rates are not unweighted averages of cohort percentages.

| Horizon | Eligible cohorts | Eligible customers | Active customers | Weighted retention |
|---|---|---:|---:|---:|
| Month 1 | 2011-05–2014-05 (37) | 18,574 | 346 | 1.863% |
| Month 3 | 2011-05–2014-03 (35) | 16,262 | 876 | 5.387% |
| Month 6 | 2011-05–2013-12 (32) | 13,097 | 784 | 5.986% |
| Month 12 | 2011-05–2013-06 (26) | 6,206 | 624 | 10.055% |

These are exact-month activity rates. Month 12 can exceed Month 6 because a customer may be active in Month 12 but not Month 6. Phase 4's 30/60/90/180/365-day return-within-window figures use a different definition (fixed day windows and returns strictly after first purchase); they should not be expected to match these calendar-month measures.

## Before/after July 2013 exploration

The observed monthly order/customer volume increased sharply around July 2013 in Phase 3. Here, first observed purchase cohorts are grouped before July 2013 versus July 2013 or later. These are descriptive weighted rates, not causal effects; the groups span different calendar periods and cohort composition, and possible source coverage change has not been resolved.

| Period | Horizon | Eligible cohorts | Eligible customers | Active | Weighted retention |
|---|---:|---|---:|---:|---:|
| Before July 2013 | 1 | 2011-05–2013-06 (26) | 6,206 | 13 | 0.209% |
| July 2013 or later | 1 | 2013-07–2014-05 (11) | 12,368 | 333 | 2.692% |
| Before July 2013 | 3 | 2011-05–2013-06 (26) | 6,206 | 469 | 7.557% |
| July 2013 or later | 3 | 2013-07–2014-03 (9) | 10,056 | 407 | 4.047% |
| Before July 2013 | 6 | 2011-05–2013-06 (26) | 6,206 | 472 | 7.606% |
| July 2013 or later | 6 | 2013-07–2013-12 (6) | 6,891 | 312 | 4.528% |
| Before July 2013 | 12 | 2011-05–2013-06 (26) | 6,206 | 624 | 10.055% |
| July 2013 or later | 12 | Not observable | — | — | — |

The one-month figure for the post-July group is higher, while Month 3 and Month 6 are lower than the pre-July group. Month 12 cannot be compared because no post-July cohort has a full 12-month observation window. Month 1's pre-July result is especially low; inspect order timing and capture consistency before interpreting the group difference. The phase 4 30-day return rate (1.938%) is not the same calculation.

## New-customer cohort size trend

| CohortMonth | CohortSize |
|---|---:|
| 2011-05 | 43 |
| 2011-06 | 141 |
| 2011-07 | 231 |
| 2011-08 | 214 |
| 2011-09 | 157 |
| 2011-10 | 200 |
| 2011-11 | 230 |
| 2011-12 | 190 |
| 2012-01 | 194 |
| 2012-02 | 182 |
| 2012-03 | 219 |
| 2012-04 | 203 |
| 2012-05 | 265 |
| 2012-06 | 330 |
| 2012-07 | 345 |
| 2012-08 | 215 |
| 2012-09 | 226 |
| 2012-10 | 215 |
| 2012-11 | 318 |
| 2012-12 | 249 |
| 2013-01 | 295 |
| 2013-02 | 252 |
| 2013-03 | 308 |
| 2013-04 | 328 |
| 2013-05 | 353 |
| 2013-06 | 303 |
| 2013-07 | 1,284 |
| 2013-08 | 1,168 |
| 2013-09 | 1,089 |
| 2013-10 | 1,143 |
| 2013-11 | 1,154 |
| 2013-12 | 1,053 |
| 2014-01 | 1,075 |
| 2014-02 | 956 |
| 2014-03 | 1,134 |
| 2014-04 | 1,144 |
| 2014-05 | 1,168 |
| 2014-06 | 545 |

Cohort sizes were generally 141–353 per full pre-July 2013 month (after the partial initial May 2011 month), with notable local highs in November 2012 (318), May 2013 (353), and June 2013 (303). July 2013 jumps to **1,284**, followed by 956–1,168 per full month through May 2014; June 2014 is 545 and has only MonthIndex 0 available. This makes the July 2013 volume shift strongly visible in new-purchaser cohorts. It does not establish why the change occurred. The initial May 2011 count of 43 is not directly comparable because only May 31 onward is observed.

## Validation and reconciliation

Live query validation against AdventureWorks2022 returned:

| Check | Result |
|---|---:|
| Purchasing customers assigned a cohort (cohort rows) | 19,119 |
| Unique cohort customers | 19,119 |
| Phase 3/4 purchasing-customer count | 19,119 (match) |
| Registered customers without orders | 701 (separate) |
| Observed order headers | 31,465 (Phase 3/4 match) |
| Customers with a negative MonthIndex | 0 |
| Cohorts where MonthIndex 0 differs from cohort size | 0 |
| Duplicate customer/month pairs | 0 |

Distinct customer/order-month pairs are formed before activity counting, so each customer contributes at most once per cohort/month index. The matrix has 494 cells (38 cohorts × 13 indices); cells beyond June 2014 remain `NULL`, including July 2013 MonthIndex 12 and all later MonthIndex 12 values. The 701 zero-order records are excluded from the purchaser cohort denominator.

## Limitations

- First observed purchase can precede the customer's actual first purchase because the extract starts 2011-05-31; the first cohort month is partial.
- Observation ends 2014-06-30. Later cohort cells are right-censored and correctly left unobserved, not treated as zero.
- Activity means at least one order in an exact calendar month. It is not cumulative retention, a fixed-day return window, churn, or proof of customer relationship status.
- The post-July 2013 acquisition increase may reflect business growth, source/channel coverage, or another data process; this analysis cannot identify a cause.
- Period comparisons are exploratory and have different calendar cohort composition. The post-July Month 12 horizon is not observable.
- Prior phases observed every order has `Status = 5` but did not validate the business meaning of that status; this analysis applies no status filter.
- No monetary measures are used.

## Plain-language business interpretation

New-purchaser cohorts become much larger in July 2013, rising from 303 in June to 1,284 in July. The increase persists at roughly a thousand new purchasers in most months afterward, making new-customer acquisition a major contributor to the overall order/customer volume shift. The available data does not explain the change.

Among eligible purchasers, 346 of 18,574 were active in the calendar month immediately after their cohort month (1.863%); 876 of 16,262 were active at Month 3 (5.387%); 784 of 13,097 at Month 6 (5.986%); and 624 of 6,206 at Month 12 (10.055%). Those are exact-month snapshots, which is why the later horizon rates do not have to decrease monotonically. The pre/post comparison is mixed: post-July cohorts show higher Month 1 activity and lower Month 3/6 activity, while Month 12 is unavailable for a fair two-group comparison. Check source capture and cohort composition before treating this as a behavioral shift.

## Questions to investigate next

1. Did source coverage, sales channel, customer onboarding, or order capture change around July 2013?
2. Are pre-2013 and post-2013 customers and orders represented consistently in the extract?
3. Would cumulative return-by-horizon or fixed 30/90/180/365-day retention answer a more useful business question alongside exact calendar-month activity?
4. How should the partial May 2011 cohort and possible pre-extract customer histories be handled in future comparisons?
5. What business meaning should be assigned to order status 5 before any approved purchasing-population filter is considered?

## Five most important findings

1. All **19,119** purchasing customers map to exactly one first-observed-purchase cohort; the **701** registered customers without orders remain separate.
2. The cohort range is **May 2011–June 2014**; the initial May 2011 cohort is partial, and June 2014 contributes 545 customers with no future follow-up.
3. Month 1/3/6/12 weighted exact-month retention is **1.863% / 5.387% / 5.986% / 10.055%**, with eligible populations decreasing from 18,574 to 6,206.
4. New-purchaser cohort size rises from **303 in June 2013 to 1,284 in July 2013**, with roughly 956–1,168 in most full months through May 2014; the cause remains unknown.
5. Pre/post July 2013 retention comparisons are mixed (post group 2.692% at Month 1 vs 0.209% pre; 4.047% vs 7.557% at Month 3; 4.528% vs 7.606% at Month 6). Month 12 cannot be compared because post-July cohorts lack sufficient follow-up.

No churn definition, churn label, RFM scoring, or ML model is introduced.
