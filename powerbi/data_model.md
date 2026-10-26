# Power BI semantic model

## Observation and design

The order observation window is **2011-05-31 through 2014-06-30**. Native AdventureWorks tables are queried read-only. The model separates order-header activity from order-line mix, and keeps fixed historical analyses in independent facts. This prevents line multiplication and prevents a report date slicer from silently changing a fixed cutoff population.

| Table | Grain / key | Relationships in the report | Notes |
|---|---|---|---|
| FactOrders | One row per `SalesOrderID` | DimCustomer 1:* by CustomerID; DimTerritory (order role) 1:* by TerritoryID; DimDate 1:* by OrderDate | Header metrics only. No monetary columns. |
| FactOrderLines | One row per `SalesOrderDetailID`; composite source product lookup validated through SpecialOfferID + ProductID | FactOrders 1:* on SalesOrderID; DimProduct 1:* on ProductID | Do not count orders by row count here. |
| DimCustomer | One row per registered CustomerID | 1:* to FactOrders; inactive/no relationship to snapshot facts by default | Includes zero-order customers and current Person/Store structure. |
| DimProduct | One row per ProductID | 1:* to FactOrderLines | Current hierarchy is not effective-dated. |
| DimTerritory | One row per TerritoryID | Role-playing copies for order territory and customer-assigned territory if both used | These fields answer different questions. Avoid both active paths to the same fact. |
| DimDate | One row per calendar date, 2011-05-31 to 2014-06-30 | 1:* active to FactOrders[OrderDate] | Create in Power BI; mark as date table. Use month-start and year-month sort key. |
| CustomerRFSnapshot | One row per purchasing CustomerID at 2014-06-30 | Disconnected from DimDate; optionally DimCustomer 1:* to RF | Snapshot labels and frequency are fixed. Do not recalculate through slicers. |
| CohortRetentionFact | One row per CohortMonth x MonthIndex (with active and NULL rows) | Disconnected from DimDate and DimCustomer | CohortSize denominator is fixed; filters do not redefine cohort membership. |
| HistoricalNonReturnFact | One row per SnapshotID x eligible CustomerID | Disconnected from DimDate; optional disconnected snapshot selector | Two cutoff/outcome periods, distinct from 2014 RF snapshot. |
| MonthlyBreakReporting | One row per month | Disconnected aggregate for break visuals | Pre-aggregated metrics. Do not join it to detail or use it for customer-level drill. |

Use **single-direction** filtering from dimensions to facts. The FactOrders-to-FactOrderLines relationship is one-to-many and single-direction from header to lines. It lets selected orders scope line visuals; never enable bidirectional filtering globally. Product filters affect line visuals, and should not be expected to filter FactOrders unless a measure explicitly transfers the distinct matching SalesOrderID set with `TREATAS`. Territory and date slicers affect FactOrders and line measures through the header path. Customer slicers affect both through the same path. This means a product selection alone does not change ordinary order or customer counts.

Do not connect cohort rows directly to order dates: CohortMonth is acquisition month, while MonthIndex describes a relative target month. The target month is already materialized. Preserve SQL NULL as blank in Power BI. CohortRetentionFact has one row per CohortMonth x MonthIndex and repeats cohort size for each index. For one selected MonthIndex, calculate weighted retention by iterating each cohort once, summing active customers and original size only for observable cells. Require exactly one MonthIndex for a weighted KPI; a multi-index total is undefined and should be blank. A user/customer/territory filter applied to this disconnected fact does not recalculate its denominator. Disable unrelated slicers on the cohort page or explain that the cohort table is the full validated population.

The RF and historical snapshot facts are not interchangeable. RF is a 2014-06-30 full extract snapshot; A and B use 2012-06-30 and 2013-06-30 cutoffs, with separate subsequent-year outcomes. HistoricalNonReturnFact's key is the composite SnapshotID + CustomerID: 2,799 A customers also occur in B, so a cross-snapshot row count is not a distinct-person count. Snapshot-level measures require one SnapshotID; an explicitly named row total counts customer-snapshot records. Reactivation is only observable for A. A relationship between RF and historical facts could leak future fields into historical outcomes. Keep them isolated.

Potential many-to-many errors: counting order headers through line rows; joining product-category data to headers without aggregation; connecting multiple territory roles actively; or relating cohort month and target month to the same date dimension. Maintain documented keys and native grains.

SQL deliverables in `sql/11_powerbi/` reproduce the Phase 3, 5, 6, 7.5, and 8 logic. Power BI cannot be verified in this environment, so this is a semantic model design, not a claim of a built PBIX.
