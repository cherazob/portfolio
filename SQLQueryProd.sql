USE Projects
GO

-- Productivity and employment information

-- Check if the table exists everytime we run the query and delete it to avoid errors

IF EXISTS (
			SELECT *
			FROM sys.tables
			WHERE name = 'productivity'
		  )
DROP TABLE productivity
GO
-- Preview of the table

SELECT *
FROM OECD_PROD

-- Instert the information in a new table to avoid tampering with the original information

SELECT STRUCTURE_NAME, REF_AREA, [Reference area], Measure, [Unit of measure], PRICE_BASE, [Price base], TIME_PERIOD, OBS_VALUE, [Unit multiplier]
INTO productivity
FROM OECD_PROD
GO
-- Deleting information in national currencies to analyze all the data in USD

DELETE FROM productivity
WHERE PRICE_BASE = 'Q' OR
	  [Unit of measure] = 'National currency' OR
	  [Unit of measure] = 'National currency per person' OR
	  [Unit of measure] = 'National currency per hour'
GO
-- Data check up and normalization

ALTER TABLE productivity
ALTER COLUMN OBS_VALUE FLOAT

ALTER TABLE productivity
ALTER COLUMN TIME_PERIOD SMALLINT

UPDATE productivity
SET OBS_VALUE = ROUND(OBS_VALUE * 1000.00,2)
WHERE [Unit multiplier] = 'Thousands'

UPDATE productivity
SET OBS_VALUE = ROUND(OBS_VALUE * 1.00,2)
WHERE [Unit multiplier] = 'Units'

UPDATE productivity
SET OBS_VALUE = ROUND(OBS_VALUE * 1000000.00,2)
WHERE [Unit multiplier] = 'Millions'

UPDATE productivity
SET OBS_VALUE = ROUND(OBS_VALUE, 0)
WHERE Measure = 'Population'

UPDATE productivity
SET [Unit of measure] = '"' + [Unit of measure] + '"'

ALTER TABLE productivity
DROP COLUMN [Unit multiplier]
ALTER TABLE productivity
DROP COLUMN PRICE_BASE

SELECT * FROM productivity
ORDER BY REF_AREA, TIME_PERIOD
GO
-- Unemployment information

-- Dropping the unemployment table if exists before every run to avoid errors

IF EXISTS (
			SELECT *
			FROM sys.tables
			WHERE name = 'unemployment'
		  )
DROP TABLE unemployment
GO
-- Create a new table with unemployment information to avoid tampering with the original information

SELECT STRUCTURE_NAME, REF_AREA, [Reference area], Measure, [Unit of measure], TIME_PERIOD, OBS_VALUE, [Unit multiplier]
INTO unemployment
FROM OECD_UN
GO
-- Data check up and normalization

ALTER TABLE unemployment
ALTER COLUMN OBS_VALUE FLOAT

ALTER TABLE unemployment
ALTER COLUMN TIME_PERIOD SMALLINT

UPDATE unemployment
SET OBS_VALUE = ROUND(OBS_VALUE * 1000.00,0)
WHERE [Unit multiplier] = 'Thousands'

ALTER TABLE unemployment
DROP COLUMN [Unit multiplier]

SELECT * FROM unemployment
ORDER BY REF_AREA, TIME_PERIOD
GO
-- Join both tables (Union)

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'temp_t'
		   )
		   DROP TABLE temp_t
GO
IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'OECD'
		   )
		   DROP TABLE OECD
GO

SELECT *
INTO temp_t
FROM productivity
WHERE TIME_PERIOD = 2023
UNION ALL
SELECT STRUCTURE_NAME,REF_AREA, [Reference area], Measure, [Unit of measure], 'Not applicable', TIME_PERIOD, OBS_VALUE 
FROM unemployment
WHERE TIME_PERIOD = 2023
ORDER BY REF_AREA, TIME_PERIOD
GO

SELECT *
FROM temp_t

-- We need to pivot the table to be able to visualize and use the information properly

SELECT REF_AREA, [Reference area], [Population],[Employment],[Unemployment],[Gross domestic product], [GDP per person employed], [GDP per hour worked],
       [GDP per capita], [Labour utilisation (hours worked per head of population)],[Average hours worked per person employed],[Hours worked for total employment]
INTO OECD
FROM (SELECT REF_AREA, [Reference area], Measure, OBS_VALUE  -- Restricted selection
      FROM temp_t) AS source
PIVOT(
    AVG(OBS_VALUE)
    FOR Measure IN ([Employment], [Population], [Gross domestic product], [GDP per person employed], [GDP per hour worked],
                   [GDP per capita], [Labour utilisation (hours worked per head of population)],[Average hours worked per person employed],[Hours worked for total employment],
                   [Unemployment])) AS Ptable
GO

SELECT *
FROM OECD

-- Update table with missing information

UPDATE OECD
SET [Reference area] = 'China'
WHERE REF_AREA = 'CHN'

UPDATE OECD
SET [Reference area] = 'Turkiye'
WHERE REF_AREA = 'TUR'

UPDATE OECD
SET [Population] = 1422584933
WHERE REF_AREA = 'CHN'

UPDATE OECD
SET [Population] = 281190067
WHERE REF_AREA = 'IDN'
GO
-- We need specific data for each country, so we need to delete country grouppings

DELETE FROM OECD
WHERE REF_AREA = 'G7' OR
	  REF_AREA = 'EA20' OR
	  REF_AREA = 'EU27_2020' OR
	  REF_AREA = 'OECD'
GO
-- Replace Null values with '0'

UPDATE OECD
SET [Population] = COALESCE([Population],0),
	[Employment] = COALESCE([Employment],0),
	[Unemployment] = COALESCE([Unemployment],0),
	[Gross domestic product] = COALESCE([Gross domestic product],0),
	[GDP per person employed] = COALESCE([GDP per person employed],0),
	[GDP per hour worked] = COALESCE([GDP per hour worked],0),
	[GDP per capita] = COALESCE([GDP per capita],0),
	[Labour utilisation (hours worked per head of population)] = COALESCE( [Labour utilisation (hours worked per head of population)],0),
	[Average hours worked per person employed] = COALESCE([Average hours worked per person employed],0),
	[Hours worked for total employment] = COALESCE([Hours worked for total employment],0)
GO
-- Update missing values

UPDATE OECD
SET [Gross domestic product] = 34660138180000 WHERE REF_AREA = 'CHN'
UPDATE OECD
SET	[Gross domestic product] = 4334715230000 WHERE REF_AREA = 'IDN'
GO

SELECT *
FROM OECD

SELECT * FROM debt

-- We need to include corruption index and debt information. For this we join the OECD table with tha corruption table 
-- and add a column with debt information from the debt table

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'gdp_stats'
		   )
DROP TABLE gdp_stats
GO

SELECT O.*, CASE WHEN D.[Last] LIKE '1__' THEN ROUND(D.[Last]/1,2)
				 WHEN D.[Last] LIKE '____' THEN ROUND(D.[Last]/100,2)
			ELSE ROUND(D.[Last]/10,2)
			END AS [Debt as percent of GDP],
			C.[Previous] AS [Corruption index]
INTO gdp_stats
FROM OECD AS O
LEFT JOIN debt as D
	ON O.[Reference area] = D.[Reference area]
	LEFT JOIN corrupt AS C
		ON O.[Reference area] = C.[Reference area]
GO
-- Add missing information about corruption and debt

UPDATE gdp_stats
SET [Debt as percent of GDP] = 51.5,
	[Corruption index] = 63
WHERE REF_AREA = 'KOR'

UPDATE gdp_stats
SET [Debt as percent of GDP] = 56.1,
	[Corruption index] = 54
WHERE REF_AREA = 'SVK'

UPDATE gdp_stats
SET [Debt as percent of GDP] = 44,
	[Corruption index] = 57
WHERE REF_AREA = 'CZE'

UPDATE gdp_stats
SET [Debt as percent of GDP] = 263
WHERE REF_AREA = 'JPN'

UPDATE gdp_stats
SET [Debt as percent of GDP] = 29.5,
	[Corruption index] = 34,
	[Average hours worked per person employed] = 2252,
	[GDP per hour worked] = 61.3,
	[Hours worked for total employment] = 79737996000,
	[Labour utilisation (hours worked per head of population)] = 934.51
WHERE REF_AREA = 'TUR'
GO
-- I relalize that China and Indonesia are not YET members of OECD so we delete them

DELETE FROM gdp_stats
WHERE REF_AREA = 'CHN' OR
	  REF_AREA = 'IDN'
GO
-- This will be one of our two final tables. Let's check for duplicates and nulls.

SELECT REF_AREA, [Reference area], COUNT(*) AS DUPLICATES
FROM gdp_stats
GROUP BY REF_AREA, [Reference area]
HAVING COUNT(*) >1

SELECT *
FROM gdp_stats
WHERE REF_AREA IS NULL OR [Reference area] IS NULL OR Population IS NULL OR
	  Employment IS NULL OR Unemployment IS NULL OR [Gross domestic product] IS NULL OR
	  [GDP per person employed] IS NULL OR [GDP per hour worked] IS NULL OR
	  [GDP per capita] IS NULL OR [Labour utilisation (hours worked per head of population)] IS NULL OR
	  [Average hours worked per person employed] IS NULL OR [Hours worked for total employment] IS NULL OR
	  [Debt as percent of GDP] IS NULL OR [Corruption index] IS NULL
GO

-- We add a rank Country by several stats, which will help our visuals. We could have done it here, but this table will be
-- exported separately and joined with gdp_stats in Tableau. The following two tables will be our second working table

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'gdp_ranks'
		   )
DROP TABLE gdp_ranks
GO

SELECT REF_AREA, [Reference area], RANK() OVER (ORDER BY [Gross domestic product] DESC) AS GDP_RANK, RANK() OVER (ORDER BY [Corruption index] DESC) AS Corruption_index_RANK,
	   RANK() OVER (ORDER BY [GDP per capita] DESC) AS GDP_capita_RANK, RANK() OVER (ORDER BY [Average hours worked per person employed] DESC) AS AVG_hours_person_RANK,
	   RANK() OVER (ORDER BY [Population] DESC) AS Population_RANK, RANK() OVER (ORDER BY [Debt as percent of GDP] DESC) AS DebpGDP_RANK,
	   ROUND([Gross domestic product]/[Hours worked for total employment],2) AS Productivity, RANK() OVER(ORDER BY [Gross domestic product]/[Hours worked for total employment] DESC) AS Prod_RANK
INTO gdp_ranks
FROM gdp_stats
ORDER BY REF_AREA
GO

SELECT *
FROM gdp_stats

DROP TABLE productivity
DROP TABLE OECD
DROP TABLE temp_t
DROP TABLE unemployment
GO

-- Tables for Analysis

--Countries by GDP,PPP

SELECT TOP 15 [Reference area], LEFT([Gross domestic product]/1000000000,7)+'B' AS GDP
FROM gdp_stats
ORDER BY [Gross domestic product] DESC
GO

-- Country by Population, Employment rate and their GDP rank in OECD

SELECT TOP 15 S.[Reference area], S.Population, LEFT(S.Employment*100.00/S.Population, 5)+'%' AS [Emplyment Rate], R.GDP_RANK
FROM gdp_stats AS S
JOIN gdp_ranks AS R
	ON S.REF_AREA = R.REF_AREA
ORDER BY Population DESC
GO

-- Productivity vs GDP

SELECT TOP 15 S.[Reference area], R.Productivity, LEFT(S.[Gross domestic product]/1000000000, 7)+'B' AS [GDP,PPP], R.GDP_RANK
FROM gdp_stats AS S
JOIN gdp_ranks AS R
	ON S.REF_AREA = R.REF_AREA
ORDER BY R.Productivity DESC
GO

-- Average hours worked compared to GDP and Productivity

SELECT TOP 20 S.[Reference area], S.[Average hours worked per person employed], S.[Gross domestic product] AS [GDP,PPP], R.GDP_RANK, R.Productivity, R.Prod_RANK
FROM gdp_stats AS S
JOIN gdp_ranks AS R
	ON S.REF_AREA = R.REF_AREA
ORDER BY S.[Average hours worked per person employed] DESC
GO

-- Perception corruption index by country

SELECT [Reference area], [Corruption index]
FROM gdp_stats
ORDER BY [Corruption index] DESC
GO

-- Corruption index compared to productivity and worked hours

SELECT S.[Reference area], S.[Corruption index], S.[Average hours worked per person employed], R.Productivity
FROM gdp_stats AS S
JOIN gdp_ranks AS R
	ON S.REF_AREA = R.REF_AREA
ORDER BY [Corruption index]
GO

-- Corruption index compared to GDP per capita

SELECT [Reference area], [Corruption index], [GDP per capita]
FROM gdp_stats
ORDER BY [Corruption index]
GO