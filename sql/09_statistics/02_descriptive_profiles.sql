/* Compact SQL cross-check for the central descriptive profiles.
   Full candidate-variable summaries and distribution tests are generated in
   reports/09_statistical_analysis.md by src/analysis/churn_statistics.py. */
WITH S AS (
 SELECT * FROM (VALUES
 ('A_2012',CONVERT(date,'20120630'),CONVERT(date,'20120701'),CONVERT(date,'20130630')),
 ('B_2013',CONVERT(date,'20130630'),CONVERT(date,'20130701'),CONVERT(date,'20140630'))
 )v(SnapshotID,Cutoff,OutcomeStart,OutcomeEnd)
), F AS (
 SELECT s.SnapshotID,s.Cutoff,h.CustomerID,COUNT_BIG(*) Frequency,
 DATEDIFF(day,MAX(CONVERT(date,h.OrderDate)),s.Cutoff) RecencyDays,
 DATEDIFF(day,MIN(CONVERT(date,h.OrderDate)),MAX(CONVERT(date,h.OrderDate))) CustomerLifetimeDays
 FROM S s JOIN Sales.SalesOrderHeader h ON h.OrderDate<DATEADD(day,1,s.Cutoff)
 GROUP BY s.SnapshotID,s.Cutoff,h.CustomerID
), Y AS (
 SELECT s.SnapshotID,f.CustomerID,CONVERT(int,CASE WHEN EXISTS(
 SELECT 1 FROM Sales.SalesOrderHeader x WHERE x.CustomerID=f.CustomerID AND x.OrderDate>=s.OutcomeStart AND x.OrderDate<DATEADD(day,1,s.OutcomeEnd)
 ) THEN 0 ELSE 1 END) AnalyticalChurn FROM S s JOIN F f ON f.SnapshotID=s.SnapshotID
)
SELECT f.SnapshotID,y.AnalyticalChurn,COUNT_BIG(*) N,
 AVG(CONVERT(float,f.RecencyDays)) MeanRecency,AVG(CONVERT(float,f.Frequency)) MeanFrequency,
 AVG(CONVERT(float,f.CustomerLifetimeDays)) MeanLifetime,
 MIN(f.RecencyDays) MinRecency,MAX(f.RecencyDays) MaxRecency
FROM F f JOIN Y y ON y.SnapshotID=f.SnapshotID AND y.CustomerID=f.CustomerID
GROUP BY f.SnapshotID,y.AnalyticalChurn ORDER BY f.SnapshotID,y.AnalyticalChurn;
