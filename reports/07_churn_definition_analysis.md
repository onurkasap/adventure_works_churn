# Phase 7: Churn definition analysis

## The churn problem in this dataset

AdventureWorks records orders, not an explicit customer cancellation or churn event. For this non-subscription purchase history, these terms are different:

- **Inactivity** is an observed period with no order.
- **Long recency** is the number of days since the last order observed by a specified cutoff.
- **Observed non-return** means no order occurred in a fully observed, explicitly defined follow-up window.
- **Analytically defined churn** is a chosen rule, such as no order for a specified period after a snapshot date. It is an inference for analysis, not a source fact.
- **Confirmed churn** would require business evidence that the relationship ended. The order table cannot confirm this.
- **Right censoring** occurs when the observation period ends before the time needed to determine a future outcome. At the fixed 2014-06-30 cutoff, a customer whose last order was 90 days earlier has not had 180 days of observable inactivity. Even a customer already inactive for 540 observed days may return after the extract ends.

Therefore a last purchase near 2014-06-30 cannot be called churned based on unobserved future behavior. In the snapshot tables, “threshold reached” reports elapsed inactivity only; “censored” means fewer than the candidate number of days elapsed by the data end. Neither category is a final churn label.

The validated population remains **19,119 purchasers**, including **11,649 one-time customers (60.929%)** and **7,470 repeat customers (39.071%)**. The 701 registered customers with no observed orders remain separate. The interval distribution and customer recency below were recalculated from the live, read-only database through 2014-06-30.

## Candidate inactivity thresholds

Completed repeat intervals number **12,346**. Their median is **138 days**, P75 is **411 days**, P90 is **634.5 days**, and mean is **261.024 days**. All three candidate thresholds exceed the median and fall below P90:

| Candidate | Relative to gap distribution | Completed gaps longer than threshold | Repeat customers with at least one completed gap longer than threshold | Snapshot: inactivity reached by cutoff | Below threshold / censored at cutoff |
|---:|---|---:|---:|---:|---:|
| 180 days | Above median, below P75 | 5,526 / 12,346 (44.759%) | 5,318 / 7,470 (71.191%) | 8,816 | 10,303 |
| 365 days | Above median, below P75 (near the one-year mark) | 3,486 / 12,346 (28.236%) | 3,486 / 7,470 (46.667%) | 1,050 | 18,069 |
| 540 days | Above P75, below P90 | 2,184 / 12,346 (17.690%) | 2,184 / 7,470 (29.237%) | 459 | 18,660 |

“Gap longer than threshold” is based on a completed interval between consecutive observed orders. Every such interval ends in a later observed order by construction. This is the share of historical completed gaps that would have crossed a threshold and then returned, and a measure of **premature churn risk** if one treated threshold crossing as permanent departure. It is not a production classifier false-positive rate. A customer might be inactive at the threshold date and later reactivate.

180 days is longer than the median repeat interval but shorter than P75, and more than seven in ten repeat customers had at least one completed gap beyond it. 365 days is still below P75, and almost half of repeat customers had a completed gap beyond it. At 540 days, fewer completed gaps and customers cross the threshold, but 29.237% of repeat customers still demonstrate a later return after such a gap. Longer thresholds reduce this particular premature-return risk while sharply reducing the number who have even reached the threshold by the cutoff.

## Return after threshold: interval and customer results

| Threshold | Completed intervals | Intervals > threshold and followed by purchase | Share of completed intervals | Customers with ≥1 such gap and later return | Share of repeat customers |
|---:|---:|---:|---:|---:|---:|
| 180 days | 12,346 | 5,526 | 44.759% | 5,318 | 71.191% |
| 365 days | 12,346 | 3,486 | 28.236% | 3,486 | 46.667% |
| 540 days | 12,346 | 2,184 | 17.690% | 2,184 | 29.237% |

The customer count is the number of distinct repeat purchasers with at least one completed gap above the threshold; its denominator is 7,470 repeat customers. The interval denominator is 12,346 completed gaps. Incomplete final gaps do not enter this return-after-threshold calculation because no later purchase has yet completed them; their censoring is shown separately below.

## One-time and repeat customers

Current recency through the cutoff differs between the two full-extract groups:

| Full-extract group | Customers | Min days | P25 | Median | P75 | P90 | Mean | Max days |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| One-time (one order in full extract) | 11,649 | 0 | 94 | 188 | 285 | 348 | 209.645 | 1,126 |
| Repeat (2+ orders in full extract) | 7,470 | 0 | 73 | 134 | 226 | 313 | 160.050 | 911 |

One-time customers have older current recency at the median than repeat customers, but their lack of a second observed order is bounded by the available history. It is not evidence that they will never purchase again. Repeat customers have a median recency of 134 days, close to the 138-day median completed interval; the long interval tail means some repeat buyers return after much longer periods.

For first-purchase follow-up, eligibility means the extract contains the full candidate number of days after the first observed purchase. These are fixed-window behavior checks, not current churn labels:

| Threshold | One-time eligible / censored | One-time with no observed second order in full window | Repeat eligible / censored | Repeat with return within threshold | All-purchaser eligible / censored |
|---:|---:|---:|---:|---:|---:|
| 180 days | 6,070 / 5,579 | 6,070 | 7,064 / 406 | 1,897 | 13,134 / 5,985 |
| 365 days | 740 / 10,909 | 740 | 5,466 / 2,004 | 1,992 | 6,206 / 12,913 |
| 540 days | 398 / 11,251 | 398 | 4,035 / 3,435 | 1,858 | 4,433 / 14,686 |

These counts use the customer's first observed purchase as the anchor and require complete follow-up. The one-time/repeat group is defined from the entire extract and is used only retrospectively for this descriptive comparison; it must not be used as a historical feature because it can depend on later orders. Phase 4's validated 365-day return result is recovered: 1,992 of 6,206 eligible first purchases returned within the year (32.098%).

## Snapshot eligibility and right censoring at 2014-06-30

For each purchaser, calculate `RecencyDays = DATEDIFF(day, LastOrderDate, 2014-06-30)`. For candidate T:

- **Inactivity reached by cutoff:** `RecencyDays >= T`. The database has observed at least T days without another order. Whether the customer returns after the cutoff is unknown.
- **Below threshold / censored:** `RecencyDays < T`. The extract ends before T days of post-order inactivity can be observed. Do not assign churn or non-churn from this lack of follow-up.

| Threshold | One-time reached | Repeat reached | Total reached | One-time censored | Repeat censored | Total censored |
|---:|---:|---:|---:|---:|---:|---:|
| 180 days | 6,070 | 2,746 | 8,816 | 5,579 | 4,724 | 10,303 |
| 365 days | 740 | 310 | 1,050 | 10,909 | 7,160 | 18,069 |
| 540 days | 398 | 61 | 459 | 11,251 | 7,409 | 18,660 |

Reached and censored groups are mutually exclusive and sum to 19,119 at every threshold. “Reached” is not equivalent to confirmed churn: later behavior is not observed. The fixed first-purchase follow-up eligibility table above answers a different question and should not be mixed with this last-order snapshot classification.

## Historical cutoff design for future prediction work

The following designs provide complete 365-day future windows inside the extract. Customers enter only if they had at least one order by the feature cutoff. The outcome diagnostic is whether they had any order during the next 365 days; “no observed return” is not yet an approved churn label.

| Feature cutoff | Feature history available | Future outcome window | Historical purchasers / eligible | Observed return | No observed return in 365 days |
|---|---|---|---:|---:|---:|
| 2012-06-30 | 2011-05-31–2012-06-30 (about 13 months) | 2012-07-01–2013-06-30 | 2,799 | 457 | 2,342 |
| 2013-06-30 | 2011-05-31–2013-06-30 (about 25 months) | 2013-07-01–2014-06-30 | 6,206 | 5,156 | 1,050 |

Both outcome windows are fully observed through the fixed end date. The 2013 cutoff is useful because it tests outcomes across the sharp July 2013 volume shift, but the large difference in observed return share (5,156/6,206 versus 457/2,799) may reflect the unresolved source/data-structure shift as well as behavior. Do not pool or interpret these outcomes until order capture consistency around July 2013 is investigated. The 2012 design is a pre-shift sensitivity case, though its feature history is shorter and its eligible base smaller. These designs are not an instruction to build a model now.

### Data leakage rules

For any future historical snapshot, recompute all features using orders on or before its feature cutoff only:

| Field from Phases 4/6 | Safe only when recalculated as of cutoff? | Leakage risk if current 2014-06-30 value is reused |
|---|---|---|
| RecencyDays | Yes: cutoff minus last order at/before cutoff | Includes time and last order after a historical cutoff. |
| Frequency / total observed orders | Yes: count orders at/before cutoff | Includes future orders and outcomes. |
| LastOrderDate | Yes: maximum order date at/before cutoff | Can reveal post-cutoff purchasing. |
| FirstOrderDate | Usually available by cutoff for included historical purchasers; still recompute within the permitted data and population | Later-acquired customers must not appear in the historical snapshot. |
| CustomerLifetimeDays | Yes: first-to-last dates using only orders at/before cutoff | Full-extract last order can leak future activity. |
| RF segment and R/F scores | Recalculate scores and segment thresholds on cutoff-only features | Phase 6 scores use orders/recency through 2014-06-30 and leak later history into earlier snapshots. |
| MonetaryRaw / AOV | If used, recalculate only from pre-cutoff orders and resolve currency first | Current full-history sums include future orders; currency comparability remains unresolved. |

The registered-customer table is a current snapshot. Unless customer registration dates can be established, a historical customer population should be defined from observed purchasers on/before the cutoff rather than assuming every currently registered customer existed then.

## Threshold comparison and recommendation

| Threshold | Advantage | Disadvantage | Premature-return risk among repeat customers | Snapshot reached / censored |
|---:|---|---|---:|---:|
| 180 days | More customers have enough observed inactivity by cutoff; shorter follow-up requirement | Less than half of P75 gap; many long but completed returns cross it | High: 71.191% have at least one later return after a >180-day gap | 8,816 / 10,303 |
| 365 days | Understandable year-long inactivity window; close to Phase 4's validated 365-day first-purchase follow-up; less short than 180 days | Below P75 gap; almost half of repeat buyers later returned after at least one such gap | Material: 46.667% have at least one later return after a >365-day gap | 1,050 / 18,069 |
| 540 days | Above P75, below P90; lowest return-after-threshold proportion among candidates | Still 29.237% of repeat customers later return after such a gap; only 459 customers have reached it by cutoff | Lower than the other candidates, not negligible | 459 / 18,660 |

**Recommendation: use 365 days as a provisional portfolio-analysis threshold for the next methodology step, not as a confirmed or operational churn definition.** It is a clear one-year period, lies between the median and P75 observed gap, and can be evaluated with the validated Phase 4 fixed-window evidence. Its weakness is material: many repeat customers have later returned after gaps longer than a year, and 18,069 of 19,119 customers have not yet accumulated 365 days of observed inactivity at this cutoff. The next analysis must preserve an unknown/censored category and separate return/reactivation after threshold from the snapshot state.

This recommendation is not a claim that one year is right for every product, customer type, or business use. A company’s operational churn rule requires domain validation, channel coverage checks, and a decision about whether later return means reactivation or disproves the prior churn state. If the project needs a status as of the dataset end, it can only describe observed inactivity reaching 365 days versus insufficient follow-up; it cannot establish future permanence.

## Validation

| Check | Result |
|---|---:|
| Purchasing population | 19,119 (matches Phases 3–6) |
| One-time / repeat purchasers | 11,649 / 7,470 (matches Phase 4 and Phase 6) |
| Completed repeat intervals | 12,346 across 7,470 repeat customers |
| Repeat interval median / P75 / P90 / mean | 138 / 411 / 634.5 / 261.024 days (matches Phase 4) |
| Snapshot reached + censored at each threshold | 19,119 (all three thresholds) |
| Historical cutoff outcome windows | End 2013-06-30 and 2014-06-30; both within source cutoff |
| Post-cutoff events used for feature measures | None in historical cutoff query; outcomes are isolated to future windows |
| Customers labeled churned | None |

The queries use only read operations. Historical feature aggregates filter orders at or before the candidate cutoff; future orders are queried only in the separate outcome calculation. The source contains no churn label, so all outcomes remain methodology diagnostics.

## Limitations and plain-language interpretation

- The extract starts 2011-05-31 and ends 2014-06-30; customers can have purchases outside this extract.
- Purchase timing has a long tail. A long gap can be followed by another order, particularly for buyers with infrequent purchase needs.
- Return-after-threshold results describe completed historical intervals only. A trailing gap with no next order is right-censored, not a completed non-return.
- Current snapshot “reached threshold” counts do not reveal what happened after the cutoff.
- The July 2013 increase in orders and customers remains unexplained and materially affects the historical 2013 cutoff outcome window.
- The one-time/repeat split uses all observed history and is retrospective; it is not a safe feature for an earlier snapshot.
- All prior observed orders have `Status = 5`, but its business meaning remains unverified. This analysis applies no status filter.

In plain language, 180 days looks short for this portfolio: long gaps are common, and most repeat buyers have at least one gap over 180 days followed by another order. A year is a reasonable provisional analysis window, but a substantial share of repeat customers also returned after a year-long gap. Waiting 540 days reduces observed later-return risk but leaves very few customers reaching that inactivity duration by the 2014 cutoff. Most customers are therefore unknown for long-horizon status at the end of this extract.

## Five most important findings

1. Churn is not recorded. Inactivity and long recency are observable; confirmed churn and post-cutoff behavior are not.
2. Of 12,346 completed repeat gaps, **44.759% exceed 180 days**, **28.236% exceed 365 days**, and **17.690% exceed 540 days**, each ending in an observed return.
3. At the 2014-06-30 snapshot, inactivity had reached 180/365/540 days for **8,816 / 1,050 / 459** purchasers; the remaining **10,303 / 18,069 / 18,660** are censored below those thresholds.
4. One-time customers have median recency **188 days**, compared with **134 days** for repeat customers; one-time status alone still does not show what they will do later.
5. A **365-day** threshold is recommended provisionally for the next analytical step, with explicit unknown/reactivation treatment. For future prediction design, 2013-06-30 offers a 365-day outcome window but crosses the unexplained July shift; pair it with the 2012-06-30 pre-shift sensitivity design and investigate data capture before modeling.

## Explicit conclusions

1. **Can a preferred threshold be defended?** A provisional project threshold can be defended for sensitivity work, but no definitive operational churn threshold is established by these data.
2. **Recommended definition candidate:** no observed purchase for 365 days after a defined customer snapshot, interpreted only as an analytical inactivity proxy; report later returns/reactivations separately.
3. **Who remains unknown/censored?** At the 2014-06-30 snapshot, 18,069 purchasers have less than 365 days since their last observed order. Even among the 1,050 who have reached 365 days, post-cutoff return is unknown.
4. **Future historical cutoff design:** use a 2013-06-30 feature cutoff with a 2013-07-01–2014-06-30 outcome window, and a 2012-06-30 cutoff with a 2012-07-01–2013-06-30 window as a pre-shift sensitivity case. Recompute every feature as of its own cutoff and investigate the July 2013 capture/structure change before comparing or modeling outcomes.

No final production churn label, statistical test, or ML model was created.
