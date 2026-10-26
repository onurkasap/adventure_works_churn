# AdventureWorks | Customer Retention & Churn Analytics

An end-to-end analytics project using AdventureWorks2022 sales history to examine customer purchasing, repeat behavior, retention, and historical non-return. The workflow moves from SQL Server schema discovery and data-quality checks to validated SQL metrics, Python statistical and machine-learning feasibility analysis, and Power BI model/dashboard specifications. The observed order window is **2011-05-31 to 2014-06-30**. Findings are descriptive: the project distinguishes observed behavior from assumptions and does not treat a historical non-return label as confirmed permanent churn.

## At a glance

| Measure | Observed result | Definition |
|---|---:|---|
| Registered customers | 19,820 | Customer records in the observed extract |
| Purchasing customers | 19,119 | At least one observed order |
| Registered customers without observed orders | 701 | Registered records with no linked order in the extract |
| Orders / order lines | 31,465 / 121,317 | Header orders / detail rows |
| One-time / repeat purchasers | 11,649 / 7,470 | Exactly one / at least two observed orders |
| Full-history repeat purchasing rate | 39.07% | 7,470 of 19,119 purchasers; bounded by this observation window |
| Weighted exact-month cohort retention | M1 1.863%; M3 5.387%; M6 5.986%; M12 10.055% | Each rate uses only cohorts with that complete target month observable; activity in that exact calendar month |

These validated counts are based on order headers and customer-level populations; order lines are kept at their own grain. Revenue and AOV are not presented as comparable KPIs because the extract contains mixed currency contexts and no conversion convention was selected.

## Key findings

- **Purchasing behavior:** 39.07% of purchasing customers placed at least two orders during the finite history. Repeat status is observed frequency, not a churn classification. [Read the baseline analysis](reports/03_baseline_analysis.md) and [customer behavior report](reports/04_customer_behavior.md).
- **Cohort retention:** exact-calendar-month weighted retention is low at M1 and varies by horizon; M12 can exceed M6 because the measure captures activity in a specific month rather than cumulative return. [Read the cohort analysis](reports/05_retention_cohort_analysis.md).
- **RF segmentation:** six descriptive groups summarize recency and frequency at **2014-06-30**. This is RF segmentation, not full RFM: monetary scoring was excluded. [Read the segmentation report](reports/06_rfm_customer_segmentation.md).
- **Observed structural shift:** monthly orders rose from 719 in June 2013 to 1,740 in July 2013. This is a visible change in the recorded series; the analysis does not establish its cause. [Read the July 2013 analysis](reports/07_5_july_2013_structural_break.md).
- **Historical 365-day non-return:** the two cutoff cohorts differ substantially: A_2012 had 2,342 / 2,799 non-returners (83.673%); B_2013 had 1,050 / 6,206 (16.919%). They represent different regimes and are not directly comparable causal churn estimates. Of A_2012 non-returners, 2,003 (85.525%) later reactivated in the next observable year; B reactivation cannot be observed in this extract. [Read the definition analysis](reports/07_churn_definition_analysis.md) and [label construction report](reports/08_churn_label_construction.md).
- **Inference and modeling:** statistical associations differ between historical snapshots, and cross-regime ML generalization was unreliable. The feasibility work supports further data and business-definition work, not a deployable churn model. [Read the statistical analysis](reports/09_statistical_analysis.md) and [ML feasibility report](reports/10_ml_feasibility.md).

## Tools and workflow

**SQL Server / T-SQL → Python (pandas, statistics, scikit-learn) → Power BI preparation**

SQL queries inspect the source schema and build reproducible customer, KPI, cohort, RF, historical-label, statistical, and reporting datasets. Python code supports statistical testing and a cutoff-aware ML feasibility experiment. Power BI documentation specifies a semantic model, measures, import sequence, and dashboard pages; a published dashboard artifact is not included in this repository.

## Explore the analyses

| Analysis | Main question | Key takeaway | Read the report |
|---|---|---|---|
| Database discovery | Which tables, keys, and relationships support customer/order analysis? | Schema and join paths were checked against AdventureWorks2022 metadata. | [Discovery](reports/01_database_discovery.md) |
| Data profiling and quality | What populations, grains, and data issues constrain analysis? | Distinguish customers, order headers, and lines; finite history and currency context matter. | [Data quality](reports/02_data_quality_report.md) |
| Baseline KPIs | How large is the observed customer/order base and repeat-purchaser share? | 19,119 purchasers; 39.07% had at least two observed orders. | [KPI definitions](reports/03_kpi_definitions.md) · [Baseline analysis](reports/03_baseline_analysis.md) |
| Customer behavior | How frequently did customers order, and when did they return? | Median interpurchase gap among repeat buyers was 138 days; this is descriptive, not an inactivity rule. | [Customer behavior](reports/04_customer_behavior.md) |
| Cohort retention | What share of each first-observed purchase cohort was active in an exact later calendar month? | Weighted rates: M1 1.863%, M3 5.387%, M6 5.986%, M12 10.055%; later cells without full follow-up are unobserved. | [Cohort retention](reports/05_retention_cohort_analysis.md) |
| RF segmentation | How do customers group by recency and order frequency at the final cutoff? | Six groups as of 2014-06-30; monetary value was not scored. | [RF segmentation](reports/06_rfm_customer_segmentation.md) |
| July 2013 structural break | What shifted around June–July 2013? | Orders rose from 719 to 1,740; timing and cause remain descriptive questions. | [Structural break](reports/07_5_july_2013_structural_break.md) |
| Historical churn definition | What can a 365-day inactivity window establish? | Defines an observed non-return proxy with cutoff eligibility and follow-up constraints. | [Definition analysis](reports/07_churn_definition_analysis.md) |
| Historical labels and reactivation | What happened in the two fully observed 365-day outcome windows? | A_2012 non-return was often followed by later reactivation; B has no later observable year. | [Label construction](reports/08_churn_label_construction.md) |
| Statistical testing | Do customer characteristics differ across returned/non-return groups and snapshots? | Associations vary across regimes and are not causal evidence. | [Statistical analysis](reports/09_statistical_analysis.md) |
| ML feasibility | Do cutoff-safe features generalize across historical regimes? | Cross-regime performance was unreliable; more history and clearer definitions are needed. | [ML feasibility](reports/10_ml_feasibility.md) |
| Power BI preparation | How should validated SQL outputs be modeled and reported? | Model, DAX measures, import guidance, and dashboard specification are documented. | [Preparation report](reports/11_powerbi_preparation.md) |

### Technical implementation

- **SQL:** [exploration](sql/01_exploration/01_database_structure.sql), [data quality](sql/02_data_quality/01_data_quality_checks.sql), [baseline KPIs](sql/03_kpi/01_baseline_kpis.sql), [customer behavior](sql/04_customer_analysis/01_customer_behavior.sql), [cohorts](sql/05_retention/02_cohort_retention.sql), [RF scoring](sql/06_rfm/03_rf_scoring.sql), [historical labels](sql/08_churn_labels/06_churn_labels.sql), [statistical dataset](sql/09_statistics/01_statistical_dataset.sql), and [Power BI validation/model extracts](sql/11_powerbi/).
- **Python:** [statistical analysis](src/analysis/churn_statistics.py), [ML feasibility workflow](src/ml/churn_feasibility.py), [feature pipeline](src/ml/feature_pipeline.py), and [database connection helper](src/database/connection.py).
- **Power BI documentation:** [semantic model](powerbi/data_model.md), [DAX measures](powerbi/dax_measures.md), [dashboard specification](powerbi/dashboard_specification.md), and [import guide](powerbi/import_guide.md).

## Methodology and interpretation

- **Observation window:** order history runs from 2011-05-31 through 2014-06-30. Customers with no observed orders remain in registered-customer counts, but have no post-purchase cohort or purchase-based churn eligibility.
- **First-observed cohorts:** cohort month is each purchaser’s first order in this extract, not necessarily their first-ever purchase. The first cohort month is partial because the observation starts May 31.
- **Exact-month retention:** the denominator is the original cohort size. A cohort contributes to a horizon only if its full target calendar month is observable by June 2014. Observed inactivity is zero; target months beyond the cutoff are NULL/blank, not zero. Rates are weighted across eligible cohorts and describe exact-month activity, not cumulative return within a day window.
- **Historical 365-day non-return:** A_2012 uses cutoff 2012-06-30 and the following fully observed year; B_2013 uses cutoff 2013-06-30 and its following fully observed year ending at the dataset cutoff. “Non-return” means no observed order in that defined follow-up window. It does not prove permanent churn. A’s later reactivation is observable; B’s is not.
- **RF snapshot:** recency/frequency groups are fixed to purchasing customers at 2014-06-30. The project does not call this full RFM because monetary scoring is excluded.
- **Currency:** stored monetary values span currency contexts. Until a conversion basis is resolved, revenue and AOV are excluded from comparable KPI claims and the Power BI reporting model.
- **July 2013:** the order-volume jump is an observed structural shift. The analyses do not prove a campaign, platform change, or other causal explanation.

## Power BI status

Power BI work is at the **preparation/documentation** stage. The repository includes SQL extracts and validation queries plus a semantic-model design, DAX measures, import guide, and dashboard specification. It contains no `.pbix` file or dashboard screenshot, so no built or published dashboard is represented here.

## Repository structure

```text
.
├── queries/                 # Table discovery query
├── reports/                 # Analysis reports, ML metrics, and calibration figure
│   └── figures/
├── sql/                     # Read-only T-SQL by analysis phase
│   ├── 01_exploration/
│   ├── 02_data_quality/
│   ├── 03_kpi/
│   ├── 04_customer_analysis/
│   ├── 05_retention/
│   ├── 06_rfm/
│   ├── 07_5_structural_break/
│   ├── 07_churn_definition/
│   ├── 08_churn_labels/
│   ├── 09_statistics/
│   └── 11_powerbi/
├── src/                     # Python connection, analysis, and ML code
├── scripts/                 # Small environment/driver check
├── notebooks/               # Present; no notebook files currently tracked
├── powerbi/                 # Model, DAX, dashboard, and import documentation
├── requirements.txt         # Python dependencies
└── README.md
```

## Reproducibility

The SQL files use T-SQL and are intended for the configured AdventureWorks2022 database. The project treats that source database as read-only. Python dependency names are listed in [`requirements.txt`](requirements.txt); the repository does not include a pinned environment or a data export.

Local database configuration is handled by the connection helper. Keep credentials in local environment variables / an untracked `.env` file; `.env` is listed in [`.gitignore`](.gitignore). Do not commit credentials or paste them into notebooks, reports, or Power BI query text. The available scripts and analyses require a compatible local SQL Server/ODBC setup and access to the AdventureWorks database.

## Limitations

- The sales history is finite and ends in 2014; later behavior is unavailable and right-censoring affects recent customers.
- “First observed” may not mean first-ever. Zero-order customers cannot be assessed for post-purchase retention.
- A fixed 365-day non-return label is a historical proxy; later return is possible, as demonstrated for A_2012.
- The A_2012 and B_2013 cohorts differ in customer mix and represent different observed regimes; their rates are not causal comparisons.
- ML evaluation is historical and cross-regime generalization was unreliable. The model is a feasibility study, not a deployment-ready churn system.
- Customer structure and product hierarchy are current mappings, not effective-dated histories; monetary comparability is unresolved.
- Observational patterns and statistical associations do not establish causes or intervention impact.

## Project value

This project demonstrates an auditable analytics workflow: verified source relationships, explicit metric grains and denominators, independent KPI reconciliation, cutoff-aware retention and labels, and carefully bounded statistical/ML interpretation. It leaves clear next steps—resolve monetary definitions, obtain longer consistent history, and validate future prediction against a representative prospective period—without overstating what this dataset can support.
