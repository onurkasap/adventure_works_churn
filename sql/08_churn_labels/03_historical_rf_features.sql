/* Snapshot-specific R/F scoring. Tied recency values share a score; frequency
   uses explicit monotone bands to preserve ties. No monetary score is used. */
WITH S AS (
 SELECT * FROM (VALUES ('A_2012',CONVERT(date,'20120630')),('B_2013',CONVERT(date,'20130630'))) v(SnapshotID,SnapshotDate)
), F AS (
 SELECT s.SnapshotID,s.SnapshotDate,h.CustomerID,COUNT_BIG(*) Frequency,
        DATEDIFF(day,CONVERT(date,MAX(h.OrderDate)),s.SnapshotDate) RecencyDays
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.SnapshotDate)
 GROUP BY s.SnapshotID,s.SnapshotDate,h.CustomerID
), P AS (
 SELECT DISTINCT SnapshotID,
  PERCENTILE_CONT(.2) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P20,
  PERCENTILE_CONT(.4) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P40,
  PERCENTILE_CONT(.6) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P60,
  PERCENTILE_CONT(.8) WITHIN GROUP(ORDER BY CONVERT(float,RecencyDays)) OVER(PARTITION BY SnapshotID) P80 FROM F
), X AS (
 SELECT f.*,p.P20,p.P40,p.P60,p.P80,
  CASE WHEN RecencyDays<=P20 THEN 5 WHEN RecencyDays<=P40 THEN 4 WHEN RecencyDays<=P60 THEN 3 WHEN RecencyDays<=P80 THEN 2 ELSE 1 END RScore,
  CASE WHEN Frequency=1 THEN 1 WHEN Frequency=2 THEN 2 WHEN Frequency=3 THEN 3 WHEN Frequency<=5 THEN 4 ELSE 5 END FScore
 FROM F f JOIN P p ON p.SnapshotID=f.SnapshotID
)
SELECT *,CONCAT('R',RScore,'F',FScore) RFCode,
 CASE WHEN RScore>=4 AND FScore>=4 THEN 'Recent/high-frequency RF'
      WHEN RScore>=4 AND FScore<=2 THEN 'Recent first/low-frequency'
      WHEN RScore=3 THEN 'Middle RF'
      WHEN RScore<=2 AND FScore>=4 THEN 'At-risk high-frequency'
      WHEN RScore<=2 AND FScore<=2 THEN 'Hibernating/low-frequency'
      ELSE 'Other RF' END RFSegment
FROM X ORDER BY SnapshotDate,CustomerID;
