/*
RF scoring only. Recency uses interpolated quintile cutpoints and a CASE rule;
identical RecencyDays always receive identical scores, so score groups may be
unequal when observations tie at a boundary. Frequency is highly tied (over
60% have one order), so use explicit monotonic frequency bands instead of
NTILE: 1 order=1; 2=2; 3=3; 4-5=4; 6+=5. Monetary is not scored.
*/
DECLARE @DatasetEnd date = '20140630';

WITH CustomerRFM AS (
    SELECT CustomerID, MAX(OrderDate) AS LastOrderDate, COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader
    WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), CustomerMeasures AS (
    SELECT CustomerID,
           DATEDIFF(day, CONVERT(date, LastOrderDate), @DatasetEnd) AS RecencyDays,
           Frequency
    FROM CustomerRFM
), RecencyCutpoints AS (
    SELECT DISTINCT
           PERCENTILE_CONT(0.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P20,
           PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P40,
           PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P60,
           PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P80
    FROM CustomerMeasures
), Scored AS (
    SELECT m.CustomerID, m.RecencyDays, m.Frequency,
           CASE WHEN m.RecencyDays <= c.P20 THEN 5
                WHEN m.RecencyDays <= c.P40 THEN 4
                WHEN m.RecencyDays <= c.P60 THEN 3
                WHEN m.RecencyDays <= c.P80 THEN 2 ELSE 1 END AS RScore,
           CASE WHEN m.Frequency = 1 THEN 1
                WHEN m.Frequency = 2 THEN 2
                WHEN m.Frequency = 3 THEN 3
                WHEN m.Frequency BETWEEN 4 AND 5 THEN 4
                ELSE 5 END AS FScore
    FROM CustomerMeasures AS m CROSS JOIN RecencyCutpoints AS c
)
SELECT CustomerID, RecencyDays, Frequency, RScore, FScore
FROM Scored
ORDER BY CustomerID;

-- Report the effective R cut points and score sizes (ties may make groups uneven).
WITH CustomerMeasures AS (
    SELECT CustomerID, DATEDIFF(day, CONVERT(date, MAX(OrderDate)), @DatasetEnd) AS RecencyDays,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader
    WHERE OrderDate < DATEADD(day, 1, @DatasetEnd)
    GROUP BY CustomerID
), Cutpoints AS (
    SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P20,
           PERCENTILE_CONT(.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P40,
           PERCENTILE_CONT(.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P60,
           PERCENTILE_CONT(.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS P80
    FROM CustomerMeasures
), Scored AS (
    SELECT m.CustomerID,
           CASE WHEN m.RecencyDays <= c.P20 THEN 5 WHEN m.RecencyDays <= c.P40 THEN 4
                WHEN m.RecencyDays <= c.P60 THEN 3 WHEN m.RecencyDays <= c.P80 THEN 2 ELSE 1 END AS RScore,
           CASE WHEN m.Frequency = 1 THEN 1 WHEN m.Frequency = 2 THEN 2 WHEN m.Frequency = 3 THEN 3
                WHEN m.Frequency BETWEEN 4 AND 5 THEN 4 ELSE 5 END AS FScore
    FROM CustomerMeasures AS m CROSS JOIN Cutpoints AS c
)
SELECT 'Recency' AS ScoreType, RScore AS Score, COUNT_BIG(*) AS CustomerCount
FROM Scored GROUP BY RScore
UNION ALL
SELECT 'Frequency', FScore, COUNT_BIG(*) FROM Scored GROUP BY FScore
ORDER BY ScoreType, Score;

-- Thresholds and score population summary for documenting tie-aware scoring.
WITH CustomerMeasures AS (
    SELECT CustomerID, DATEDIFF(day, CONVERT(date, MAX(OrderDate)), @DatasetEnd) AS RecencyDays,
           COUNT_BIG(*) AS Frequency
    FROM Sales.SalesOrderHeader WHERE OrderDate < DATEADD(day, 1, @DatasetEnd) GROUP BY CustomerID
)
SELECT DISTINCT PERCENTILE_CONT(.20) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS RecencyP20,
       PERCENTILE_CONT(.40) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS RecencyP40,
       PERCENTILE_CONT(.60) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS RecencyP60,
       PERCENTILE_CONT(.80) WITHIN GROUP (ORDER BY CONVERT(float, RecencyDays)) OVER () AS RecencyP80
FROM CustomerMeasures;
