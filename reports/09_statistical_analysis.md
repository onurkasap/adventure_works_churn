# Phase 9: Statistical Analysis of 365-Day Customer Non-Return

## Objective and target

Assess which **pre-cutoff** customer characteristics are associated with whether a customer placed at least one order in the fully observed next 365 days. `AnalyticalChurn=1` means no observed order (365-day analytical non-return); `0` means at least one observed return. This is a historical outcome proxy and does not establish permanent churn.

## Snapshot populations and validation

Each snapshot was reconstructed and analyzed separately using the Phase 8 cutoff logic. Features use order dates on or before cutoff; the future order existence check is used only for the label. The unit is customer within snapshot.

| Snapshot | Customers | Returned | Non-return | Validation |
|---|---:|---:|---:|---|
| A_2012 | 2,799 | 457 | 2,342 | PASS |
| B_2013 | 6,206 | 5,156 | 1,050 | PASS |

Each key is unique. Monetary fields are absent. Gap variables remain null when a customer has only one pre-cutoff order. The dataset query is `sql/09_statistics/01_statistical_dataset.sql`.

## Methodology and assumptions

Continuous/count variables are summarized by label with N, missing count, mean, median, standard deviation, P25, and P75 below. Distribution inspection supports median/IQR and Mann–Whitney U comparisons because counts and shares are skewed, bounded, or discrete. The reported rank-biserial effect is positive when non-return customers tend to have higher values. Median-difference confidence intervals use 3,000 seeded independent customer bootstrap resamples. These intervals quantify sampling uncertainty under independent customer sampling; customers can appear in both snapshots, so cross-snapshot contrasts are descriptive.

Binary and multi-category fields use 2x2 Fisher exact when expected cell counts are sparse; otherwise Pearson chi-square. Sparse larger tables use fixed-margin Monte Carlo (5,000 draws). Cramer's V reports association magnitude. Exploratory product and basket Mann–Whitney tests receive Benjamini–Hochberg adjustment within each snapshot. No normality test is used mechanically. P-values do not establish practical importance or causality.

## Descriptive statistics by snapshot and outcome

The summaries include every continuous/count candidate. Large mean–median gaps indicate strong skew, especially Frequency, CustomerLifetimeDays, DaysSinceFirstOrder, TotalQuantity, and order-gap measures; many category shares are zero-inflated.

| Snapshot | AnalyticalChurn | Variable | N | Missing | Mean | Median | SD | P25 | P75 | Min | Max |
|---|---|---|---|---|---|---|---|---|---|---|---|
| A_2012 | 0 | RecencyDays | 457 | 0 | 111.23 | 61.00 | 121.51 | 0.00 | 210.00 | 0.00 | 396.00 |
| A_2012 | 0 | Frequency | 457 | 0 | 2.01 | 1.00 | 1.58 | 1.00 | 4.00 | 1.00 | 5.00 |
| A_2012 | 0 | CustomerLifetimeDays | 457 | 0 | 97.13 | 0.00 | 148.53 | 0.00 | 273.00 | 0.00 | 365.00 |
| A_2012 | 0 | DaysSinceFirstOrder | 457 | 0 | 208.37 | 246.00 | 145.02 | 31.00 | 336.00 | 0.00 | 396.00 |
| A_2012 | 0 | AverageDaysBetweenOrders | 142 | 315 | 103.93 | 91.25 | 38.28 | 91.00 | 91.25 | 91.00 | 365.00 |
| A_2012 | 0 | MedianDaysBetweenOrders | 142 | 315 | 103.66 | 92.00 | 38.12 | 91.00 | 92.00 | 91.00 | 365.00 |
| A_2012 | 0 | OnlineOrderShare | 457 | 0 | 0.42 | 0.00 | 0.49 | 0.00 | 1.00 | 0.00 | 1.00 |
| A_2012 | 0 | DistinctProductCount | 457 | 0 | 14.79 | 3.00 | 19.11 | 1.00 | 22.00 | 1.00 | 75.00 |
| A_2012 | 0 | DistinctCategoryCount | 457 | 0 | 2.20 | 2.00 | 1.30 | 1.00 | 4.00 | 1.00 | 4.00 |
| A_2012 | 0 | TotalQuantity | 457 | 0 | 75.65 | 4.00 | 126.17 | 1.00 | 104.00 | 1.00 | 817.00 |
| A_2012 | 0 | MeanQuantityPerOrder | 457 | 0 | 36.62 | 2.33 | 67.19 | 1.00 | 42.25 | 1.00 | 384.00 |
| A_2012 | 0 | MeanLinesPerOrder | 457 | 0 | 10.50 | 1.67 | 14.67 | 1.00 | 16.00 | 1.00 | 65.00 |
| A_2012 | 0 | DiscountedLineShare | 457 | 0 | 0.03 | 0.00 | 0.08 | 0.00 | 0.02 | 0.00 | 1.00 |
| A_2012 | 0 | BikesShare | 457 | 0 | 0.67 | 0.72 | 0.34 | 0.37 | 1.00 | 0.00 | 1.00 |
| A_2012 | 0 | AccessoriesShare | 457 | 0 | 0.04 | 0.00 | 0.08 | 0.00 | 0.07 | 0.00 | 1.00 |
| A_2012 | 0 | ClothingShare | 457 | 0 | 0.10 | 0.00 | 0.15 | 0.00 | 0.19 | 0.00 | 1.00 |
| A_2012 | 0 | ComponentsShare | 457 | 0 | 0.19 | 0.08 | 0.24 | 0.00 | 0.32 | 0.00 | 1.00 |
| A_2012 | 1 | RecencyDays | 2342 | 0 | 174.38 | 165.00 | 113.14 | 77.00 | 266.00 | 0.00 | 396.00 |
| A_2012 | 1 | Frequency | 2342 | 0 | 1.07 | 1.00 | 0.44 | 1.00 | 1.00 | 1.00 | 5.00 |
| A_2012 | 1 | CustomerLifetimeDays | 2342 | 0 | 6.53 | 0.00 | 41.22 | 0.00 | 0.00 | 0.00 | 365.00 |
| A_2012 | 1 | DaysSinceFirstOrder | 2342 | 0 | 180.92 | 175.50 | 115.32 | 80.00 | 277.00 | 0.00 | 396.00 |
| A_2012 | 1 | AverageDaysBetweenOrders | 59 | 2283 | 101.82 | 91.00 | 31.84 | 91.00 | 91.33 | 90.50 | 273.00 |
| A_2012 | 1 | MedianDaysBetweenOrders | 59 | 2283 | 102.26 | 92.00 | 31.69 | 91.00 | 92.00 | 90.50 | 273.00 |
| A_2012 | 1 | OnlineOrderShare | 2342 | 0 | 0.97 | 1.00 | 0.16 | 1.00 | 1.00 | 0.00 | 1.00 |
| A_2012 | 1 | DistinctProductCount | 2342 | 0 | 1.35 | 1.00 | 2.64 | 1.00 | 1.00 | 1.00 | 36.00 |
| A_2012 | 1 | DistinctCategoryCount | 2342 | 0 | 1.04 | 1.00 | 0.32 | 1.00 | 1.00 | 1.00 | 4.00 |
| A_2012 | 1 | TotalQuantity | 2342 | 0 | 3.56 | 1.00 | 23.29 | 1.00 | 1.00 | 1.00 | 431.00 |
| A_2012 | 1 | MeanQuantityPerOrder | 2342 | 0 | 1.63 | 1.00 | 5.74 | 1.00 | 1.00 | 1.00 | 107.75 |
| A_2012 | 1 | MeanLinesPerOrder | 2342 | 0 | 1.22 | 1.00 | 1.81 | 1.00 | 1.00 | 1.00 | 28.75 |
| A_2012 | 1 | DiscountedLineShare | 2342 | 0 | 0.00 | 0.00 | 0.01 | 0.00 | 0.00 | 0.00 | 0.31 |
| A_2012 | 1 | BikesShare | 2342 | 0 | 0.99 | 1.00 | 0.07 | 1.00 | 1.00 | 0.00 | 1.00 |
| A_2012 | 1 | AccessoriesShare | 2342 | 0 | 0.00 | 0.00 | 0.01 | 0.00 | 0.00 | 0.00 | 0.25 |
| A_2012 | 1 | ClothingShare | 2342 | 0 | 0.00 | 0.00 | 0.04 | 0.00 | 0.00 | 0.00 | 1.00 |
| A_2012 | 1 | ComponentsShare | 2342 | 0 | 0.00 | 0.00 | 0.05 | 0.00 | 0.00 | 0.00 | 1.00 |
| B_2013 | 0 | RecencyDays | 5156 | 0 | 305.45 | 282.00 | 213.06 | 115.00 | 465.00 | 0.00 | 761.00 |
| B_2013 | 0 | Frequency | 5156 | 0 | 1.28 | 1.00 | 1.15 | 1.00 | 1.00 | 1.00 | 9.00 |
| B_2013 | 0 | CustomerLifetimeDays | 5156 | 0 | 37.41 | 0.00 | 138.58 | 0.00 | 0.00 | 0.00 | 757.00 |
| B_2013 | 0 | DaysSinceFirstOrder | 5156 | 0 | 342.86 | 334.00 | 210.27 | 162.00 | 501.00 | 0.00 | 761.00 |
| B_2013 | 0 | AverageDaysBetweenOrders | 418 | 4738 | 227.99 | 91.25 | 221.97 | 91.25 | 309.75 | 0.00 | 757.00 |
| B_2013 | 0 | MedianDaysBetweenOrders | 418 | 4738 | 224.82 | 92.00 | 223.48 | 91.50 | 309.75 | 0.00 | 757.00 |
| B_2013 | 0 | OnlineOrderShare | 5156 | 0 | 0.93 | 1.00 | 0.26 | 1.00 | 1.00 | 0.00 | 1.00 |
| B_2013 | 0 | DistinctProductCount | 5156 | 0 | 3.40 | 1.00 | 11.11 | 1.00 | 1.00 | 1.00 | 107.00 |
| B_2013 | 0 | DistinctCategoryCount | 5156 | 0 | 1.19 | 1.00 | 0.65 | 1.00 | 1.00 | 1.00 | 4.00 |
| B_2013 | 0 | TotalQuantity | 5156 | 0 | 20.47 | 1.00 | 119.37 | 1.00 | 1.00 | 1.00 | 1664.00 |
| B_2013 | 0 | MeanQuantityPerOrder | 5156 | 0 | 5.49 | 1.00 | 26.53 | 1.00 | 1.00 | 1.00 | 483.00 |
| B_2013 | 0 | MeanLinesPerOrder | 5156 | 0 | 2.18 | 1.00 | 5.88 | 1.00 | 1.00 | 1.00 | 67.00 |
| B_2013 | 0 | DiscountedLineShare | 5156 | 0 | 0.01 | 0.00 | 0.05 | 0.00 | 0.00 | 0.00 | 1.00 |
| B_2013 | 0 | BikesShare | 5156 | 0 | 0.94 | 1.00 | 0.19 | 1.00 | 1.00 | 0.00 | 1.00 |
| B_2013 | 0 | AccessoriesShare | 5156 | 0 | 0.02 | 0.00 | 0.09 | 0.00 | 0.00 | 0.00 | 1.00 |
| B_2013 | 0 | ClothingShare | 5156 | 0 | 0.02 | 0.00 | 0.07 | 0.00 | 0.00 | 0.00 | 1.00 |
| B_2013 | 0 | ComponentsShare | 5156 | 0 | 0.03 | 0.00 | 0.11 | 0.00 | 0.00 | 0.00 | 1.00 |
| B_2013 | 1 | RecencyDays | 1050 | 0 | 238.40 | 110.00 | 250.93 | 19.00 | 487.00 | 0.00 | 761.00 |
| B_2013 | 1 | Frequency | 1050 | 0 | 1.61 | 1.00 | 1.31 | 1.00 | 2.00 | 1.00 | 9.00 |
| B_2013 | 1 | CustomerLifetimeDays | 1050 | 0 | 104.28 | 0.00 | 191.09 | 0.00 | 164.75 | 0.00 | 730.00 |
| B_2013 | 1 | DaysSinceFirstOrder | 1050 | 0 | 342.68 | 334.00 | 262.28 | 67.25 | 601.75 | 0.00 | 761.00 |
| B_2013 | 1 | AverageDaysBetweenOrders | 310 | 740 | 250.98 | 150.00 | 202.10 | 91.00 | 444.25 | 5.00 | 717.00 |
| B_2013 | 1 | MedianDaysBetweenOrders | 310 | 740 | 250.48 | 150.00 | 202.40 | 92.00 | 444.25 | 5.00 | 717.00 |
| B_2013 | 1 | OnlineOrderShare | 1050 | 0 | 0.85 | 1.00 | 0.35 | 1.00 | 1.00 | 0.00 | 1.00 |
| B_2013 | 1 | DistinctProductCount | 1050 | 0 | 4.43 | 1.00 | 9.62 | 1.00 | 4.00 | 1.00 | 75.00 |
| B_2013 | 1 | DistinctCategoryCount | 1050 | 0 | 1.63 | 1.00 | 0.86 | 1.00 | 2.00 | 1.00 | 4.00 |
| B_2013 | 1 | TotalQuantity | 1050 | 0 | 25.99 | 1.00 | 115.73 | 1.00 | 4.00 | 1.00 | 1322.00 |
| B_2013 | 1 | MeanQuantityPerOrder | 1050 | 0 | 6.39 | 1.00 | 23.67 | 1.00 | 2.50 | 1.00 | 330.50 |
| B_2013 | 1 | MeanLinesPerOrder | 1050 | 0 | 2.92 | 1.00 | 5.94 | 1.00 | 2.50 | 1.00 | 54.75 |
| B_2013 | 1 | DiscountedLineShare | 1050 | 0 | 0.00 | 0.00 | 0.02 | 0.00 | 0.00 | 0.00 | 0.31 |
| B_2013 | 1 | BikesShare | 1050 | 0 | 0.74 | 1.00 | 0.32 | 0.50 | 1.00 | 0.00 | 1.00 |
| B_2013 | 1 | AccessoriesShare | 1050 | 0 | 0.15 | 0.00 | 0.25 | 0.00 | 0.33 | 0.00 | 1.00 |
| B_2013 | 1 | ClothingShare | 1050 | 0 | 0.07 | 0.00 | 0.15 | 0.00 | 0.00 | 0.00 | 1.00 |
| B_2013 | 1 | ComponentsShare | 1050 | 0 | 0.04 | 0.00 | 0.15 | 0.00 | 0.00 | 0.00 | 1.00 |

Categorical distributions, outcome rates, effect sizes, and tests are detailed below. The SQL outputs in `02_descriptive_profiles.sql`, `03_categorical_analysis.sql`, and `04_product_category_analysis.sql` document the corresponding groupings.

## Primary analyses

### A_2012

Eligible **2,799**; returned **457**; 365-day non-return **2,342 (83.7%)**.

- **RecencyDays** (non-return vs return; n=2342/457): medians 165.00 vs 61.00, means 174.38 vs 111.23, IQR [77.00, 266.00] vs [0.00, 210.00]; Mann–Whitney U p=<0.001, rank-biserial r=0.357, bootstrap 95% CI for median difference [95.00, 138.00].
- **Frequency** (non-return vs return; n=2342/457): medians 1.00 vs 1.00, means 1.07 vs 2.01, IQR [1.00, 1.00] vs [1.00, 4.00]; Mann–Whitney U p=<0.001, rank-biserial r=-0.289, bootstrap 95% CI for median difference [0.00, 0.00].
- **OnlineOrderShare** (non-return vs return; n=2342/457): medians 1.00 vs 0.00, means 0.97 vs 0.42, IQR [1.00, 1.00] vs [0.00, 1.00]; Mann–Whitney U p=<0.001, rank-biserial r=0.554, bootstrap 95% CI for median difference [1.00, 1.00].
- **AverageDaysBetweenOrders** (non-return vs return; n=59/142): medians 91.00 vs 91.25, means 101.82 vs 103.93, IQR [91.00, 91.33] vs [91.00, 91.25]; Mann–Whitney U p=0.009, rank-biserial r=-0.219, bootstrap 95% CI for median difference [-0.25, -0.25].
- **MedianDaysBetweenOrders** (non-return vs return; n=59/142): medians 92.00 vs 92.00, means 102.26 vs 103.66, IQR [91.00, 92.00] vs [91.00, 92.00]; Mann–Whitney U p=0.662, rank-biserial r=0.037, bootstrap 95% CI for median difference [0.00, 0.50].
- **One-order vs repeat**: one-order 2283/2598 non-return (87.9%); repeat 59/201 (29.4%); difference +58.5 percentage points; RR 2.99 (95% CI 2.41–3.71); OR 17.44 (95% CI 12.60–24.16); Pearson chi-square p=<0.001.
- **FirstOrderOnlineFlag**: 0: n=331, non-return=65 (19.6%); 1: n=2468, non-return=2277 (92.3%). Pearson chi-square, p=<0.001, Cramer's V=0.634 (minimum expected cell 54.04).
- **LastOrderOnlineFlag**: 0: n=331, non-return=65 (19.6%); 1: n=2468, non-return=2277 (92.3%). Pearson chi-square, p=<0.001, Cramer's V=0.634 (minimum expected cell 54.04).
- **CustomerStructure**: Person and Store: n=331, non-return=65 (19.6%); Person only: n=2468, non-return=2277 (92.3%). Pearson chi-square, p=<0.001, Cramer's V=0.634 (minimum expected cell 54.04).
- **RFSegment**: Hibernating/low-frequency: n=1120, non-return=995 (88.8%); Middle RF: n=555, non-return=499 (89.9%); Other RF: n=20, non-return=7 (35.0%); Recent first/low-frequency: n=952, non-return=803 (84.3%); Recent/high-frequency RF: n=152, non-return=38 (25.0%). Pearson statistic, fixed-margin Monte Carlo (5,000 draws), p=<0.001, Cramer's V=0.403 (minimum expected cell 3.27).
- **DominantCategory**: Accessories: n=3, non-return=0 (0.0%); Bikes: n=2676, non-return=2335 (87.3%); Clothing: n=42, non-return=2 (4.8%); Components: n=78, non-return=5 (6.4%). Pearson statistic, fixed-margin Monte Carlo (5,000 draws), p=<0.001, Cramer's V=0.452 (minimum expected cell 0.49).
- **Frequency groups** (1, 2, 3, 4–5, 6+): rates by group 1: 87.9% (n=2598), 2: 37.5% (n=16), 3: 35.0% (n=20), 4–5: 27.9% (n=165); Pearson statistic, fixed-margin Monte Carlo (5,000 draws) p=<0.001, Cramer's V=0.409.
### B_2013

Eligible **6,206**; returned **5,156**; 365-day non-return **1,050 (16.9%)**.

- **RecencyDays** (non-return vs return; n=1050/5156): medians 110.00 vs 282.00, means 238.40 vs 305.45, IQR [19.00, 487.00] vs [115.00, 465.00]; Mann–Whitney U p=<0.001, rank-biserial r=-0.230, bootstrap 95% CI for median difference [-196.00, -146.50].
- **Frequency** (non-return vs return; n=1050/5156): medians 1.00 vs 1.00, means 1.61 vs 1.28, IQR [1.00, 2.00] vs [1.00, 1.00]; Mann–Whitney U p=<0.001, rank-biserial r=0.206, bootstrap 95% CI for median difference [0.00, 0.00].
- **OnlineOrderShare** (non-return vs return; n=1050/5156): medians 1.00 vs 1.00, means 0.85 vs 0.93, IQR [1.00, 1.00] vs [1.00, 1.00]; Mann–Whitney U p=<0.001, rank-biserial r=-0.072, bootstrap 95% CI for median difference [0.00, 0.00].
- **AverageDaysBetweenOrders** (non-return vs return; n=310/418): medians 150.00 vs 91.25, means 250.98 vs 227.99, IQR [91.00, 444.25] vs [91.25, 309.75]; Mann–Whitney U p=0.083, rank-biserial r=0.075, bootstrap 95% CI for median difference [32.08, 88.75].
- **MedianDaysBetweenOrders** (non-return vs return; n=310/418): medians 150.00 vs 92.00, means 250.48 vs 224.82, IQR [92.00, 444.25] vs [91.50, 309.75]; Mann–Whitney U p=<0.001, rank-biserial r=0.171, bootstrap 95% CI for median difference [28.00, 88.00].
- **One-order vs repeat**: one-order 740/5478 non-return (13.5%); repeat 310/728 (42.6%); difference -29.1 percentage points; RR 0.32 (95% CI 0.28–0.35); OR 0.21 (95% CI 0.18–0.25); Pearson chi-square p=<0.001.
- **FirstOrderOnlineFlag**: 0: n=535, non-return=153 (28.6%); 1: n=5671, non-return=897 (15.8%). Pearson chi-square, p=<0.001, Cramer's V=0.096 (minimum expected cell 90.52).
- **LastOrderOnlineFlag**: 0: n=535, non-return=153 (28.6%); 1: n=5671, non-return=897 (15.8%). Pearson chi-square, p=<0.001, Cramer's V=0.096 (minimum expected cell 90.52).
- **CustomerStructure**: Person and Store: n=535, non-return=153 (28.6%); Person only: n=5671, non-return=897 (15.8%). Pearson chi-square, p=<0.001, Cramer's V=0.096 (minimum expected cell 90.52).
- **RFSegment**: At-risk high-frequency: n=46, non-return=41 (89.1%); Hibernating/low-frequency: n=2423, non-return=313 (12.9%); Middle RF: n=1245, non-return=86 (6.9%); Other RF: n=36, non-return=13 (36.1%); Recent first/low-frequency: n=2154, non-return=536 (24.9%); Recent/high-frequency RF: n=302, non-return=61 (20.2%). Pearson chi-square, p=<0.001, Cramer's V=0.253 (minimum expected cell 6.09).
- **DominantCategory**: Accessories: n=336, non-return=246 (73.2%); Bikes: n=5639, non-return=747 (13.2%); Clothing: n=90, non-return=28 (31.1%); Components: n=141, non-return=29 (20.6%). Pearson chi-square, p=<0.001, Cramer's V=0.365 (minimum expected cell 15.23).
- **Frequency groups** (1, 2, 3, 4–5, 6+): rates by group 1: 13.5% (n=5478), 2: 56.7% (n=337), 3: 34.2% (n=38), 4–5: 33.8% (n=231), 6+: 23.0% (n=122); Pearson chi-square p=<0.001, Cramer's V=0.279.

Primary tests and magnitudes:

| snapshot | var | p | eff | ci | n1 | n0 |
|---|---|---|---|---|---|---|
| A_2012 | RecencyDays | <0.001 | 0.357 | [95.000, 138.000] | 2342 | 457 |
| A_2012 | Frequency | <0.001 | -0.289 | [0.000, 0.000] | 2342 | 457 |
| A_2012 | OnlineOrderShare | <0.001 | 0.554 | [1.000, 1.000] | 2342 | 457 |
| A_2012 | OneOrderSoFar | <0.001 | 0.585 | [, ] | 2598 | 201 |
| A_2012 | FirstOrderOnlineFlag | <0.001 | 0.634 | [, ] | 2799 | 2799 |
| A_2012 | LastOrderOnlineFlag | <0.001 | 0.634 | [, ] | 2799 | 2799 |
| A_2012 | RFSegment | <0.001 | 0.403 | [, ] | 2799 | 2799 |
| B_2013 | RecencyDays | <0.001 | -0.230 | [-196.000, -146.500] | 1050 | 5156 |
| B_2013 | Frequency | <0.001 | 0.206 | [0.000, 0.000] | 1050 | 5156 |
| B_2013 | OnlineOrderShare | <0.001 | -0.072 | [0.000, 0.000] | 1050 | 5156 |
| B_2013 | OneOrderSoFar | <0.001 | -0.291 | [, ] | 5478 | 728 |
| B_2013 | FirstOrderOnlineFlag | <0.001 | 0.096 | [, ] | 6206 | 6206 |
| B_2013 | LastOrderOnlineFlag | <0.001 | 0.096 | [, ] | 6206 | 6206 |
| B_2013 | RFSegment | <0.001 | 0.253 | [, ] | 6206 | 6206 |

## Exploratory product, category, and basket analyses

Customer category shares are line-based and categories overlap within customers. Their many zero values and strong concentration favor distribution-aware rank tests; dominant category is mutually exclusive with alphabetical tie-break inherited from Phase 8. Current product hierarchy is not effective-dated. Associations do not imply category preference caused return.

Raw p-values and snapshot-wise BH adjusted p-values:

| snapshot | var | p | eff | ci | n1 | n0 | q_BH |
|---|---|---|---|---|---|---|---|
| A_2012 | AverageDaysBetweenOrders | 0.009 | -0.219 | [-0.250, -0.250] | 59 | 142 | 0.010 |
| A_2012 | MedianDaysBetweenOrders | 0.662 | 0.037 | [0.000, 0.500] | 59 | 142 | 0.662 |
| A_2012 | CustomerStructure | <0.001 | 0.634 | [, ] | 2799 | 2799 | <0.001 |
| A_2012 | DominantCategory | <0.001 | 0.452 | [, ] | 2799 | 2799 | <0.001 |
| A_2012 | DistinctProductCount | <0.001 | -0.522 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | DistinctCategoryCount | <0.001 | -0.500 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | TotalQuantity | <0.001 | -0.528 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | MeanQuantityPerOrder | <0.001 | -0.520 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | MeanLinesPerOrder | <0.001 | -0.497 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | DiscountedLineShare | <0.001 | -0.275 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | BikesShare | <0.001 | 0.537 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | AccessoriesShare | <0.001 | -0.299 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | ClothingShare | <0.001 | -0.412 | [, ] | 2342 | 457 | <0.001 |
| A_2012 | ComponentsShare | <0.001 | -0.500 | [, ] | 2342 | 457 | <0.001 |
| B_2013 | AverageDaysBetweenOrders | 0.083 | 0.075 | [32.083, 88.750] | 310 | 418 | 0.090 |
| B_2013 | MedianDaysBetweenOrders | <0.001 | 0.171 | [28.000, 88.000] | 310 | 418 | <0.001 |
| B_2013 | CustomerStructure | <0.001 | 0.096 | [, ] | 6206 | 6206 | <0.001 |
| B_2013 | DominantCategory | <0.001 | 0.365 | [, ] | 6206 | 6206 | <0.001 |
| B_2013 | DistinctProductCount | <0.001 | 0.347 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | DistinctCategoryCount | <0.001 | 0.322 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | TotalQuantity | <0.001 | 0.352 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | MeanQuantityPerOrder | <0.001 | 0.333 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | MeanLinesPerOrder | <0.001 | 0.326 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | DiscountedLineShare | 0.460 | 0.005 | [, ] | 1050 | 5156 | 0.460 |
| B_2013 | BikesShare | <0.001 | -0.354 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | AccessoriesShare | <0.001 | 0.281 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | ClothingShare | <0.001 | 0.156 | [, ] | 1050 | 5156 | <0.001 |
| B_2013 | ComponentsShare | <0.001 | 0.041 | [, ] | 1050 | 5156 | <0.001 |

## Purchase gaps

Gap analyses above use only customers with at least two pre-cutoff orders; N is displayed for each outcome. Single-order customers have no interval, and those values were not imputed. Snapshot A has particularly small gap samples, so estimates there are imprecise.

## Snapshot stability

Association direction is defined as non-return median minus returned median (for one-order share, non-return minus returned proportion).

| Feature / effect | Snapshot A | Snapshot B | Same direction? | Absolute magnitude change | Potential regime sensitivity |
|---|---:|---:|---|---:|---|
| RecencyDays | +104.000 | -172.000 | No | 68.000 | Yes: direction reverses |
| Frequency | -0.939 | +0.334 | No | 0.605 | Yes: direction reverses |
| OnlineOrderShare | +0.554 | -0.072 | No | 0.483 | Yes: direction reverses |
| OneOrderSoFar | +0.286 | -0.214 | No | 0.071 | Yes: direction reverses |
| Frequency rank-biserial | -0.289 | +0.206 | No | 0.083 | Yes: effect magnitude differs |
| OnlineOrderShare rank-biserial | +0.554 | -0.072 | No | 0.483 | Yes: effect magnitude differs |
| FirstOrderOnlineFlag Cramer's V | +0.634 | +0.096 | N/A (magnitude only) | 0.539 | Yes: effect magnitude differs |
| RFSegment Cramer's V | +0.403 | +0.253 | N/A (magnitude only) | 0.151 | Yes: effect magnitude differs |
| OneOrderSoFar rate difference (percentage points) | +28.6 | -21.4 | No | 7.1 | Yes: direction reverses |

The shared customer IDs are handled in a small explanatory logistic regression with Snapshot B interactions for standardized RecencyDays, Frequency, and OnlineOrderShare. Standard errors are clustered by customer to account for repeated snapshot rows. Interactions test whether conditional log-odds associations differ by snapshot; they do not measure predictive performance or causality. The model omits redundant one-order and RF variables.

| Term | Coefficient | OR per 1 SD / indicator | 95% cluster-robust OR CI | p-value |
|---|---:|---:|---:|---:|
| Intercept | +1.943 | 6.978 | [5.896, 8.259] | <0.001 |
| SnapshotB | -3.526 | 0.029 | [0.025, 0.035] | <0.001 |
| RecencyDays | -0.518 | 0.596 | [0.468, 0.758] | <0.001 |
| Frequency | +0.301 | 1.352 | [1.166, 1.567] | <0.001 |
| OnlineOrderShare | +1.435 | 4.198 | [3.616, 4.875] | <0.001 |
| B_x_RecencyDays | +0.277 | 1.320 | [1.029, 1.692] | 0.029 |
| B_x_Frequency | -0.201 | 0.818 | [0.707, 0.946] | 0.007 |
| B_x_OnlineOrderShare | -1.498 | 0.224 | [0.192, 0.260] | <0.001 |

Model rows: 9,005; customer clusters: 6,206. Interaction coefficients are changes in the log-odds slope in B relative to A; exponentiated coefficients are ratios of the per-standard-deviation odds ratios. Linear logit effects are a simplifying assumption, and residual confounding remains possible.

## Business interpretation and conclusions

1. **Recency reverses strongly:** median recency difference (non-return minus return) is +104 days in A and -172 days in B; rank-biserial effects are +0.357 and -0.230.
2. **Repeat history reverses:** one-order customers have +28.6 percentage points higher non-return rate than repeat customers in A, but -21.4 points lower in B.
3. **Frequency's mean association reverses:** non-return minus return mean frequency is -0.94 orders in A and +0.33 in B; its median is tied at one in both, showing why the skew-aware rank/group summaries matter.
4. **Channel association weakens materially:** FirstOrderOnlineFlag Cramer's V changes from 0.634 in A to 0.096 in B, with opposite direction in the category rates.
5. **RF separates outcomes in each snapshot but its magnitude shifts:** Cramer's V is 0.403 in A and 0.253 in B; the segment rate ordering changes.

### Five important findings

1. **Recency reverses strongly:** median recency difference (non-return minus return) is +104 days in A and -172 days in B; rank-biserial effects are +0.357 and -0.230.
2. **Repeat history reverses:** one-order customers have +28.6 percentage points higher non-return rate than repeat customers in A, but -21.4 points lower in B.
3. **Frequency's mean association reverses:** non-return minus return mean frequency is -0.94 orders in A and +0.33 in B; its median is tied at one in both, showing why the skew-aware rank/group summaries matter.
4. **Channel association weakens materially:** FirstOrderOnlineFlag Cramer's V changes from 0.634 in A to 0.096 in B, with opposite direction in the category rates.
5. **RF separates outcomes in each snapshot but its magnitude shifts:** Cramer's V is 0.403 in A and 0.253 in B; the segment rate ordering changes.

### Required decisions

1. **Stable associations:** RF segment and first-order flag remain associated within both snapshots, but effect magnitudes weaken in B. No key directional numeric association is stable across snapshots.
2. **Reversals/material changes:** recency, frequency mean, online share mean, and one-order share reverse direction between A and B.
3. **Most useful candidates for later prediction:** recency, frequency/repeat status, channel history, and RF segment are reasonable candidates for feasibility evaluation, subject to temporal validation and redundancy checks.
4. **Caution:** current customer structure and current product hierarchy are not effective-dated; category shares are zero-inflated; gap statistics exclude one-order customers; OnlineOrderFlag semantics are limited; the 365-day outcome is not permanent churn.
5. **Proceed to ML feasibility?** Yes, as a separate feasibility phase only, with no claim of operational readiness. Preserve time separation, compare snapshot-specific performance later, and avoid blind pooling. This phase itself does not build an ML model.

## Limitations

`Sales.Customer` is not effective-dated, so historical stability of Person-only versus Person-and-Store is unproven. Product hierarchy is current. Independence may be imperfect because the same customer can occur in both snapshots; each within-snapshot test uses one row per customer. Phase 9 uses two historical regimes, and Snapshot B's outcome ends with the extract. P-values are descriptive inferential evidence under the stated assumptions, not causal proof. No monetary feature was used.
