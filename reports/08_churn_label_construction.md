# Phase 8: Historical churn label construction and validation

## Purpose and interpretation

AdventureWorks records orders, not customer cancellation or a confirmed churn event. This phase constructs two historical analytical snapshots using the provisional 365-day rule from Phase 7. `AnalyticalChurn = 1` means **no observed order during the next fully observable 365 days**. `AnalyticalChurn = 0` means at least one order in that window. It is a non-return proxy, not confirmed or permanent churn.

An eligible customer has at least one order on or before the snapshot cutoff. The outcome interval is the next day through the date 365 days after the cutoff, inclusive. The fixed extract ends 2014-06-30, so both label windows are complete. Registered customers with zero orders are outside both purchasing snapshots; the 701 zero-order registered customers remain separate.

## Snapshot design and label distribution

| Snapshot | Feature cutoff | Outcome interval | Eligible | Returned (`AnalyticalChurn=0`) | No return (`AnalyticalChurn=1`) | No-return rate |
|---|---|---|---:|---:|---:|---:|
| A_2012 | 2012-06-30 | 2012-07-01–2013-06-30 | 2,799 | 457 (16.327%) | 2,342 (83.673%) | 83.673% |
| B_2013 | 2013-06-30 | 2013-07-01–2014-06-30 | 6,206 | 5,156 (83.081%) | 1,050 (16.919%) | 16.919% |

The outcome counts exactly reconcile with the independently validated Phase 7 and 7.5 results. The two snapshots are separate datasets, not a pooled modeling table. The sharp difference in labels is an observed period change and should not be interpreted as a stable long-run churn rate.

## Feature construction

Every feature is recomputed independently for each cutoff from `Sales.SalesOrderHeader` rows with `OrderDate < SnapshotDate + 1 day`. The historical customer row is created only from customers with such an order. The label query reads future orders in a separate `EXISTS` calculation; no future order columns are joined into the feature aggregates.

| Feature family | Measures included | Grain / handling |
|---|---|---|
| Purchase history | First/last order date as of cutoff, RecencyDays, Frequency, CustomerLifetimeDays, DaysSinceFirstOrder, one-order-so-far, repeat-so-far | One customer per snapshot. Recency and lifetime use calendar-day boundaries. |
| Purchase gaps | Mean and median days between consecutive observed orders | Null for a customer with fewer than two pre-cutoff orders; calculated with a date-ordered `LAG`. |
| Historical RF | Snapshot-specific R quintile cut points, tie-preserving R scores, explicit frequency bands, RF code and interpretable segment | No Monetary score. Frequency bands: 1, 2, 3, 4–5, 6+. Equal RecencyDays always receive the same R score; tied cut points can make groups unequal. |
| Channel | First and last `OnlineOrderFlag`, online/offline order counts, online order share | Uses only pre-cutoff orders. `OnlineOrderFlag` is a database field; it does not prove a particular website or business strategy. |
| Customer structure | Person only, Person and Store, Store only, neither/unknown | Based on current `Sales.Customer.PersonID` and `StoreID`. No Store-only purchasers were observed in either snapshot; this does not remove the 701 registered Store-only zero-order customers from their separate population. |
| Product and basket | Distinct product/category counts, dominant category, line shares for Bikes/Accessories/Clothing/Components, lines, quantity, mean lines/quantity/distinct products per order, discounted-line share | Uses detail rows from pre-cutoff orders and the validated composite `SpecialOfferProduct` join on offer and product IDs. Dominant category is highest line count, alphabetical tie-break. |

The customer-level label output in `06_churn_labels.sql` is one row per snapshot/customer. The supplementary feature files expose detailed component feature result sets. MonetaryRaw, SubTotal, UnitPrice, LineTotal, and AOV are excluded because a common-currency interpretation remains unresolved.

## Historical RF method

Recency is ranked separately inside each snapshot using interpolated P20/P40/P60/P80 cut points from `PERCENTILE_CONT`; lower recency is better, with scores 5 through 1. The `CASE` assignment uses `<=` cut points, so tied recency values are never split across scores. Report the actual cut points from `03_historical_rf_features.sql` alongside any later use; the thresholds are snapshot-specific.

Frequency uses fixed, interpretable, tie-preserving bands: 1 order = 1; 2 = 2; 3 = 3; 4–5 = 4; 6+ = 5. Segments combine these R and F scores. They are behavior summaries, not monetary value segments. The Phase 6 full-extract RF scores were not reused.

## Cutoff feature distributions and label profiles

The following values come from the assembled cutoff-only rows. Rates/means are descriptive; no formal statistical tests were run. Online share and discounts are averaged across customers, so each customer has equal weight in these customer-level means.

| Snapshot / label | Customers | Mean recency days | Mean frequency | One-order-so-far share | Mean online order share | Mean discounted-line share | Mean of customer average gap days* |
|---|---:|---:|---:|---:|---:|---:|---:|
| A_2012 / returned | 457 | 111.23 | 2.01 | 68.93% | 41.79% | 2.73% | 103.9 (n=142) |
| A_2012 / no observed return | 2,342 | 174.38 | 1.07 | 97.48% | 97.22% | 0.08% | 101.8 (n=59) |
| B_2013 / returned | 5,156 | 305.45 | 1.28 | 91.89% | 92.59% | 0.62% | 228.0 (n=418) |
| B_2013 / no observed return | 1,050 | 238.40 | 1.61 | 70.48% | 85.43% | 0.32% | 251.0 (n=310) |

\*Gap averages are averaged across customers with at least two pre-cutoff orders; single-order customers have no calculable interval. Their small eligible counts, especially in A, make this a descriptive comparison only.

Additional pre-cutoff customer-average category line shares show another reversal: among Snapshot A returners/non-returners, Bikes shares were 67.2%/99.0% and Accessories shares 3.7%/0.1%; in Snapshot B the corresponding shares were 94.0%/73.8% Bikes and 1.8%/15.4% Accessories. These are customer-level averages, and categories can coexist within one customer. They are descriptive associations, not explanations for later returns.

This reversal is substantial: in Snapshot A, non-returners were typically more recent and had higher pre-cutoff online share than returners, while in Snapshot B the non-returners were less recent and had higher frequency than returners. These are associations within two different periods and customer mixes. They do not establish why customers returned.

| Cutoff-only population measure | A_2012 | B_2013 |
|---|---:|---:|
| Mean customer online-order share | 88.17% | 91.38% |
| Person only | 2,468 (88.17%) | 5,671 (91.38%) |
| Person and Store | 331 (11.83%) | 535 (8.62%) |
| Store only among purchasers | 0 | 0 |
| Mean distinct products per customer | 3.54 | 3.57 |
| Mean distinct categories per customer | 1.23 | 1.26 |
| Mean customer Bikes line share | 93.81% | 90.57% |
| Mean customer Accessories line share | 0.69% | 4.08% |
| Mean lines per order | 2.73 | 2.31 |
| Mean quantity per order | 7.34 | 5.64 |

Pre-cutoff characteristics have already changed between snapshots: the later snapshot has a higher average online share and a larger Accessories line share, and somewhat smaller order baskets by these averages. Snapshot A’s returned group also has a much higher frequency and lower online share than its non-return group. Snapshot B shows the opposite direction for those label profiles. The broader matched-period Phase 7.5 comparison found the stronger shift in activity starting around late June/July 2013: online share of orders rose from 74.571% to 92.125%, Accessories line share from 12.158% to 45.876%, and average lines per order fell from 5.70 to 3.58. These period-level outcomes are not caused by the Phase 8 labels; they are evidence that a regime change must be considered.

The RF segment sizes are shown below. The dominant segments are `Recent first/low-frequency` and `Hibernating/low-frequency` in both snapshots; that broad similarity does not offset the reversed label associations or period shifts.

| RF segment | A_2012 customers | B_2013 customers |
|---|---:|---:|
| Recent first/low-frequency | 952 | 2,154 |
| Hibernating/low-frequency | 1,120 | 2,423 |
| Middle RF | 555 | 1,245 |
| Recent/high-frequency RF | 152 | 302 |
| At-risk high-frequency | 0 | 46 |
| Other RF | 20 | 36 |

These rules use only R and F; names describe score bands and do not imply monetary value. Customer structure and product hierarchy are not effective-dated, so their apparent historical validity is limited.

## Later reactivation

Of Snapshot A’s **2,342** customers with no observed order during July 2012–June 2013, **2,003 (85.525%)** had an order from July 2013 through June 2014. This is “later reactivation” / “return after the label window.” It does not change the original Snapshot A label: that customer had no observed order in the defined first 365-day outcome window. Snapshot B has no observable later reactivation period because the extract ends on 2014-06-30.

The high later-return count demonstrates that an analytical non-return label is not equivalent to permanent departure. It also reinforces Phase 7’s finding that long gaps can precede a later purchase (completed repeat-gap median 138 days, P75 411, P90 634.5).

## Leakage audit and validation

| Validation | Result |
|---|---|
| Eligible customer count | 2,799 A; 6,206 B |
| Returned / analytical non-return counts | 457 / 2,342 A; 5,156 / 1,050 B |
| Exactly one row per customer per snapshot | Validated from assembled output: 2,799 and 6,206 distinct IDs; no duplicate keys |
| No customer acquired after cutoff | Validated: zero first-order dates after each cutoff |
| Negative RecencyDays | Zero in both snapshots |
| Feature date restrictions | Feature source CTEs filter order dates to on/before the snapshot date; labels alone inspect their later outcome window |
| Outcome window complete | A ends 2013-06-30; B ends at fixed extract end 2014-06-30 |
| Zero-order registered customers | Kept separate; none enters a purchaser-based snapshot |
| Monetary values | Excluded from features and RF scoring |
| Component query execution | Snapshot population, historical features, RF, channel/structure, product/order, leakage audit and comparison SQL executed successfully against the read-only source |

`07_feature_leakage_audit.sql` documents each feature’s source, grain, maximum permitted date, safety, and residual risk. Features approved for later descriptive/statistical or candidate ML analysis are cutoff-recomputed RecencyDays, Frequency, one/repeat-so-far, lifetime/days since first order, gap statistics, snapshot-specific RF, channel counts/shares, pre-cutoff order behavior, discount-line share, and pre-cutoff product/category behavior. Customer structure is conditional on validating historical stability; customer/product relationships and online flag semantics need domain review. The future target is never a feature.

## Structural-break implications and limitations

Snapshot A and B are **not suitable for blind pooling**. Phase 7.5 independently showed a sharp July 2013 increase in order and new-customer volume, a strong move toward online-flag orders and Person-only purchasers, a large Accessories mix change, smaller baskets, and a dramatic return-rate change. The same original 2,799 customers’ return rate increased from 16.327% in the first outcome year to 82.601% in the next. No single cause was established. Treat this as an exploratory regime difference, not a business intervention or causal effect.

For subsequent work, retain snapshot/time identity and report the snapshots separately. A later analyst may investigate regime indicators or time-aware designs, but this phase makes no final model architecture decision and performs no hypothesis testing or modeling.

Other limitations:

- The extract begins 2011-05-31. “First order” means first observed in this extract, not necessarily first-ever purchase or customer registration.
- The data ends 2014-06-30; behavior after Snapshot B is censored and cannot be assessed.
- The 365-day cutoff is provisional and known to produce later returns; labels are noisy proxies.
- `Sales.Customer` is a current, non-effective-dated record. Person/Store links cannot be proven static over the historical snapshots.
- `OnlineOrderFlag` is descriptive of the stored flag only.
- Current product hierarchy can differ from historical classification, and customer category shares can reflect multiple categories.
- Stored currency context remains unresolved; monetary fields stay excluded.
- No causality, statistical significance, or production churn status is inferred.

## Plain-language interpretation

The two historical snapshots can be labeled consistently by the same one-year non-return rule, and the SQL checks confirm the intended customer counts and cutoff boundaries. But the labels behave very differently across the July 2013 shift. More than four in five Snapshot A customers lacked a return in the next year, while about one in six Snapshot B customers did. Most of Snapshot A’s non-returners later ordered within the next year. These results support careful, time-aware follow-up and a provisional label interpretation; they do not show permanent churn.

## Five most important findings

1. The historical datasets reconcile: A has 2,799 customers (457 returned, 2,342 no return); B has 6,206 (5,156 returned, 1,050 no return).
2. The label rates reverse dramatically between snapshots: 83.673% no-return in A versus 16.919% in B, consistent with the previously observed structural break.
3. **2,003 of 2,342 (85.525%)** Snapshot A non-returners placed an order in the later observable year; the original label remains unchanged.
4. Pre-cutoff label profiles also reverse: A non-returners are less frequent and less online than returners, while B non-returners have higher frequency and online share than B returners.
5. Snapshot A and B should not be blindly pooled later. Use cutoff-recomputed, non-monetary features with snapshot/time context; validate historical customer-structure semantics and investigate the regime shift before modeling.

## Phase 8 decisions

1. **Technical validity:** The historical labels are technically valid for the stated 365-day observed non-return definition, and required counts, unique customer grain, eligibility dates, and outcome windows reconcile. They are not confirmed real-world churn labels.
2. **Later reactivation:** 2,003 / 2,342 Snapshot A non-returners (85.525%) returned in the following observed year. Snapshot B reactivation is unobservable.
3. **Pooling:** Do not pool A and B blindly; preserve snapshot identity and analyze time/regime differences.
4. **Candidate approved features:** Cutoff-only recency, frequency, one/repeat-so-far, customer lifetime, purchase-gap summaries, RF scores/segments, channel activity, order size/line/quantity, discount-line share, and cutoff-only product/category behavior.
5. **Excluded/conditional fields:** MonetaryRaw, SubTotal, UnitPrice, LineTotal, and AOV remain excluded due unresolved currency comparability. Future outcome fields are target-only. Current Person/Store relationships are conditional on historical stability, and OnlineOrderFlag must retain its literal descriptive meaning.

No statistical hypothesis testing or machine learning was performed. No final operational churn definition was established.
