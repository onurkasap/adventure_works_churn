# DAX measures and filter behavior

Create these measures after importing the named tables. Monetary values remain excluded because common-currency interpretation is unresolved. The formulas below assume the single-direction relationships in `data_model.md` and a marked DimDate table.

## Order activity and frequency

```DAX
Total Orders = DISTINCTCOUNT(FactOrders[SalesOrderID])

Purchasing Customers = DISTINCTCOUNT(FactOrders[CustomerID])

Order Lines = DISTINCTCOUNT(FactOrderLines[SalesOrderDetailID])

Monthly Active Customers = [Purchasing Customers]

One-Time Purchasers (Selected Period) =
VAR PerCustomer =
    ADDCOLUMNS(VALUES(FactOrders[CustomerID]), "OrderCount", CALCULATE([Total Orders]))
RETURN COUNTROWS(FILTER(PerCustomer, [OrderCount] = 1))

Repeat Purchasers (Selected Period) =
VAR PerCustomer =
    ADDCOLUMNS(VALUES(FactOrders[CustomerID]), "OrderCount", CALCULATE([Total Orders]))
RETURN COUNTROWS(FILTER(PerCustomer, [OrderCount] >= 2))

Repeat Customer Rate (Selected Period) =
DIVIDE([Repeat Purchasers (Selected Period)], [Purchasing Customers])

Orders per Purchasing Customer = DIVIDE([Total Orders], [Purchasing Customers])

One-Time Purchasers (Full History) =
CALCULATE([One-Time Purchasers (Selected Period)], REMOVEFILTERS(DimDate))

Repeat Purchasers (Full History) =
CALCULATE([Repeat Purchasers (Selected Period)], REMOVEFILTERS(DimDate))

Repeat Customer Rate (Full History) =
DIVIDE([Repeat Purchasers (Full History)], [Purchasing Customers (Full History)])

Purchasing Customers (Full History) =
CALCULATE([Purchasing Customers], REMOVEFILTERS(DimDate))

Total Orders (Full History) =
CALCULATE([Total Orders], REMOVEFILTERS(DimDate))
```

The selected-period measures count a customer's orders within the active DimDate selection; selecting one month can make a customer with many lifetime orders a one-time purchaser for that month. Full-history measures ignore DimDate and cover the imported 2011-05-31 through 2014-06-30 observation window. Both sets still respect other dimension filters such as customer structure and territory. Label them clearly; the validated 11,649 one-time, 7,470 repeat, and 39.07% rate are full-history figures.

## Product filter behavior

With single-direction relationships, DimProduct filters FactOrderLines only. It does not filter FactOrders, so `[Total Orders]` remains the total for the selected date/customer/territory context when a product slicer is used. That is intentional and avoids an unsafe reverse relationship from lines to headers. If the business question is orders containing the selected product/category, define an explicit measure:

```DAX
Orders Containing Selected Product =
VAR MatchingOrders = VALUES(FactOrderLines[SalesOrderID])
RETURN
    CALCULATE(
        [Total Orders],
        TREATAS(MatchingOrders, FactOrders[SalesOrderID])
    )
```

For purchasers or one-time/repeat frequency restricted to orders containing a product, use the same explicit matching-order set as a documented virtual filter at the intended grain. Do not just count FactOrderLines rows as orders or change the relationship to bidirectional. A product selection can also mean "customers who ever bought this product, with their full selected-period order history"; that is a different question and needs a separately named customer-set measure.

## Fixed RF snapshot

```DAX
RF Segment Customers = DISTINCTCOUNT(CustomerRFSnapshot[CustomerID])
```

The RF table is one row per purchaser at 2014-06-30 and is disconnected from DimDate. Use its segment counts only for that fixed snapshot. Do not imply date-sliced or current segments.

## Cohort retention

The SQL fact is one row per CohortMonth x MonthIndex. Its CohortSize repeats across each month index for a cohort. `RetentionRate` and `ActiveCustomers` are NULL/blank for target months beyond 2014-06; observed inactive cells have zero. Keep this fact disconnected from DimDate, customer, product, and territory dimensions.

```DAX
Cohort Cell Retention =
IF(
    HASONEVALUE(CohortRetentionFact[CohortMonth])
        && HASONEVALUE(CohortRetentionFact[MonthIndex]),
    SELECTEDVALUE(CohortRetentionFact[RetentionRate]),
    BLANK()
)

Cohort Cell Active Customers =
IF(
    HASONEVALUE(CohortRetentionFact[CohortMonth])
        && HASONEVALUE(CohortRetentionFact[MonthIndex]),
    SELECTEDVALUE(CohortRetentionFact[ActiveCustomers]),
    BLANK()
)

Cohort Cell Size =
IF(
    HASONEVALUE(CohortRetentionFact[CohortMonth]),
    SELECTEDVALUE(CohortRetentionFact[CohortSize]),
    BLANK()
)

Weighted Cohort Retention (Selected MonthIndex) =
VAR OneMonthIndex = HASONEVALUE(CohortRetentionFact[MonthIndex])
VAR EligibleCohorts =
    FILTER(
        ADDCOLUMNS(
            VALUES(CohortRetentionFact[CohortMonth]),
            "CellRate", CALCULATE(MAX(CohortRetentionFact[RetentionRate])),
            "CellActive", CALCULATE(MAX(CohortRetentionFact[ActiveCustomers])),
            "FixedSize", CALCULATE(MAX(CohortRetentionFact[CohortSize]))
        ),
        NOT ISBLANK([CellRate])
    )
VAR ActiveTotal = SUMX(EligibleCohorts, [CellActive])
VAR CohortTotal = SUMX(EligibleCohorts, [FixedSize])
RETURN
    IF(OneMonthIndex, DIVIDE(ActiveTotal, CohortTotal), BLANK())
```

The weighted measure requires exactly one MonthIndex. It iterates each visible cohort once, excludes only unobservable blank cells, keeps observed zero-activity cohorts in the denominator, and never sums repeated cohort sizes across MonthIndex values. It returns BLANK for a multi-index total. With all cohorts selected, validate MonthIndex 1, 3, 6, and 12 at 1.863%, 5.387%, 5.986%, and 10.055% respectively. A cohort-month matrix should use `Cohort Cell Retention`; future cells stay blank. Avoid averaging cell percentages to make a weighted total.

## Historical non-return and reactivation

HistoricalNonReturnFact has composite row grain SnapshotID + CustomerID. A customer present in both snapshots is two snapshot observations, not one globally unique row. The snapshot-level measures below deliberately require one selected SnapshotID. For a cross-snapshot *row* total, use the explicitly named row measure; it counts snapshot-customer records, so shared people count once per snapshot.

```DAX
Historical Snapshot Rows = COUNTROWS(HistoricalNonReturnFact)

Historical Eligible Customers (Selected Snapshot) =
IF(
    HASONEVALUE(HistoricalNonReturnFact[SnapshotID]),
    DISTINCTCOUNT(HistoricalNonReturnFact[CustomerID]),
    BLANK()
)

Historical Non-Returners (Selected Snapshot) =
IF(
    HASONEVALUE(HistoricalNonReturnFact[SnapshotID]),
    CALCULATE(
        DISTINCTCOUNT(HistoricalNonReturnFact[CustomerID]),
        HistoricalNonReturnFact[AnalyticalNonReturn] = TRUE()
    ),
    BLANK()
)

Historical Non-Return Rate (Selected Snapshot) =
DIVIDE(
    [Historical Non-Returners (Selected Snapshot)],
    [Historical Eligible Customers (Selected Snapshot)]
)

Historical Returned Customers (Selected Snapshot) =
IF(
    HASONEVALUE(HistoricalNonReturnFact[SnapshotID]),
    CALCULATE(
        DISTINCTCOUNT(HistoricalNonReturnFact[CustomerID]),
        HistoricalNonReturnFact[AnalyticalNonReturn] = FALSE()
    ),
    BLANK()
)

Historical Reactivated A Non-Returners =
VAR OneSnapshot = HASONEVALUE(HistoricalNonReturnFact[SnapshotID])
VAR SnapshotName = SELECTEDVALUE(HistoricalNonReturnFact[SnapshotID])
RETURN
    IF(
        NOT OneSnapshot || SnapshotName <> "A_2012",
        BLANK(),
        CALCULATE(
            DISTINCTCOUNT(HistoricalNonReturnFact[CustomerID]),
            HistoricalNonReturnFact[AnalyticalNonReturn] = TRUE(),
            HistoricalNonReturnFact[ReturnedInNextObservableYear] = TRUE()
        )
    )

Historical Reactivation Rate A =
DIVIDE(
    [Historical Reactivated A Non-Returners],
    CALCULATE(
        [Historical Non-Returners (Selected Snapshot)],
        HistoricalNonReturnFact[SnapshotID] = "A_2012"
    )
)
```

The reactivation numerator is restricted to A_2012 analytical non-returners and the denominator is those same 2,342 A_2012 non-returners. Snapshot B has no later observable year: reactivation measures intentionally return BLANK for B and for no/multiple snapshot selection. Label B as “Not observable,” rather than 0%. With one snapshot selected, validate A as 2,799 eligible (457 returned, 2,342 non-return) and B as 6,206 (5,156 returned, 1,050 non-return). The 2,003 A reactivations equal 85.525% of A non-returners.

For registered customers, use `DISTINCTCOUNT(DimCustomer[CustomerID])`; this includes 701 customers without observed orders and is not the purchaser denominator. No AOV, revenue, subtotal, TotalDue, or unit-price measures belong on the executive page.
