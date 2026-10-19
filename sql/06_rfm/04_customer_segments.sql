/*
Manageable six-group RF segmentation. Labels describe observed behavior through
2014-06-30 and do not imply churn. R scores are tie-aware recency quintile
bands; F scores preserve equal frequencies. Monetary is descriptive only.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerRFM AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency, SUM(SubTotal) AS MonetaryRaw
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd) GROUP BY CustomerID
), Measures AS (
    SELECT *, DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays,
           DATEDIFF(day, CONVERT(date, FirstOrderDate), CONVERT(date, LastOrderDate)) AS CustomerLifetimeDays
    FROM CustomerRFM
), Cutpoints AS (
    SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P20,
           PERCENTILE_CONT(.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P40,
           PERCENTILE_CONT(.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P60,
           PERCENTILE_CONT(.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P80
    FROM Measures
), Scored AS (
    SELECT m.*,
           CASE WHEN m.RecencyDays <= c.P20 THEN 5 WHEN m.RecencyDays <= c.P40 THEN 4
                WHEN m.RecencyDays <= c.P60 THEN 3 WHEN m.RecencyDays <= c.P80 THEN 2 ELSE 1 END AS RScore,
           CASE WHEN m.Frequency = 1 THEN 1 WHEN m.Frequency = 2 THEN 2 WHEN m.Frequency = 3 THEN 3
                WHEN m.Frequency BETWEEN 4 AND 5 THEN 4 ELSE 5 END AS FScore
    FROM Measures AS m CROSS JOIN Cutpoints AS c
), Labeled AS (
    SELECT *,
      CASE WHEN RScore >= 4 AND FScore >= 4 THEN 'Highly engaged repeat buyers'
           WHEN RScore <= 3 AND FScore >= 4 THEN 'Repeat buyers, longer since purchase'
           WHEN RScore >= 4 AND FScore BETWEEN 2 AND 3 THEN 'Recent developing repeat buyers'
           WHEN RScore <= 3 AND FScore BETWEEN 2 AND 3 THEN 'Developing repeat buyers, longer gap'
           WHEN RScore >= 4 AND FScore = 1 THEN 'Recent one-time buyers'
           ELSE 'One-time buyers, longer since purchase' END AS CustomerSegment
    FROM Scored
)
SELECT CustomerID, FirstOrderDate, LastOrderDate, RecencyDays, Frequency,
       MonetaryRaw AS MonetaryRaw_StoredUnconverted, RScore, FScore, CustomerSegment
FROM Labeled
ORDER BY CustomerID;

-- Segment size and customer behavior profile. Monetary intentionally excluded.
WITH CustomerRFM AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd) GROUP BY CustomerID
), Measures AS (
    SELECT *, DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays,
           CASE WHEN DATEFROMPARTS(YEAR(FirstOrderDate), MONTH(FirstOrderDate), 1) < '20130701'
                THEN 'Before July 2013' ELSE 'July 2013 or later' END AS AcquisitionPeriod
    FROM CustomerRFM
), Cutpoints AS (
    SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P20,
           PERCENTILE_CONT(.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P40,
           PERCENTILE_CONT(.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P60,
           PERCENTILE_CONT(.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P80
    FROM Measures
), Scored AS (
    SELECT m.*,
           CASE WHEN m.RecencyDays <= c.P20 THEN 5 WHEN m.RecencyDays <= c.P40 THEN 4
                WHEN m.RecencyDays <= c.P60 THEN 3 WHEN m.RecencyDays <= c.P80 THEN 2 ELSE 1 END AS RScore,
           CASE WHEN m.Frequency = 1 THEN 1 WHEN m.Frequency = 2 THEN 2 WHEN m.Frequency = 3 THEN 3
                WHEN m.Frequency BETWEEN 4 AND 5 THEN 4 ELSE 5 END AS FScore
    FROM Measures AS m CROSS JOIN Cutpoints AS c
), Labeled AS (
    SELECT *, CASE WHEN RScore >= 4 AND FScore >= 4 THEN 'Highly engaged repeat buyers'
                   WHEN RScore <= 3 AND FScore >= 4 THEN 'Repeat buyers, longer since purchase'
                   WHEN RScore >= 4 AND FScore BETWEEN 2 AND 3 THEN 'Recent developing repeat buyers'
                   WHEN RScore <= 3 AND FScore BETWEEN 2 AND 3 THEN 'Developing repeat buyers, longer gap'
                   WHEN RScore >= 4 AND FScore = 1 THEN 'Recent one-time buyers'
                   ELSE 'One-time buyers, longer since purchase' END AS CustomerSegment
    FROM Scored
), Profiles AS (
    SELECT CustomerSegment,
           COUNT_BIG(*) OVER (PARTITION BY CustomerSegment) AS CustomerCount,
           PERCENTILE_CONT(.50) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerSegment) AS MedianRecencyDays,
           PERCENTILE_CONT(.50) WITHIN GROUP (ORDER BY CONVERT(float, Frequency)) OVER (PARTITION BY CustomerSegment) AS MedianFrequency,
           100.0 * SUM(CASE WHEN Frequency > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY CustomerSegment)
                 / COUNT_BIG(*) OVER (PARTITION BY CustomerSegment) AS RepeatCustomerPercent
    FROM Labeled
)
SELECT CustomerSegment, CustomerCount,
       CAST(100.0 * CustomerCount / SUM(CustomerCount) OVER () AS decimal(7, 3)) AS PercentOfPurchasers,
       MedianRecencyDays, MedianFrequency,
       CAST(RepeatCustomerPercent AS decimal(7, 3)) AS RepeatCustomerPercent
FROM Profiles
GROUP BY CustomerSegment, CustomerCount, MedianRecencyDays, MedianFrequency, RepeatCustomerPercent
ORDER BY CustomerSegment;

-- Segment profiles split by first-observed acquisition period (descriptive only).
WITH CustomerRFM AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd) GROUP BY CustomerID
), Measures AS (
    SELECT *, DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays,
           CASE WHEN DATEFROMPARTS(YEAR(FirstOrderDate), MONTH(FirstOrderDate), 1) < '20130701'
                THEN 'Before July 2013' ELSE 'July 2013 or later' END AS AcquisitionPeriod
    FROM CustomerRFM
), Cutpoints AS (
    SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P20,
           PERCENTILE_CONT(.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P40,
           PERCENTILE_CONT(.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P60,
           PERCENTILE_CONT(.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P80
    FROM Measures
), Scored AS (
    SELECT m.*,
           CASE WHEN m.RecencyDays <= c.P20 THEN 5 WHEN m.RecencyDays <= c.P40 THEN 4
                WHEN m.RecencyDays <= c.P60 THEN 3 WHEN m.RecencyDays <= c.P80 THEN 2 ELSE 1 END AS RScore,
           CASE WHEN m.Frequency = 1 THEN 1 WHEN m.Frequency = 2 THEN 2 WHEN m.Frequency = 3 THEN 3
                WHEN m.Frequency BETWEEN 4 AND 5 THEN 4 ELSE 5 END AS FScore
    FROM Measures AS m CROSS JOIN Cutpoints AS c
), Labeled AS (
    SELECT *, CASE WHEN RScore >= 4 AND FScore >= 4 THEN 'Highly engaged repeat buyers'
                   WHEN RScore <= 3 AND FScore >= 4 THEN 'Repeat buyers, longer since purchase'
                   WHEN RScore >= 4 AND FScore BETWEEN 2 AND 3 THEN 'Recent developing repeat buyers'
                   WHEN RScore <= 3 AND FScore BETWEEN 2 AND 3 THEN 'Developing repeat buyers, longer gap'
                   WHEN RScore >= 4 AND FScore = 1 THEN 'Recent one-time buyers'
                   ELSE 'One-time buyers, longer since purchase' END AS CustomerSegment
    FROM Scored
), Profiles AS (
    SELECT CustomerSegment, AcquisitionPeriod,
           COUNT_BIG(*) OVER (PARTITION BY CustomerSegment, AcquisitionPeriod) AS CustomerCount,
           PERCENTILE_CONT(.50) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER (PARTITION BY CustomerSegment, AcquisitionPeriod) AS MedianRecencyDays,
           PERCENTILE_CONT(.50) WITHIN GROUP (ORDER BY CONVERT(float, Frequency)) OVER (PARTITION BY CustomerSegment, AcquisitionPeriod) AS MedianFrequency,
           100.0 * SUM(CASE WHEN Frequency > 1 THEN 1 ELSE 0 END) OVER (PARTITION BY CustomerSegment, AcquisitionPeriod)
                 / COUNT_BIG(*) OVER (PARTITION BY CustomerSegment, AcquisitionPeriod) AS RepeatCustomerPercent
    FROM Labeled
)
SELECT DISTINCT CustomerSegment, AcquisitionPeriod, CustomerCount, MedianRecencyDays, MedianFrequency,
       CAST(RepeatCustomerPercent AS decimal(7, 3)) AS RepeatCustomerPercent
FROM Profiles ORDER BY CustomerSegment, AcquisitionPeriod;

-- Validation of mutually exclusive and exhaustive segment assignment.
WITH CustomerRFM AS (
    SELECT CustomerID, MIN(OrderDate) AS FirstOrderDate, MAX(OrderDate) AS LastOrderDate,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd) GROUP BY CustomerID
), Measures AS (
    SELECT *, DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays
    FROM CustomerRFM
), Cutpoints AS (
    SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P20,
           PERCENTILE_CONT(.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P40,
           PERCENTILE_CONT(.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P60,
           PERCENTILE_CONT(.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P80
    FROM Measures
), Scored AS (
    SELECT m.CustomerID,
           CASE WHEN m.RecencyDays <= c.P20 THEN 5 WHEN m.RecencyDays <= c.P40 THEN 4
                WHEN m.RecencyDays <= c.P60 THEN 3 WHEN m.RecencyDays <= c.P80 THEN 2 ELSE 1 END AS RScore,
           CASE WHEN m.Frequency = 1 THEN 1 WHEN m.Frequency = 2 THEN 2 WHEN m.Frequency = 3 THEN 3
                WHEN m.Frequency BETWEEN 4 AND 5 THEN 4 ELSE 5 END AS FScore
    FROM Measures AS m CROSS JOIN Cutpoints AS c
), Labeled AS (
    SELECT CustomerID,
           CASE WHEN RScore >= 4 AND FScore >= 4 THEN 'Highly engaged repeat buyers'
                WHEN RScore <= 3 AND FScore >= 4 THEN 'Repeat buyers, longer since purchase'
                WHEN RScore >= 4 AND FScore BETWEEN 2 AND 3 THEN 'Recent developing repeat buyers'
                WHEN RScore <= 3 AND FScore BETWEEN 2 AND 3 THEN 'Developing repeat buyers, longer gap'
                WHEN RScore >= 4 AND FScore = 1 THEN 'Recent one-time buyers'
                ELSE 'One-time buyers, longer since purchase' END AS CustomerSegment
    FROM Scored
), CustomerAssignments AS (
    SELECT CustomerID, COUNT_BIG(*) AS SegmentAssignments
    FROM Labeled GROUP BY CustomerID
)
SELECT COUNT_BIG(*) AS SegmentedCustomerRows,
       COUNT_BIG(DISTINCT CustomerID) AS UniqueSegmentedCustomers,
       SUM(CASE WHEN SegmentAssignments = 1 THEN 1 ELSE 0 END) AS CustomersAssignedExactlyOnce,
       SUM(CASE WHEN SegmentAssignments > 1 THEN 1 ELSE 0 END) AS CustomersAssignedMoreThanOnce
FROM CustomerAssignments;
