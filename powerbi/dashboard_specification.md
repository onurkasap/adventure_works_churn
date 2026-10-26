# Dashboard specification

Shared visual language: navy `#17324D` for baseline, teal `#168C8C` for activity/retention, muted gold `#E0A83E` to mark July 2013, slate `#64748B` for context, and light gray backgrounds. Use month labels in chronological sort order. State **Observed order history: 2011-05-31 to 2014-06-30** in the footer. Tooltips should define grain and denominator. Avoid currency cards.

## A. Executive Overview

- **Questions:** How many customers registered and purchased? What share of purchasers ordered more than once? How did monthly activity move across the observation period?
- **Cards:** registered customers (19,820, all registered); purchasers (19,119); zero-order registered (701); orders (31,465); repeat customer rate (39.07%, use the explicit Full History measure and label it as such).
- **Visuals:** monthly orders and monthly active purchasing customers as a combo chart; one-time/repeat split as a bar or donut; monthly first-observed purchasers as a line.
- **Fields/measures:** FactOrders OrderDate, SalesOrderID, CustomerID; DimCustomer HasObservedOrder; core measures in `dax_measures.md`.
- **Filters:** order date, customer structure, order territory. Use explicit Full History one-time/repeat measures for baseline cards; use Selected Period measures for slicer-responsive analysis. Registered total can remain all registered and should be labeled accordingly.
- **Interpretation:** distinguish acquisition/activity from repeat behavior. Repeat is 2+ orders in the finite observed extract, not churn.
- **Limitations:** monthly customer counts overlap; registered and purchasing denominators differ; date selection changes purchaser-based measures. No monetary comparison is supported.

## B. Customer Segmentation

- **Questions:** How is the 2014-06-30 purchaser population distributed across the six historical RF groups? How do those groups differ in recency and observed order frequency?
- **Cards:** selected segment customers and share of fixed 19,119 purchasing customers; do not expose them as live date-sensitive scores.
- **Visuals:** sorted horizontal segment bars; dot plot of median/average RecencyDays and Frequency; detail table with segment count and percentage.
- **Fields/measures:** CustomerRFSnapshot CustomerSegment, RScore, FScore, RecencyDays, Frequency, SnapshotDate; DimCustomer structure only with explicit note that structure is current, not effective-dated.
- **Filters:** segment and current customer structure. No date slicer; if page navigation syncs a date slicer, disable its interaction with this page.
- **Interpretation:** RF groups summarize fixed historical recency/frequency. They are not full RFM because monetary scoring was deferred.
- **Limitations:** cutoff 2014-06-30; history begins 2011-05-31; segment sizes validated once per purchaser; not present-day risk or value.

Segments: Highly engaged repeat buyers; Repeat buyers, longer since purchase; Recent developing repeat buyers; Developing repeat buyers, longer gap; Recent one-time buyers; One-time buyers, longer since purchase.

## C. Retention & Cohort

- **Questions:** What fraction of each observed first-purchase-month cohort was active in each exact subsequent calendar month?
- **Cards:** selected cohort size, active customers, single-cell exact-month retention. A weighted KPI requires exactly one MonthIndex and uses one original cohort denominator per observable cohort. Provide the validated weighted M1 1.863%, M3 5.387%, M6 5.986%, M12 10.055% only when showing the full cohort population.
- **Visuals:** heatmap/matrix, cohort months in rows and MonthIndex 0–12 in columns; color by RetentionRate, show `—` for NULL; tooltip includes CohortSize, ActiveCustomers, exact target month.
- **Fields/measures:** CohortRetentionFact CohortMonth, MonthIndex, TargetMonth, CohortSize, ActiveCustomers, RetentionRate.
- **Filters:** CohortMonth and a single-select MonthIndex selector for weighted cards. Multi-index weighted total should be blank. Do not allow unrelated customer/category/territory filters to alter denominator. Use disconnected fact and explain it represents full validated population.
- **Interpretation:** retention is exact-month activity / original eligible cohort size; observed inactivity is 0%, future unobservable is blank. Exact-month retention is not cumulative return within 365 days.
- **Limitations:** first observed purchase is not necessarily first-ever; first cohort month is partial. Cells near the end have shorter observable follow-up.

## D. July 2013 Structural Break

- **Questions:** What changed in the observed order pattern around late June/July 2013, and how did equal six-month windows compare?
- **Cards:** Jan-Jun vs Jul-Dec 2013 orders, average lines per order, online-flag order share. Annotate first weekly lift in week of June 24; shade July 2013.
- **Visuals:** monthly orders and active purchasers; first-observed purchaser line; 100% stacked online/offline flag distribution; product category line-share stacked chart; average lines/order; matched-period comparison table. Optional small multiples by customer structure using DimCustomer current Person/Store links.
- **Fields/measures:** MonthlyBreakReporting monthly values, period label, category shares and basket measure; FactOrders for drill-down. `OnlineOrderFlag` must retain the literal field name/meaning.
- **Filters:** 2013 date range, flag and territory on order-level exploration. State that category and customer-structure history uses current mappings.
- **Interpretation:** several observable shifts coincide, and some appear already in late June. A fair Jan-Jun vs Jul-Dec comparison avoids unequal periods.
- **Limitations:** descriptive association only; no single cause established. Do not claim marketing campaign, pipeline migration, or website launch. Structure and product hierarchy are not effective-dated. No monetary values.

## E. Historical Non-Return Analysis

- **Questions:** How did the separate 2012 and 2013 cutoff populations behave in the next fully observed year? How many Snapshot A non-returners later reactivated?
- **Cards:** require one SnapshotID context. A: 2,799 eligible, 457 returned, 2,342 non-return, 83.673% non-return. B: 6,206 eligible, 5,156 returned, 1,050 non-return, 16.919% non-return. A later reactivation: 2,003 / 2,342 = 85.525%; show “Not observable” for B, never 0%.
- **Visuals:** separate two-bar snapshot outcomes; 100% non-return rate comparison; feature profile small multiples (frequency, recency, online share) split by snapshot and outcome; clear reactivation callout for A.
- **Fields/measures:** HistoricalNonReturnFact SnapshotID, SnapshotDate, AnalyticalNonReturn, ReturnedInNextObservableYear, RecencyDays, Frequency, OnlineOrderShare.
- **Filters:** SnapshotID and label only; use a single-select SnapshotID or separate A/B visuals. SnapshotID + CustomerID is the row key and A/B populations overlap by 2,799 people. No connection to 2014 RF fields and no date slicer.
- **Interpretation:** historical non-return means no order in a defined next 365-day window; 2,003 Snapshot A non-returners later returned in the next observable year.
- **Limitations:** not permanent churn. A/B use different customer mixes and sit across the structural shift. Snapshot B later reactivation is unobservable. Phase 10 model scores are not operational risk indicators; better history/business definitions are needed.

## Methodology tooltip/page

Define registered, purchasing, monthly active, first-observed purchaser, one-time, repeat, cohort size, retained customer, historical non-return and reactivation. Include cutoff dates, exact-month denominator, current-vs-historical dimensions, currency exclusion, and the non-causal structural-break statement. Keep report-page footers short and link to the project methodology document.
