USE Projects
GO

--First we delete the cleaned table, if exists, to facilitate the proccess everytime we run the code
IF EXISTS(
		  SELECT *
		  FROM sys.tables
		  WHERE name = 'ArrestDataClean'
		  )
DROP TABLE ArrestDataClean
GO
--Then we insert all the information into a new table to protect the source data and create a new dataset with cleaned data

SELECT *
INTO ArrestDataClean
FROM ArrestData
GO
--We verify the data types

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ArrestDataClean'
GO
-- We find out that there are some inconsistencies with the data. Since we are exporting in CSV files, we must address commas
-- whithin entries. We can use escape characters to keep the commas or we can replace them. The second option is chosen

UPDATE ArrestDataClean
SET PD_DESC = REPLACE(PD_DESC,',',' ')
UPDATE ArrestDataClean
SET PD_DESC = REPLACE(PD_DESC,'  ',' ')
UPDATE ArrestDataClean
SET OFNS_DESC = REPLACE(OFNS_DESC,',',' ')
GO
-- The boroughs are reffered with single letters which may cause confusion. For this reason the information is updated with the full name

UPDATE ArrestDataClean
SET ARREST_BORO = 'BRONX'
WHERE ARREST_BORO = 'B'
UPDATE ArrestDataClean
SET ARREST_BORO = 'MANHATTAN'
WHERE ARREST_BORO = 'M'
UPDATE ArrestDataClean
SET ARREST_BORO = 'BROOKLYN'
WHERE ARREST_BORO = 'K'
UPDATE ArrestDataClean
SET ARREST_BORO = 'QUEENS'
WHERE ARREST_BORO = 'Q'
UPDATE ArrestDataClean
SET ARREST_BORO = 'STATEN ISLAND'
WHERE ARREST_BORO = 'S'
GO
--Now we need to change the data types to the correct ones. We could change one by one or use a standard procedure that is
--already in SQL server to change several columns from a single data type to another (the date will be changed using a simple
--alter table)

DECLARE @tableName sysname = 'ArrestDataClean'
DECLARE @dataInt nvarchar(MAX) = ''
DECLARE @dataFloat nvarchar(MAX) = ''

ALTER TABLE ArrestDataClean
ALTER COLUMN ARREST_DATE DATE

SELECT @dataInt = @dataInt + 'ALTER TABLE ' + QUOTENAME(@tableName) + ' ALTER COLUMN ' + QUOTENAME(COLUMN_NAME) + ' INT '
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @tableName AND
	 DATA_TYPE = 'VARCHAR' AND
	 COLUMN_NAME IN ('ARREST_KEY', 'PD_CD', 'KY_CD', 'ARREST_PRECINCT', 'JURISDICTION CODE', 'X_COORD_CD', 'Y_COORD_CD')


SELECT @dataFloat = @dataFloat + 'ALTER TABLE ' + QUOTENAME(@tableName) + ' ALTER COLUMN ' + QUOTENAME(COLUMN_NAME) + ' FLOAT '
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = @tableName AND
	  DATA_TYPE = 'VARCHAR' AND
	  COLUMN_NAME IN ('Latitude', 'Longitude')

PRINT @dataInt
PRINT @dataFloat

EXECUTE SP_EXECUTESQL @dataInt
EXECUTE SP_EXECUTESQL @dataFloat
GO
--We check again the data types to confirm everything was done correctly

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ArrestDataClean'

--Now we found an entry that has no practical location (the very middle of the world). It will be deleted

DELETE FROM ArrestDataClean
WHERE Latitude = 0 AND Longitude = 0
GO

-- Check for duplicates

SELECT ARREST_KEY, ARREST_DATE, ARREST_BORO, PD_DESC, OFNS_DESC, ARREST_BORO, AGE_GROUP, PERP_RACE, PERP_SEX, Latitude, Longitude, COUNT(*)
FROM ArrestDataClean
GROUP BY ARREST_KEY, ARREST_DATE, ARREST_BORO, PD_DESC, OFNS_DESC, ARREST_BORO, AGE_GROUP, PERP_RACE, PERP_SEX, Latitude, Longitude
HAVING COUNT(*) > 1
GO
--Delete duplicates (We saw there are none, but just as practice)

WITH deduplication AS (SELECT *, RANK() OVER(PARTITION BY ARREST_KEY, ARREST_DATE, ARREST_BORO, PD_DESC, OFNS_DESC, ARREST_BORO, AGE_GROUP, PERP_RACE, PERP_SEX, Latitude, Longitude ORDER BY ARREST_KEY) AS ranking
					   FROM ArrestDataClean
					   )
DELETE FROM deduplication
WHERE ranking > 1

-- Check for null values

SELECT *
FROM ArrestDataClean
WHERE ARREST_KEY IS NULL OR ARREST_DATE IS NULL OR ARREST_BORO IS NULL OR PD_DESC IS NULL OR
	  OFNS_DESC IS NULL OR ARREST_BORO IS NULL OR AGE_GROUP IS NULL OR PERP_RACE IS NULL OR
	  PERP_SEX IS NULL OR Latitude IS NULL OR Longitude IS NULL
GO
--We check our cleaned table. This is the one we will export for visualizations

SELECT *
FROM ArrestDataClean
GO
--EDA
--Check how evolved the number of arrests throughout 2023 by date

SELECT DATENAME(MONTH,ARREST_DATE) AS MONTH, COUNT(ARREST_KEY) AS MONTHLY_ARRESTS
FROM ArrestDataClean
GROUP BY DATENAME(MONTH,ARREST_DATE)
ORDER BY MONTHLY_ARRESTS DESC

SELECT DATENAME(WEEK,ARREST_DATE) AS WEEK, COUNT(ARREST_KEY) AS WEEKLY_ARRESTS
FROM ArrestDataClean
GROUP BY DATENAME(WEEK,ARREST_DATE)
ORDER BY WEEKLY_ARRESTS DESC

SELECT DATENAME(WEEKDAY,ARREST_DATE) AS DAY, COUNT(ARREST_KEY) AS DAILY_ARRESTS
FROM ArrestDataClean
GROUP BY DATENAME(WEEKDAY,ARREST_DATE)
ORDER BY DAILY_ARRESTS DESC
GO
-- Let's see which type of crime is more common in NY

SELECT PD_DESC, COUNT(*) AS NUMBER_OF_CRIMES, LEFT(COUNT(*)*100.00/SUM(COUNT(*)) OVER(),6) + '%' AS PERCENTAGE
FROM ArrestDataClean
GROUP BY PD_DESC
ORDER BY NUMBER_OF_CRIMES DESC
GO
-- Let's check which areas have the most crime and which crimes are commited the most on these areas

SELECT ARREST_BORO, COUNT(ARREST_KEY) AS MOST_ARRESTS
FROM ArrestDataClean
GROUP BY ARREST_BORO
ORDER BY COUNT(ARREST_KEY) DESC

SELECT ARREST_BORO, ARREST_PRECINCT, COUNT(ARREST_KEY) AS MOST_ARRESTS
FROM ArrestDataClean
GROUP BY ARREST_BORO, ARREST_PRECINCT
ORDER BY COUNT(ARREST_KEY) DESC

SELECT PD_DESC, ARREST_BORO, COUNT(*)
FROM ArrestDataClean
GROUP BY PD_DESC, ARREST_BORO
ORDER BY COUNT(*) DESC
GO
--Let's check gender specific data

SELECT PERP_SEX, AGE_GROUP, COUNT(*) AS CRIMES, LEFT(COUNT(*)*100.00/SUM(COUNT(*))OVER(PARTITION BY PERP_SEX),5) + '%' AS SEX_PERCENTAGE, 
	   LEFT(COUNT(*)*100.00/SUM(COUNT(*)) OVER(),5) + '%' AS TOTAL_PERCENTAGE
FROM ArrestDataClean
GROUP BY PERP_SEX, AGE_GROUP
ORDER BY PERP_SEX, AGE_GROUP
GO
--Let's check race specific data

SELECT PERP_RACE, AGE_GROUP, COUNT(*) AS CRIMES, LEFT(COUNT(*)*100.00/SUM(COUNT(*))OVER(PARTITION BY PERP_RACE),5) + '%' AS RACE_PERCENTAGE, 
	   LEFT(COUNT(*)*100.00/SUM(COUNT(*)) OVER(),5) + '%' AS TOTAL_PERCENTAGE
FROM ArrestDataClean
GROUP BY PERP_RACE, AGE_GROUP
ORDER BY PERP_RACE, AGE_GROUP
GO
-- Tables to display in the analysis

-- Arrests by age group

SELECT AGE_GROUP, COUNT(ARREST_KEY) AS Crimes_Commited
FROM ArrestDataClean
GROUP BY AGE_GROUP
ORDER BY AGE_GROUP
GO
-- Top 5 crimes by the ages groups that get arrested more

SELECT TOP 5 AGE_GROUP, PD_DESC, COUNT(ARREST_KEY) AS Crimes_Commited
FROM ArrestDataClean
WHERE AGE_GROUP = '18-24'
GROUP BY AGE_GROUP, PD_DESC
ORDER BY Crimes_Commited DESC

SELECT TOP 5 AGE_GROUP, PD_DESC, COUNT(ARREST_KEY) AS Crimes_Commited
FROM ArrestDataClean
WHERE AGE_GROUP = '25-44'
GROUP BY AGE_GROUP, PD_DESC
ORDER BY Crimes_Commited DESC

SELECT TOP 5 AGE_GROUP, PD_DESC, COUNT(ARREST_KEY) AS Crimes_Commited
FROM ArrestDataClean
WHERE AGE_GROUP = '45-64'
GROUP BY AGE_GROUP, PD_DESC
ORDER BY Crimes_Commited DESC
GO

-- Causes of arrest

SELECT TOP 10 PD_DESC, COUNT(*) AS NUMBER_OF_CRIMES, LEFT(COUNT(*)*100.00/SUM(COUNT(*))OVER(),6)+'%' AS PERCENTAGE
FROM ArrestDataClean
GROUP BY PD_DESC
ORDER BY NUMBER_OF_CRIMES DESC
GO

-- Specifics by gender, age range

WITH TopByGender AS (SELECT TOP 100 PERCENT PERP_SEX, AGE_GROUP, PD_DESC, COUNT(ARREST_KEY) AS CRIMES_COMMITED, RANK() OVER(PARTITION BY PERP_SEX, AGE_GROUP ORDER BY COUNT(ARREST_KEY) DESC) AS ranking
					 FROM ArrestDataClean
					 GROUP BY PERP_SEX, AGE_GROUP, PD_DESC
					 ORDER BY CRIMES_COMMITED DESC
					 )
SELECT PERP_SEX, AGE_GROUP, PD_DESC, CRIMES_COMMITED
FROM TopByGender
WHERE ranking = 1
ORDER BY PERP_SEX
GO
-- Within each gender, which age range was arrested the most and what was the most common arrest cause

WITH TopCrimeGender AS (SELECT TOP 100 PERCENT PERP_SEX, AGE_GROUP, PD_DESC, COUNT(ARREST_KEY) AS CRIMES_COMMITED, RANK() OVER(PARTITION BY PERP_SEX ORDER BY COUNT(ARREST_KEY) DESC) AS ranking
						FROM ArrestDataClean
						GROUP BY PERP_SEX, AGE_GROUP, PD_DESC
						ORDER BY CRIMES_COMMITED DESC, PERP_SEX, AGE_GROUP 
						)
SELECT PERP_SEX, AGE_GROUP, PD_DESC, CRIMES_COMMITED
FROM TopCrimeGender
WHERE ranking = 1
ORDER BY PERP_SEX
GO

-- Arrests by race group

SELECT PERP_RACE, COUNT(*) AS CRIMES, LEFT(COUNT(*)*100.00/SUM(COUNT(*)) OVER(),5) + '%' AS TOTAL_PERCENTAGE
FROM ArrestDataClean
GROUP BY PERP_RACE
ORDER BY CRIMES DESC
GO

-- Most common cause of arrest by borough

WITH borough AS	(SELECT TOP 100 PERCENT ARREST_BORO, PD_DESC, COUNT(ARREST_KEY) AS MAX_ARRESTS, RANK()OVER(PARTITION BY ARREST_BORO ORDER BY COUNT(ARREST_KEY) DESC) AS ranking
				FROM ArrestDataClean
				GROUP BY ARREST_BORO, PD_DESC
				ORDER BY MAX_ARRESTS DESC)
SELECT ARREST_BORO, PD_DESC, MAX_ARRESTS
FROM borough
WHERE ranking = 1
ORDER BY MAX_ARRESTS DESC
GO

-- Arrests by borough

SELECT ARREST_BORO, COUNT(ARREST_KEY) AS MOST_ARRESTS, LEFT(COUNT(*)*100.00/SUM(COUNT(*)) OVER(),5) + '%' AS TOTAL_PERCENTAGE
FROM ArrestDataClean
GROUP BY ARREST_BORO
ORDER BY COUNT(ARREST_KEY) DESC
GO