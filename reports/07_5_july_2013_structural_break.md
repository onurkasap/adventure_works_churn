# Phase 7.5: July 2013 structural-break investigation

## Executive finding

Several substantial, measurable changes coincide with the rise beginning in June/July 2013: customer acquisition and orders increase, growth is concentrated in `OnlineOrderFlag = 1` and customers linked as Person only, product mix shifts sharply toward accessories (especially tires/tubes), order baskets become smaller on average, and discount-line share falls. Most territories continue to be represented; no new territory or order/customer ID block appears at the break.

The historical return-rate discrepancy is real and independently reconciled. It is **not** caused by post-cutoff customer acquisition leaking into the baseline population. The same 2,799 customers in the 2012 cutoff population have 457 returns in the following year (16.327%) and 2,312 returns in the next year (82.601%). The return change is especially large among person-only customers whose first observed order was online. This strongly supports caution about different pre/post data regimes, but the available fields do not establish whether the cause is business behavior, sales process, source coverage, or another mechanism.

**Evidence classification: B) Several measurable changes are associated with the break, but no single cause can be established.** Treat the periods as potentially different regimes in later churn and statistical/ML work until source coverage and business meaning are clarified.

## Scope, grains, and definitions

All queries are read-only and use the verified `AdventureWorks2022` schema. The fixed observation cutoff is **2014-06-30**. A “new customer” means first observed order in this extract, which begins 2011-05-31; it does not prove a true first-ever purchase or registration date. Order counts and active customers use `SalesOrderHeader` grain. Product/category and discount analyses use `SalesOrderDetail` line grain; where lines can multiply customers, the SQL uses distinct customer keys.

The customer’s assigned `Sales.Customer.TerritoryID` is used for customer acquisition composition. `SalesOrderHeader.TerritoryID` is used for the territory recorded on an order. These represent different fields and are not substituted for each other. Customer-type categories reflect the nullable `PersonID` and `StoreID` links only; they are not interpreted as B2B/B2C.

Matched comparisons use equal six-month windows, January–June and July–December 2013. Broader before/after totals are shown only as context because their observation periods differ in length. Monetary totals and raw unit prices are not interpreted as consolidated currency values.

## Timing and scale of the break

The validated monthly sequence shows the first signs before July, followed by a higher level from July onward:

| Month 2013 | Orders | Active purchasers | First-observed purchasers | Repeat purchasers active that month |
|---|---:|---:|---:|---:|
| Jan | 400 | 400 | 295 | 105 |
| Feb | 325 | 325 | 252 | 73 |
| Mar | 441 | 441 | 308 | 133 |
| Apr | 428 | 428 | 328 | 100 |
| May | 428 | 426 | 353 | 73 |
| Jun | 719 | 713 | 303 | 410 |
| Jul | 1,740 | 1,675 | 1,284 | 391 |
| Aug | 1,789 | 1,727 | 1,168 | 559 |
| Sep | 1,791 | 1,741 | 1,089 | 652 |
| Oct | 1,968 | 1,893 | 1,143 | 750 |
| Nov | 2,103 | 2,041 | 1,154 | 887 |
| Dec | 2,050 | 1,970 | 1,053 | 917 |

From June to July, orders rose **719 to 1,740**, active purchasers rose **713 to 1,675**, and the first-observed cohort rose **303 to 1,284**. The June–December 2013 matched comparison gives 2,741 versus 11,441 orders (456.8 versus 1,906.8 per month) and 1,839 versus 6,891 new purchasers. Orders per active customer stayed near one in each month (about 1.00–1.04); the volume increase is mainly more customers/orders, not a large rise in monthly orders per active customer.

Weekly counts show a transition already visible in the week beginning **June 24, 2013**: 336 orders and 333 active customers, compared with 121 orders and 121 customers in the prior week. First-observed purchasers rose from 54 in the week beginning June 17 to 151 in the week beginning June 24 and 278 in the week beginning July 1. Orders then remained around 337–382 in the first four full July weeks before the week beginning July 29 reached 529 (which includes the first August days). Thus July is the clear new monthly level, but the first weekly increase occurs in late June; timing alone cannot identify why.

The monthly totals also reconcile: January–June 2013 sum to **2,741**, and the six months July–December sum to **11,441**. June and July first-observed cohorts reproduce the prior validated **303** and **1,284** counts.

## Channel: online versus offline

The verified `OnlineOrderFlag` is non-null and present throughout the extract. In matched 2013 windows:

| Window | Flag | Orders | Active customers in channel | First-observed customers | Order share | New-customer share |
|---|---:|---:|---:|---:|---:|---:|
| Jan–Jun | 0 (offline flag) | 697 | 445 | 112 | 25.429% | 6.090% |
| Jan–Jun | 1 (online flag) | 2,044 | 1,978 | 1,727 | 74.571% | 93.910% |
| Jul–Dec | 0 (offline flag) | 901 | 471 | 96 | 7.875% | 1.393% |
| Jul–Dec | 1 (online flag) | 10,540 | 9,264 | 6,795 | 92.125% | 98.607% |

Channel-specific customer counts can overlap if a customer uses both flags, so they should not be summed as if customers were exclusive. The monthly detail shows the change: online orders rose from **533 in June to 1,564 in July**, while offline-flag orders went from **186 to 176**. First-observed customers by first-order flag moved from **231 online and 72 offline in June** to **1,196 online and 88 offline in July**. The acquisition increase is therefore concentrated in online-flag orders. This is observed field behavior, not proof of a channel launch or a business intervention.

The order-level field coverage also shows `SalesPersonID` and `PurchaseOrderNumber` are NULL on online-flag orders in the 2013 monthly checks, while their null counts equal the online order count. These fields align with the channel flag in this extract; their correlation is not evidence of a new pipeline by itself.

## Customer structure: Person and Store links

Using the validated nullable customer links:

| First-observed period | Person only | Both Person and Store | Store only |
|---|---:|---:|---:|
| Jan–Jun 2013 | 1,727 | 112 | 0 |
| Jul–Dec 2013 | 6,795 | 96 | 0 |

This is first-observed purchaser composition. Across the full registered base, the source has 18,484 Person-only customers, 635 with both links, and 701 Store-only customers; all 701 Store-only records are the previously validated zero-order population. The observed acquisition jump is overwhelmingly Person-only, but the schema supports no stronger B2B/B2C interpretation.

## Geography and territory mix

All ten territories in the validated territory table were already represented in the order history before the break; none first appears in July 2013. Acquisition territory below uses the customer’s assigned territory and matched six-month windows:

| Customer territory | Jan–Jun new customers | Share | Jul–Dec new customers | Share |
|---|---:|---:|---:|---:|
| Australia | 578 | 31.430% | 1,043 | 15.136% |
| Southwest (US) | 290 | 15.769% | 1,715 | 24.888% |
| Germany | 223 | 12.126% | 623 | 9.041% |
| United Kingdom | 214 | 11.637% | 742 | 10.768% |
| Northwest (US) | 213 | 11.582% | 1,307 | 18.967% |
| France | 210 | 11.419% | 629 | 9.128% |
| Canada | 89 | 4.840% | 803 | 11.653% |
| Southeast (US) | 8 | 0.435% | 14 | 0.203% |
| Northeast (US) | 7 | 0.381% | 9 | 0.131% |
| Central (US) | 7 | 0.381% | 6 | 0.087% |

Growth is broad across existing territories, with a composition shift: Southwest, Northwest, and Canada account for larger shares in the later matched window, while Australia’s share declines. Order territory is separately reported in the SQL; for example, order counts rose in both Southwest and Australia. The geography is not concentrated in a newly represented region, and these territory fields do not explain a cause.

## Product and category mix

The product join preserves the validated detail relationship through `SpecialOfferProduct` on both `SpecialOfferID` and `ProductID`, then joins product/subcategory/category. Equal six-month line-level comparison:

| Category | Jan–Jun lines | Share of lines | Jan–Jun units | Jul–Dec lines | Share of lines | Jul–Dec units |
|---|---:|---:|---:|---:|---:|---:|
| Bikes | 6,418 | 41.067% | 16,741 | 10,067 | 24.587% | 21,007 |
| Components | 4,283 | 27.406% | 12,000 | 4,855 | 11.857% | 12,707 |
| Clothing | 3,027 | 19.369% | 15,822 | 7,239 | 17.680% | 21,358 |
| Accessories | 1,900 | 12.158% | 6,812 | 18,784 | 45.876% | 25,341 |
| **All categories** | **15,628** | **100%** | **51,375** | **40,945** | **100%** | **80,413** |

Accessory lines grew markedly in both count and share. Tires and tubes are a major component: 328 lines and 465 units in Jan–Jun versus 8,600 lines and 8,821 units in Jul–Dec. Mountain Tire Tube alone moved from 32 to 1,562 lines at essentially the same stored unit price (~4.99); Road Tire Tube moved 47 to 1,173 lines at ~3.99. This is strong evidence of a product-mix change, not evidence of a price or marketing cause.

New-customer first-order category counts also shift: Jan–Jun first-order customers associated with Bikes/Accessories/Clothing/Components were 1,783/219/129/96; Jul–Dec counts were 1,649/5,791/2,348/83. A customer can have multiple categories in their first order, so these category counts are not additive cohort sizes. The later new-customer wave is disproportionately associated with accessory and clothing lines.

## Price, discount, and order characteristics

Matched detail-line comparison:

| Measure | Jan–Jun 2013 | Jul–Dec 2013 |
|---|---:|---:|
| Order lines | 15,628 | 40,945 |
| Units | 51,375 | 80,413 |
| Discounted lines | 988 (6.322%) | 944 (2.306%) |
| Mean line discount fraction | 0.604% | 0.190% |
| Median line discount fraction | 0% | 0% |
| Mean units per line | 3.287 | 1.964 |
| Median units per line | 2 | 1 |

Line volume increased about 2.6×, but discounted line count was slightly lower and its share fell. Median discount was zero in both periods. Mean and median units per line also fell. At order grain, mean lines per order declined from 5.70 to 3.58, mean quantity from 18.74 to 7.03 units, and mean unique products from 5.70 to 3.58; medians were 1 line/1 unit before versus 2 lines/2 units after, reflecting a highly skewed pre-period basket distribution. The share of active customers with a prior observed order in the matched period rose from 647/2,423 (26.7%) to 3,568/9,735 (36.7%). Same-day multiple orders remain rare (6 versus 27 customers).

Completed intervals whose later order falls in Jan–Jun versus Jul–Dec 2013 numbered 902 versus 4,550. Their median gaps were 92 and 177 days; P75 was 271 and 455.75 days. This reflects a changed mix/timing of completed repeat orders and should be interpreted with the larger regime shift in mind.

`UnitPrice` and `LineTotal` are monetary fields in unresolved currency contexts. Product-matched comparisons were inspected, and the SQL provides raw prices by product and by presence of `CurrencyRateID`, but this does not establish a common currency. `Product.ListPrice` and `StandardCost` are current, non-time-versioned fields; they cannot prove historical price/cost at the order date. No consolidated price or revenue conclusion is drawn.

## Special offers

The detail rows predominantly use offer ID 1 (“No Discount”): 92.206% of Jan–Jun lines and 95.526% of Jul–Dec lines. Offer IDs 13 and 14 have descriptions “Touring-3000 Promotion” and “Touring-1000 Promotion” and date ranges May 30–August 29, 2013; both appear on either side of July (ID 13: 261 versus 263 lines; ID 14: 129 versus 115). Their share falls as total lines grow. Offer 11 (“Sport Helmet Discount-2003”) ended June 29 and appears in Jan–Jun only (84 lines), consistent with its recorded end date. New-customer first-order usage of ID 13 was 56 versus 58 customers and ID 14 was 62 versus 49. The data show offer descriptions and usage, not a campaign strategy or cause of the structural change.

## Historical return-rate anomaly: high-priority validation

The return calculation was independently rebuilt two ways:

1. Select distinct customers with at least one order on or before the cutoff, then use `EXISTS` for an order in the following 365 days.
2. Join the pre-cutoff distinct customer population to future orders, count distinct returning customers, and reconcile the same denominator.

Both methods give the same values. The baseline population is anchored before each cutoff, so customers acquired after the cutoff cannot enter its return numerator or denominator.

| Feature cutoff | Existing customers at cutoff | Returned existing customers next year | No observed return | Rate |
|---|---:|---:|---:|---:|
| 2012-06-30 | 2,799 | 457 | 2,342 | 16.327% |
| 2013-06-30 | 6,206 | 5,156 | 1,050 | 83.081% |

There were 3,407 first-observed customers acquired during the 2012 cutoff’s outcome year and 12,913 acquired during the 2013 cutoff’s outcome year. Those are explicitly excluded from the respective cutoff baseline populations. Decomposing the 2013 baseline by acquisition vintage:

| First-observed vintage within 2013 cutoff population | Customers | Returned Jul 2013–Jun 2014 | Rate |
|---|---:|---:|---:|
| By 2012-06-30 | 2,799 | 2,312 | 82.601% |
| 2012-07-01–2013-06-30 | 3,407 | 2,844 | 83.475% |
| **Total** | **6,206** | **5,156** | **83.081%** |

Most importantly, the same 2,799 customers in consecutive outcome years had **457/2,799 (16.327%)** return in July 2012–June 2013 and **2,312/2,799 (82.601%)** return in July 2013–June 2014. Therefore the difference is not just a larger or newer 2013 baseline cohort and cannot be explained by post-cutoff acquisitions leaking into the count.

The change is strongly associated with first-order customer structure/channel. Within those same 2,799 customers, Person-only customers whose first order was online went from **191/2,468 (7.739%)** returned in 2012–13 to **2,097/2,468 (84.968%)** in 2013–14. Customers linked to both Person and Store whose first order was offline went from **266/331 (80.363%)** to **215/331 (64.955%)**. In the 2013 cutoff population, Person-only/online-first customers returned at 84.183%, while both-linked/offline-first customers returned at 71.402%.

Pre-cutoff product-category membership is associated with different rates too, but categories overlap at customer level. For the 2012 baseline, customers with prior Bikes lines returned at 15.565% versus 87.037% for Accessories; for the 2013 baseline the corresponding figures are 83.483% and 49.211%. This reversal and the channel/vintage findings indicate that period and customer composition matter. They do not establish a single explanation.

## Data-capture and schema-artifact checks

**Observed facts:**

- `SalesOrderID` values progress continuously by month in 2013: June spans 51,203–51,921 and July 51,922–53,661. No ID reset or gap aligned to July was observed.
- First-observed purchaser ID ranges overlap: pre-July customers span 11,000–30,118 and July-onward customers 11,012–30,097. There is no separate customer-ID block at the break.
- `Status <> 5` remains zero in every 2013 month. Channel, `SalesPersonID`, and `PurchaseOrderNumber` coverage track each other; no abrupt field nulling independent of channel was seen in the monthly check.
- All ten order territories appear before the break; no new country/region or territory first appears in July.
- `OnlineOrderFlag` exists throughout the extract, while its share changes from 74.571% of orders in Jan–Jun 2013 to 92.125% in Jul–Dec.
- The valid order-detail product/category join shows an abrupt change in product mix; discount and offer fields remain populated.

**Plausible interpretation:** The coordinated changes in online share, customer structure, product mix, order size, and the same-customer return rate are consistent with a different data/behavior regime beginning around late June/July 2013. The available tables cannot distinguish a business change from a source coverage/process change or another mechanism.

**Unsupported explanations:** These results do not establish a marketing campaign, online-channel launch, customer-growth initiative, pipeline migration, or causal effect. No source field records those explanations.

## Implications for churn and future ML analysis

- Do not pool pre- and post-July outcomes without checking source consistency and including period/regime sensitivity in any later analysis.
- Report the 2013–14 return pattern as a distinct observed regime until its cause is investigated; do not use its 83% rate as a stable portfolio baseline.
- Historical cutoff features and outcomes must remain separated. The return validation here uses post-cutoff orders only for the outcome and excludes customers first acquired after each cutoff from that cutoff’s baseline.
- If future modeling is approved, recompute all features as of each historical cutoff, evaluate pre/post regime stability, and consider time-based validation. The large post-July shift is a material comparability risk.
- This investigation creates no churn label and does not establish that any customer churned.

## Limitations and evidence classification

- First-observed acquisition is constrained by the 2011-05-31 extract start and is not registration date or verified first-ever purchase.
- The 2014-06-30 endpoint censors later customer behavior.
- Customer and channel counts in channel-specific tables can overlap across flags; distinct customers are used within each group.
- Product category customer counts can overlap because a customer can purchase multiple categories.
- Territory assignment and order territory answer different questions.
- Monetary comparability is unresolved, so raw amounts/prices are not used to explain growth.
- The structural changes are observed associations. No causal test or business-source evidence was available in the validated tables.

## Five most important findings

1. The transition is visible in late June and becomes a new level in July: orders increase 719→1,740 and first-observed purchasers 303→1,284; the week beginning June 24 already has 336 orders and 151 first-observed purchasers.
2. The matched-period acquisition jump is concentrated online: online share rises 74.571%→92.125% of orders and 93.910%→98.607% of new purchasers; first-order customer structure is overwhelmingly Person only.
3. Product mix shifts sharply toward Accessories (12.158%→45.876% of lines), especially tires/tubes, while Bikes share falls; average basket size and discount-line share also decline.
4. The 365-day return anomaly is independently validated and not population leakage: the same 2,799 customers move from 16.327% returns in 2012–13 to 82.601% in 2013–14. The shift is concentrated in the person-only/online-first group.
5. Several dimensions change together, but no single cause is established. Classify the evidence as **B** and treat pre/post data cautiously as potentially different regimes in later churn/statistical/ML analysis.

No churn labeling, statistical testing, or machine learning was performed.
