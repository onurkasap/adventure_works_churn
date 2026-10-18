# Phase 3: Baseline business analysis

## Key findings

- The source contains **19,820 registered customers**. Of these, **19,119** have at least one recorded order and **701** have none. The registered-customer base and purchasing-customer base are different populations.
- There are **31,465 orders** across **121,317 order lines**. Order and customer measures were counted from order headers; detail lines were not joined into those counts.
- There are **11,649 one-time purchasers** and **7,470 repeat purchasers** (2+ observed orders). Repeat purchasers are **39.07%** of purchasing customers within this observation window. This describes observed frequency only; it is not a churn measure.
- Summed order-header `SubTotal` is **109,846,381.4039 stored monetary units, unconverted**. It excludes tax and freight, but it cannot yet be presented as one consolidated-currency revenue total because 13,976 order headers reference currency rates for six foreign-currency pairs. The arithmetic AOV, **3,491.07 stored units per order**, has the same limitation.
- `TotalDue` sums to **123,216,786.1159 stored monetary units, unconverted**. It is not interchangeable with `SubTotal`: the difference is **13,370,404.7120** in stored amounts, reflecting tax and freight as well as any currency context.
- Independent reconciliation is strong at the stored precision: summed detail `LineTotal` is **109,846,381.399888**, only **0.004012** below header `SubTotal` overall. No order differs by more than one cent.
- Every observed order header has `Status = 5`. The status code was observed in the data, but this analysis did not apply a status filter or infer additional status meanings.

## Monthly movement

The monthly query uses `OrderDate`; it returns 38 observed months from May 2011 to June 2014. Order counts and distinct monthly purchasers generally rise over the period: monthly orders increase from **43** in the first observed month to a peak of **2,411** in May 2014. The first month begins on May 31, so it is a partial month. June 2014 has 939 orders; the maximum date is June 30, but that alone does not establish whether the source contains a complete month.

There is a sharp change in volume between June and July 2013: orders rise from **719 to 1,740**, and purchasing customers rise from **713 to 1,675**. Monthly recorded subtotals vary substantially and are unconverted across currency contexts, so they should not be interpreted as a clean comparable-currency growth trend yet. Check whether the volume shift reflects a source coverage or business process change before explaining it.

The full monthly result set is in [03_kpi_definitions.md](03_kpi_definitions.md) and can be regenerated with [02_monthly_kpis.sql](../sql/03_kpi/02_monthly_kpis.sql).

## Plain-language interpretation

AdventureWorks has a substantial group of customers who never appear in the order table and a larger group with only one observed purchase. Around 4 in 10 purchasing customers made multiple recorded purchases during the available history. That is a useful starting baseline for customer analysis, but it does not indicate how many customers are currently active or have actually left.

The number of orders and customers rises markedly from mid-2013 onward. Before drawing a business conclusion from that increase-or from monthly revenue-confirm that the data capture and currency treatment are consistent throughout the period.

## Caveats

- The raw monetary sums and AOV mix rows with and without `CurrencyRateID`. Currency pairs observed are USD to AUD, USD to CAD, USD to DEM, USD to EUR, USD to FRF, and USD to GBP. Because `AverageRate` and `EndOfDayRate` are both available, a consolidated-currency rule must be agreed and applied before these figures are called comparable total revenue, AOV, or revenue growth.
- `SubTotal` is the selected pre-tax, pre-freight field; `TotalDue` includes tax and freight. Neither field alone establishes accounting-recognized net revenue or return/refund handling.
- All observed order headers have `Status = 5`; confirm the business interpretation of this code if the database is refreshed or the source includes other statuses.
- The observed transaction window is finite (2011-05-31 to 2014-06-30). Customers near the end of the window have less follow-up, so a final purchase date is not proof of churn.
- The **39.07%** repeat rate is bounded by this historical window. Customers with one order may have purchased before or after it; registered customers with no order may have no purchase record in this extract.
- This phase establishes baseline metrics only. It does not define churn, assign churn labels, or analyze cohorts/RFM.

## Questions for the next customer/retention phase

1. Which reporting currency should be used, and should conversion use `AverageRate` or `EndOfDayRate`? What is the correct direction and treatment of orders with no `CurrencyRateID`?
2. What is the business-approved interpretation of `Status = 5`, and should any status be excluded if future source data includes additional values?
3. Does the sharp order/customer increase beginning July 2013 reflect a real business change, a channel/source coverage change, or another data collection change?
4. Should the customer population for later retention work include only customers whose first purchase is observed in this extract, or also registered customers without orders and customers possibly active before the observed period?
5. What observation cutoff and minimum follow-up period should be used later so customers near the end of the data are compared fairly?
