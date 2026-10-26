# Power BI Desktop import and refresh guide

## First import

Import **FactOrders** first from `sql/11_powerbi/01_fact_orders.sql`; verify 31,465 rows and 31,465 distinct SalesOrderID values. Then import FactOrderLines and reconcile the line table to 121,317 source detail rows. Import DimCustomer, DimProduct, DimTerritory, then the three fixed snapshot facts and MonthlyBreakReporting. Import CohortRetentionFact last so NULL future cells can be checked explicitly. SQL files contain SELECT-only statements and can be pasted into Power BI Desktop > Get data > SQL Server > Advanced options. Select the existing AdventureWorks2022 database and use the configured trusted local authentication method. No credential should be placed in the PBIX query text or repository.

DimDate is generated inside Power BI using `CALENDAR(DATE(2011,5,31), DATE(2014,6,30))`; add Year, Month Number, Month Name, Month Start, Year-Month label, and numeric YearMonth sort key. Mark it as the date table. Use date-only fields, since order timestamp time components are intentionally removed in FactOrders.

## Relationships

Apply the one-to-many, single-direction relationships described in `data_model.md`. Connect FactOrders to FactOrderLines by SalesOrderID; DimCustomer and order-role DimTerritory to FactOrders; DimDate to FactOrders[OrderDate]; DimProduct to FactOrderLines[ProductID]. Leave cohort, historical snapshot, RF, and monthly aggregate facts disconnected from DimDate. Do not create a circular or ambiguous path. Use role-playing territory dimensions only if customer territory and order territory are both required.

Create measures from `dax_measures.md`. Hide raw keys from report view where they are not needed for drill-through. Set percentages to percentage formatting and counts to whole numbers. Use explicit Full History vs Selected Period frequency measures. Weighted cohort cards require one MonthIndex; cross-index totals should be blank. Historical snapshot rate cards require one SnapshotID. Reactivation is defined only for A_2012; show “Not observable” for B_2013. Do not load monetary fields.

## Post-import validation checklist

1. FactOrders has 31,465 rows and unique SalesOrderID; distinct customers = 19,119.
2. DimCustomer has 19,820 rows; 701 have HasObservedOrder = 0.
3. FactOrderLines has 121,317 rows and distinct SalesOrderDetailID; detail totals reconcile independently.
4. One-time = 11,649; repeat = 7,470; sum = 19,119; repeat rate = 39.07% with full date window.
5. CustomerRFSnapshot has 19,119 unique customers, each assigned once, across six labels. Date slicers do not change counts.
6. Cohort month sizes sum to 19,119; MonthIndex 0 active count equals each cohort size. Verify weighted exact-month rates M1 1.863%, M3 5.387%, M6 5.986%, M12 10.055%.
7. Cohort future target months remain blank; observed zero-activity cells display 0%.
8. HistoricalNonReturnFact has 2,799 A rows and 6,206 B rows, one row per snapshot/customer. Label counts match 457/2,342 and 5,156/1,050 respectively.
9. Snapshot A reactivation is 2,003 of 2,342. Snapshot B reactivation remains blank/unobservable.
10. Historical snapshot overlap is validated using eligible populations; do not combine records as independent customers without considering overlap.
11. Monthly break table covers the observation months. Jan-Jun and Jul-Dec 2013 are equal six-month windows, and visual marks July 2013 while acknowledging late-June timing.
12. Product category shares and average lines/order reconcile at line grain; no line join duplicates order-header measures.

## Focused Desktop DAX validation

1. **Cohorts:** Add a matrix with CohortMonth rows, MonthIndex columns, and `Cohort Cell Retention` values. Check a known MonthIndex 0 cell is 100%, observed inactive cells are 0%, and future cells are blank. Add a single-select MonthIndex slicer and a card for `Weighted Cohort Retention (Selected MonthIndex)`. Check M1 = 1.863%, M3 = 5.387%, M6 = 5.986%, M12 = 10.055% with all cohorts selected. Clear the slicer or select multiple indices: the weighted card must be blank. The sum of cohort denominators must include each eligible cohort once, not once per index.
2. **Snapshots:** Add a SnapshotID slicer and cards for eligible customers, returned, non-return, and non-return rate. A_2012 must show 2,799, 457, 2,342, 83.673%; B_2013 must show 6,206, 5,156, 1,050, 16.919%. With no single snapshot selected, those measures should be blank. A visual row count across both snapshots may show 9,005 customer-snapshot rows; it is not 9,005 unique people. A/B overlap is 2,799.
3. **Reactivation:** In A_2012 context, the card must show 2,003 / 2,342 = 85.525%. In B_2013 context it must be blank and the visual label should say “Not observable.” Test no snapshot and multi-snapshot context; the measure must also be blank.
4. **Date behavior:** Build cards for Full History and Selected Period one-time/repeat counts. With all dates selected, the full-history measures reconcile to 11,649 and 7,470. Select one month: selected-period counts recalculate within that month, while full-history measures stay fixed (other customer/territory filters can still change both). Explain that one-time means exactly one order within the named window.
5. **Product behavior and grain:** Add a product category slicer. `Order Lines` and line-based basket visuals should respond; ordinary `Total Orders` should not, because the product dimension cannot filter back through the single-direction relationship. `Orders Containing Selected Product` should respond. Verify it uses distinct SalesOrderID and does not count line rows as orders. Date/customer/territory filters should affect both header and line activity through FactOrders.
6. **Relationship check:** In Model view confirm every relationship is single-direction, no direct relationship joins snapshot/cohort facts to DimDate, and no product-to-header bidirectional path exists. Recheck total orders at 31,465 before slicers.

Refresh is a new read-only extract. Re-run the SQL validation queries and compare the observed period, counts, snapshot labels, and cohort NULL behavior before replacing the validated data. Do not refresh historical snapshots to a later cutoff without treating that as a new analytical definition.
