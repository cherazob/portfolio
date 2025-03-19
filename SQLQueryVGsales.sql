USE Projects
GO

-- Check if the table games_sales exists and it if does, drop it before every run of the code

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'games_sales'
		   )
DROP TABLE games_sales
GO

--Create table to handle the data

SELECT *
INTO games_sales
FROM vgsales
GO

--Change data types

ALTER TABLE games_sales
ALTER COLUMN NA_Sales FLOAT

ALTER TABLE games_sales
ALTER COLUMN EU_Sales FLOAT

ALTER TABLE games_sales
ALTER COLUMN JP_Sales FLOAT

ALTER TABLE games_sales
ALTER COLUMN Other_Sales FLOAT

ALTER TABLE games_sales
ALTER COLUMN Global_Sales FLOAT

ALTER TABLE games_sales
ALTER COLUMN Rank INT
GO

-- Check data types

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'games_sales'
GO

--Change the values to millions of units and correct decimal positions

UPDATE games_sales
SET NA_Sales = ROUND(NA_Sales*1000000,2),
	EU_Sales = ROUND(EU_Sales*1000000,2),
	JP_Sales = ROUND(JP_Sales*1000000,2),
	Other_Sales = ROUND(Other_Sales*1000000,2),
	Global_Sales = ROUND(Global_Sales*1000000,2)
GO

--Find null values

SELECT *
FROM games_sales
WHERE Name IS NULL OR Platform IS NULL OR Year IS NULL OR Genre IS NULL OR Publisher IS NULL OR
	  NA_Sales IS NULL OR EU_Sales IS NULL OR JP_Sales IS NULL OR Other_Sales IS NULL OR Global_Sales IS NULL
GO

--Find an delete duplicates

SELECT Name, Platform, Year, Publisher,NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales, COUNT(*)
FROM games_sales
GROUP BY Name, Platform, Year, Publisher,NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales
HAVING COUNT(*) >1
GO

WITH deduplication AS(
					  SELECT *, ROW_NUMBER() OVER (PARTITION BY Name, Platform, Year, Publisher,NA_Sales, EU_Sales, JP_Sales, Other_Sales, Global_Sales ORDER BY Name) AS rows
					  FROM games_sales
					  )
DELETE FROM deduplication
WHERE rows > 1
GO

-- Since there are games entries that share platform, year, genre and publisher, but for some reason have diferent sales data
-- these entries will be also deleted

SELECT Name, Platform, Year, Genre, Publisher, COUNT(*)
FROM games_sales
GROUP BY Name, Platform, Year, Genre, Publisher
HAVING COUNT(*) >1
GO

WITH deduplication AS(
					  SELECT *, ROW_NUMBER() OVER (PARTITION BY Name, Platform, Year, Publisher ORDER BY Name) AS rows
					  FROM games_sales
					  )
DELETE FROM deduplication
WHERE rows > 1
GO

--Remove games with no date and anything beyond 2017

DELETE FROM games_sales
WHERE Year = 'N/A' OR
	  Year = 2020

ALTER TABLE games_sales
ALTER COLUMN Year SMALLINT

SELECT * FROM games_sales
ORDER BY Global_Sales DESC

SELECT *
FROM games_sales
WHERE Year = 2017
GO

-- This will be our first table for visualizations

SELECT *
FROM games_sales
GO

-- Tables for analysis

-- Platform with the most games launched

SELECT TOP 10 Platform, COUNT(*) AS Games_Launched
FROM games_sales
GROUP BY Platform
ORDER BY Games_Launched DESC
GO

-- Publisher with the most games launched

SELECT TOP 10 Publisher, COUNT(*) AS Games_Launched
FROM games_sales
GROUP BY Publisher
ORDER BY Games_Launched DESC
GO

-- Top 10 games with the most sales ever

SELECT TOP 10 Name, Platform, '$ '+LEFT(SUM(Global_Sales)/1000000,5)+'M' AS Global_Sales
FROM games_sales
GROUP BY Name, Platform
ORDER BY SUM(Global_Sales) DESC
GO

-- Genres with the most sold games in history

SELECT TOP 10 Genre, '$ '+LEFT(SUM(Global_sales)/1000000,6)+'M' AS Global_sales
FROM games_sales
GROUP BY Genre
ORDER BY SUM(Global_sales) DESC
GO

-- Sales by world region

SELECT LEFT(SUM(NA_Sales/1000000000),4)+'B' AS NA_SALES, LEFT(SUM(EU_Sales/1000000000),4)+'B' AS EU_SALES, LEFT(SUM(JP_Sales/1000000000),4)+'B' AS JP_SALES,
	   LEFT(SUM(Other_Sales/1000000000),4)+'B' AS OTHER_SALES
FROM games_sales
GO

-- Genre specific sales by world region

SELECT Genre, LEFT(SUM(NA_Sales/1000000),5)+'M' AS NA_SALES, LEFT(SUM(EU_Sales/1000000),5)+'M' AS EU_SALES, LEFT(SUM(JP_Sales/1000000),5)+'M' AS JP_SALES,
	   LEFT(SUM(Other_Sales/1000000),5)+'M' AS OTHER_SALES
FROM games_sales
GROUP BY Genre
ORDER BY SUM(NA_Sales) DESC
GO