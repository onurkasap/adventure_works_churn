# Phase 6: RF customer segmentation

## Scope and RFM definitions

This phase uses the 19,119 customers with at least one observed order. The 701 registered customers with no observed order remain separate because they have no purchase behavior to score. All calculations stop at **2014-06-30** and use one `Sales.SalesOrderHeader` row per order.

| Measure | Definition |
|---|---|
| RecencyDays | Calendar-day boundaries between the customer's last observed order and 2014-06-30. A low value means a more recent observed order. |
| Frequency | Number of observed order headers for the customer. |
| MonetaryRaw | Sum of `SubTotal` for the customer's observed orders. Stored monetary amount, not currency converted. |
| AverageOrderValueRaw | Mean `SubTotal` per observed order. Stored monetary amount, not currency converted. |
| CustomerLifetimeDays | Calendar-day boundaries between first and last observed order; this describes only the observed extract. |

All customers have at least one order, so the customer-level values are defined. Monetary values are before tax and freight, and are not treated as directly comparable customer value. No activity after the cutoff is inferred.

## R, F, and M distributions

Percentiles are customer-level continuous percentiles. `MonetaryRaw` figures below are stored, unconverted amounts.

| Measure | Minimum | P25 | Median | P75 | P90 | Mean | Maximum |
|---|---:|---:|---:|---:|---:|---:|---:|
| RecencyDays | 0 | 85 | 165 | 263 | 339 | 190.267 | 1,126 |
| Frequency | 1 | 1 | 1 | 2 | 3 | 1.646 | 28 |
| MonetaryRaw (stored, unconverted) | 1.374 | 54.980 | 548.980 | 2,822.386 | 5,873.260 | 5,745.404 | 877,107.192 |

Frequency reproduces Phase 4: 11,649 customers (60.929%) had one observed order, and 7,470 (39.071%) had multiple orders. Counts by exact frequency were: 1: 11,649; 2: 5,473; 3: 1,204; 4: 386; 5: 70; 6: 24; 7: 37; 8: 149; 9: 10; 10: 8; 11: 10; 12: 64; 16: 14; 17: 7; 25: 1; 27: 11; 28: 2.

Recency has a longer upper tail: its mean (190 days) exceeds its median (165), and some customers' last order predates the cutoff by more than three years. This is time since the last order inside the extract, not confirmed churn. Frequency is strongly concentrated at one order, with a long but sparse tail to 28. The unconverted monetary distribution is highly right-skewed: its mean is over ten times the median, and a small number of large raw totals dominate the upper tail. Currency differences make those monetary comparisons unsuitable for customer-value ranking.

Phase 4 found 12,346 consecutive-purchase intervals, a median of 138 days, mean of 261.024 days, and 90th percentile of 634.5 days. That long interval tail reinforces why elapsed time should be described as behavior rather than used to call a customer churned.

## Currency investigation and decision

Live catalog inspection confirmed the declared foreign key `Sales.SalesOrderHeader.CurrencyRateID` → `Sales.CurrencyRate.CurrencyRateID`. `CurrencyRate` contains `FromCurrencyCode`, `ToCurrencyCode`, `CurrencyRateDate`, `AverageRate`, and `EndOfDayRate`; the order header contains nullable `CurrencyRateID` and `SubTotal`, but no currency-code column.

Observed orders with a rate reference: **13,976**. Their joined rate rows use **USD** as the source and six destination codes in this extract: AUD, CAD, DEM, EUR, FRF, and GBP. Both average and end-of-day rates are populated. Another **17,489** orders have a NULL `CurrencyRateID`, spanning the full observed date range. The database relationship and data show the direction encoded in each rate row, but they do not establish which currency units `SubTotal` is stored in for each header, whether NULL means USD, or which rate convention the business intends for customer comparisons. Choosing a multiplication/division rule or assigning null-rate orders to USD would therefore go beyond the available evidence.

**Decision: defer M scoring.** The report and segments use RF scores only. `MonetaryRaw` and `AverageOrderValueRaw` remain descriptive stored amounts. Phase 3's overall raw `SubTotal` total of **109,846,381.4039** matches this base table's customer-level MonetaryRaw total exactly; that is an arithmetic reconciliation, not a currency-normalized total. A common-currency rule requires an approved interpretation of order amount currency, rate direction/application, rate convention, and NULL-rate handling.

## R and F scoring method

### Recency

Recency uses interpolated 20th, 40th, 60th, and 80th percentile cutpoints across customers. Lower recency receives the higher score. A `CASE` rule assigns the same RecencyDays value the same score, including at cutpoint ties; consequently score sizes can be slightly uneven.

| R score | RecencyDays rule | Customers |
|---:|---|---:|
| 5 | ≤ 71 | 3,867 |
| 4 | > 71 and ≤ 129 | 3,813 |
| 3 | > 129 and ≤ 204 | 3,814 |
| 2 | > 204 and ≤ 288 | 3,821 |
| 1 | > 288 | 3,804 |

The observed percentile cutpoints are 71, 129, 204, and 288 days. Higher score means more recent last observed activity. A low score does not mean confirmed churn.

### Frequency

A customer-row `NTILE(5)` would split the 11,649 customers tied at exactly one order across score groups, making identical purchase histories receive different scores. Instead, all equal frequencies receive the same monotonic score using transparent order-count bands:

| F score | Frequency rule | Customers |
|---:|---|---:|
| 1 | 1 order | 11,649 |
| 2 | 2 orders | 5,473 |
| 3 | 3 orders | 1,204 |
| 4 | 4–5 orders | 456 |
| 5 | 6 or more orders | 337 |

The F score bands are intentionally unequal. They preserve the large single-order group and maintain consistent treatment for equal frequency values. Frequency score 5 is a broad upper band because exact counts above five are sparse and have gaps.

## Final RF segments

Rules combine the Recency and Frequency scores into six readable, mutually exclusive groups. Names describe observed purchase history only.

| Segment | Rule | Customers | % of purchasers | Median RecencyDays | Median Frequency | Repeat-customer share |
|---|---|---:|---:|---:|---:|---:|
| Highly engaged repeat buyers | R ≥ 4 and F ≥ 4 | 623 | 3.259% | 78 | 5 | 100.000% |
| Repeat buyers, longer since purchase | R ≤ 3 and F ≥ 4 | 170 | 0.889% | 426 | 4 | 100.000% |
| Recent developing repeat buyers | R ≥ 4 and F = 2–3 | 3,011 | 15.749% | 71 | 2 | 100.000% |
| Developing repeat buyers, longer gap | R ≤ 3 and F = 2–3 | 3,666 | 19.175% | 221 | 2 | 100.000% |
| Recent one-time buyers | R ≥ 4 and F = 1 | 4,046 | 21.162% | 71 | 1 | 0.000% |
| One-time buyers, longer since purchase | R ≤ 3 and F = 1 | 7,603 | 39.767% | 254 | 1 | 0.000% |
| **All purchasing customers** |  | **19,119** | **100.000%** |  |  | **39.071%** |

### Business reading

- **Highly engaged repeat buyers:** the most recent, higher-frequency group. They are a small share of the base and may be useful for learning which customer/order patterns accompany continued purchasing.
- **Repeat buyers, longer since purchase:** 170 customers have at least four orders but a relatively long recency. Their observed history is substantial, while their last observed purchase is older; elapsed time is not proof they left.
- **Recent developing repeat buyers:** 3,011 customers have two or three orders and are among the more recently observed purchasers. These histories can help describe a path toward more frequent ordering.
- **Developing repeat buyers, longer gap:** 3,666 customers have two or three orders but are less recent. Their segment median recency (221 days) is above the 138-day median repeat interval from Phase 4, which makes them a group to examine for follow-up opportunities, not a churned group.
- **Recent one-time buyers:** 4,046 customers have one observed order and a median recency of 71 days. They may be appropriate for analysis of second-purchase timing.
- **One-time buyers, longer since purchase:** the largest group, 7,603 customers. They have one observed order and a median recency of 254 days. Their lack of a second observed order is bounded by the extract and does not establish churn.

## Relationship to July 2013 acquisition cohorts

This exploratory split uses the month of first observed order: before July 2013 versus July 2013 or later. Counts below describe where each RF segment's customers came from; they do not explain the July volume shift or establish a causal relationship.

| Segment | Before July 2013 | July 2013 or later |
|---|---:|---:|
| Highly engaged repeat buyers | 407 | 216 |
| Repeat buyers, longer since purchase | 153 | 17 |
| Recent developing repeat buyers | 1,926 | 1,085 |
| Developing repeat buyers, longer gap | 2,980 | 686 |
| Recent one-time buyers | 0 | 4,046 |
| One-time buyers, longer since purchase | 740 | 6,863 |
| **All customers** | **6,206** | **12,913** |

The later acquisition period accounts for most one-time buyers with longer recency because that period contains far more customers overall (the Phase 5 cohorts jump from 303 in June 2013 to 1,284 in July 2013). Conversely, the recent one-time segment can only include customers whose observed first and last order is recent, so all 4,046 fall in the later period. These are mechanical consequences of cohort size and the score definitions; they should not be read as evidence of different campaign response or customer quality.

## Validation

The live query results and prior phase findings reconcile as follows:

| Check | Result |
|---|---:|
| Purchasing customers in base and segments | 19,119 |
| Unique customers assigned a segment | 19,119 |
| Customers assigned exactly once / more than once | 19,119 / 0 |
| Segment counts sum to purchasing customers | 19,119 |
| Frequency summed across customers | 31,465 orders |
| One-time / repeat customers | 11,649 / 7,470 (matches Phase 4) |
| Negative RecencyDays | 0; minimum is 0 |
| Customer-level MonetaryRaw sum | 109,846,381.4039 stored unconverted units (matches Phase 3 header subtotal) |
| Registered customers with zero orders | 701, kept outside segmentation |

The base aggregation groups all in-cutoff order headers once by `CustomerID`. The segment validation is run on the actual assigned segment rows, and confirms one segment per purchasing customer. Segment counts and customer-level orders reconcile to Phases 3–4.

## Limitations

- The extract begins 2011-05-31, so first observed orders may not be customers' true first-ever purchases.
- The cutoff is 2014-06-30. Recency is only time since the last order observed by that date; future behavior is unavailable.
- This is a historical segmentation, not a current customer status or churn classification.
- R score thresholds depend on this extract's customer distribution. Frequency bands deliberately sacrifice equal-sized quintiles to avoid splitting identical order counts.
- Monetary totals mix currency contexts. No M score or customer-value comparison is used pending an approved and evidenced conversion convention.
- All observed headers had `Status = 5` in prior phases; the business meaning has not been confirmed and no status filter is applied here.

## Five most important findings

1. The segmentation covers **19,119 purchasers** and keeps the **701 customers without orders** separate; every purchaser is assigned exactly once.
2. Recency has a median of **165 days** (mean 190.267; maximum 1,126). This describes time since the last observed order through the cutoff, not confirmed churn.
3. Frequency remains concentrated: **60.929%** have one observed order and **39.071%** have multiple; tied frequency values are kept together in F scoring.
4. The largest segment is **One-time buyers, longer since purchase** (7,603, 39.767%); the **Recent one-time buyers** group contains 4,046 (21.162%). Both point to distinct histories for possible second-purchase analysis.
5. MonetaryRaw is strongly skewed and its **109,846,381.4039** total is unconverted across currency contexts. Since the order amount currency and NULL-rate treatment cannot be established from the available relationship, monetary scoring is deferred.

## Final result

**B) RF segmentation with Monetary deferred.** The existing schema links orders to rate rows, and those rows encode USD-to-destination pairs, but it does not identify the currency of each `SubTotal` or establish how to handle missing rate references and choose a rate convention for business comparisons. A final Monetary score would require assumptions not supported by the available evidence.

No churn definition, churn label, or ML model is introduced.
