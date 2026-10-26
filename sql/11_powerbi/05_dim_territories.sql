/* Customer assigned territory and order recorded territory are distinct roles.
   Import once; create role-playing copies in Power BI if both are needed. */
SELECT t.TerritoryID, t.Name AS TerritoryName, t.CountryRegionCode,
       t.[Group] AS TerritoryGroup
FROM Sales.SalesTerritory AS t;
