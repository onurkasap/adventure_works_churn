# Project guidance

This is a learning-focused, end-to-end data analytics project using SQL Server, the AdventureWorks database, SQL, Python, pandas, statistics, machine learning, and Power BI. Prefer clear, explainable work that helps the learner understand each analytical decision.

## Source database safety

- Treat the AdventureWorks source database as strictly read-only. Never modify it.
- Never execute `DROP`, `DELETE`, `UPDATE`, `INSERT`, `TRUNCATE`, or `ALTER` statements against AdventureWorks.
- Use read-only queries for discovery and analysis. Do not assume that a query is safe merely because it is part of an analysis workflow.
- Never expose database credentials in source files, notebooks, reports, logs, or committed configuration. Use environment variables for local credentials and keep `.env` untracked.

## SQL and schema

- Inspect the actual AdventureWorks schema and sample data before relying on table or column names, relationships, or data types. Do not assume a column exists based on familiarity with AdventureWorks or an earlier project.
- Use SQL Server/T-SQL syntax.
- Store SQL in the existing `queries/` directory, organized by purpose: `exploration/`, `data_quality/`, `kpis/`, `customer_analysis/`, `cohort_analysis/`, and `churn_analysis/`.
- Keep SQL readable and educational. Use clear names, formatting, and comments where they help explain intent.
- Explain non-obvious joins, CTEs, and window functions, including why they are appropriate and what rows they preserve or produce.

## Analytical standards

- Start from a clear business question. Define each business metric explicitly before calculating it.
- Never silently invent a business definition. If a definition is missing, state the assumption clearly and seek clarification when it materially affects the result.
- Distinguish facts observed in the data from business assumptions and interpretation.
- Validate important KPIs with an independent check, such as a separate query, a reconciliation, or a calculation through a different method. Explain material discrepancies.
- Check data quality and relevant caveats before drawing conclusions. Avoid presenting correlation or model output as causation.

## Python, notebooks, and reporting

- Put reusable Python code under `src/`.
- Use notebooks mainly for exploration, learning, and documenting analytical reasoning. Keep reusable logic in `src/` rather than duplicating it across notebooks.
- Use pandas and statistical or machine-learning methods only when they fit the question and the available data. Explain key choices, assumptions, and limitations.
- Keep visualizations and business interpretation tied to the defined metrics and validated findings.
- Do not include credentials or other secrets in notebooks, reports, charts, or exported artifacts.

## Project workflow

Follow this workflow unless the business question calls for a clearly explained adjustment:

1. Business question
2. Data discovery
3. Data quality
4. Metric definition
5. SQL analysis
6. Validation
7. Python or statistical analysis when appropriate
8. Visualization
9. Business interpretation

Explain important analytical decisions in plain language so the project remains useful as a learning resource.
