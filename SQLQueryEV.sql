USE Projects
GO

-- Delete working table if it exits on database

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'ev_data'
		   )
DROP TABLE ev_data
GO

-- Create table ev_data to protect the original table

SELECT *
INTO ev_data
FROM ev

SELECT *
FROM ev_data

-- Change and update data types

ALTER TABLE ev_data
ALTER COLUMN [value] FLOAT

ALTER TABLE ev_data
ADD years INT

UPDATE ev_data
SET [value] = ROUND([value],2),
	[years] = YEAR([year])

ALTER TABLE ev_data
DROP COLUMN [year]

SELECT *
FROM ev_data

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ev_data'

-- The focus of this study is only europe, so we drop other regions

DELETE FROM ev_data
WHERE region IN ('USA', 'Canada', 'Mexico', 'Costa Rica', 'Colombia', 'Brazil', 'Chile', 'South Africa',
				 'United Arab Emirates', 'Israel', 'India', 'China', 'Japan', 'Australia', 'New Zealand',
				 'EU27', 'Europe', 'Korea', 'World', 'Rest of the World', 'Seychelles', 'Thailand',
				 'Indonesia')

-- NUll values

SELECT *
FROM ev_data
WHERE value IS NULL

-- Insert values that are missing from the table, not null but missing, like data from 2023

INSERT INTO ev_data (region, category, parameter, mode, powertrain, unit, value, years) VALUES 
('Hungary', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 2500, 2023),
('Czech Republic', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 2317, 2023),
('Slovakia', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 2008, 2023),
('Ireland', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 2500, 2023),
('Slovenia', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 1500, 2023),
('Croatia', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 870, 2023),
('Romania', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 1350, 2023),
('Bulgaria', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 346, 2023),
('Lithuania', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 2200, 2023),
('Latvia', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 1000, 2023),
('Estonia', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 1975, 2023),
('Luxembourg', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 627, 2023),
('Cyprus', 'Historical', 'EV charging points', 'EV', 'Publicly available slow', 'charging points', 238, 2023)

-- Duplicated values

SELECT region, category, parameter, mode, powertrain, unit, value, years, COUNT(*) AS Count
FROM ev_data
GROUP BY region, category, parameter, mode, powertrain, unit, value, years
HAVING COUNT(*) >1
GO

WITH deduplication AS (SELECT *, 
					   RANK()OVER(PARTITION BY region, category, parameter, mode, powertrain, unit, value, years ORDER BY region) AS ranking
					   FROM ev_data
					   )
DELETE FROM deduplication
WHERE ranking > 1

-- Table for visuals

SELECT *
FROM ev_data


-- Total EV sold until 2023 in every european country

SELECT region, parameter AS Category, SUM(value) AS Total_EV
FROM ev_data
WHERE parameter = 'EV sales' AND
	  powertrain = 'BEV' AND
	  unit = 'Vehicles'
GROUP BY region, parameter
ORDER BY Total_EV DESC

-- Total EV sold until 2023 in eurpe by year

SELECT years, parameter AS Category, SUM(value) AS Total_EV
FROM ev_data
WHERE parameter = 'EV sales' AND
	  powertrain = 'BEV' AND
	  unit = 'Vehicles'
GROUP BY years, parameter
ORDER BY years

-- Distribution by type:

WITH percentage_sales AS (SELECT SUM(value) AS total
						  FROM ev_data
						  WHERE parameter = 'EV sales' AND
						  powertrain = 'BEV' AND
						  unit = 'Vehicles'
						  )
SELECT mode, SUM(value) as Total_EV, ROUND(SUM(value)*100.00/total,2) AS percentage
FROM ev_data, percentage_sales
WHERE parameter = 'EV sales' AND
	  powertrain = 'BEV' AND
	  unit = 'Vehicles'
GROUP BY mode, total
ORDER BY percentage
GO

-- Actual numbers based on percentages and market shares on 2023


SELECT mode, ROUND(AVG(value),2) AVG_market_share_by_type
FROM ev_data
WHERE unit = 'percent' AND
	  parameter = 'EV sales share' AND
	  years = 2023
GROUP BY mode

-- Total charging stations until 2023 in every european country

SELECT region, parameter AS Category, SUM(value) AS Charging_stations
FROM ev_data
WHERE parameter = 'EV charging points' AND
	  unit = 'charging points' AND
	  years = 2023
GROUP BY region, parameter
ORDER BY Charging_stations DESC

-- Increase of charging stations by year

SELECT years, parameter AS Category, CAST(SUM(value) AS int) AS Charging_Stations
FROM ev_data
WHERE parameter = 'EV charging points' AND
	  unit = 'charging points'
GROUP BY years, parameter
ORDER BY years

-- EV per charging station

WITH cars AS (SELECT region, parameter AS Category, SUM(value) AS ev
			  FROM ev_data
			  WHERE parameter = 'EV sales' AND
					powertrain = 'BEV' AND
					unit = 'Vehicles'
			  GROUP BY region, parameter
			  ),
	 stations AS (SELECT region, parameter AS Category, CAST(SUM(value) AS int) AS Charging_Stations
				  FROM ev_data
				  WHERE parameter = 'EV charging points' AND
				  unit = 'charging points' AND
				  years = 2023
				  GROUP BY region, parameter
				  )
SELECT c.region, C.ev AS Electric_vehicles, S.Charging_stations, ROUND(CAST(C.ev AS float)/S.Charging_Stations,2) AS [Ev per Charging station]
FROM cars AS C
JOIN stations AS S
	ON c.region = S.region
ORDER BY [Ev per Charging station]
