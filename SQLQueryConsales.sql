USE Projects
GO

-- Check if the folowing tables exist and it they do, drop them before every run of the code

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'console_sales'
		   )
DROP TABLE console_sales
GO

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'costs'
		   )
DROP TABLE costs
GO

IF EXISTS (SELECT *
		   FROM sys.tables
		   WHERE name = 'sales_consolidate'
		   )
DROP TABLE sales_consolidate
GO

-- Create a new table to handle the console selling data

SELECT * FROM best_selling

SELECT [Console Name], Type, Company, [Released Year], [Discontinuation Year], [Units sold (million)] AS [Units sold]
INTO console_sales
FROM best_selling
GO

-- Transform data from the and add relevant data to console_sales table

ALTER TABLE console_sales
ALTER COLUMN [Released Year] SMALLINT

ALTER TABLE console_sales
ALTER COLUMN [Discontinuation Year] SMALLINT

ALTER TABLE console_sales
ALTER COLUMN [Units sold] FLOAT

UPDATE console_sales
SET [Units sold]=[Units sold]*1000000

UPDATE console_sales
SET [Console Name] = 'Xbox Series X'
	WHERE [Console Name] = 'Xbox Series X/S'

INSERT INTO console_sales ([Console Name], Type, Company, [Released Year], [Discontinuation Year], [Units sold]) VALUES 
('Xbox Series S', 'Home', 'Microsoft', 2020, '0',11500000)
GO

-- Handling Null Values

SELECT *
FROM console_sales
WHERE [Console Name] IS NULL OR Type IS NULL OR Company IS NULL OR
	  [Released Year] IS NULL OR [Discontinuation Year] IS NULL OR
	  [Units sold] IS NULL
GO

-- Check for duplicates

SELECT [Console Name], [Type], Company, [Released Year], [Discontinuation Year], [Units sold], COUNT(*)
FROM console_sales
GROUP BY [Console Name], [Type], Company, [Released Year], [Discontinuation Year], [Units sold]
HAVING COUNT(*) > 1
GO

-- There are no duplicates, but just as practice, here is a query to delete duplicates

WITH deduplication AS (
					   SELECT *, RANK() OVER (PARTITION BY [Console Name], [Type], Company, [Released Year], [Discontinuation Year], [Units sold] ORDER BY [Console Name]) as ranks
					   FROM console_sales
					   )
DELETE FROM deduplication
WHERE ranks > 1
GO

-- Create a column to calculate the years a console has been or was available to purchase

ALTER TABLE console_sales
ADD [Running years] SMALLINT
GO

UPDATE console_sales
SET [Running years] = CASE WHEN [Discontinuation Year] = 0 THEN YEAR(GETDATE())-[Released Year]
					  ELSE [Discontinuation Year] - [Released Year]
					  END
GO

-- Correct data

UPDATE console_sales
SET [Released Year] = 1972
WHERE [Console Name] = 'Magnavox Odyssey'
GO

-- Bring a table with console costs

SELECT *
INTO costs
FROM console_costs
GO

-- Create a table with all the sales information by joining console_sales and costs

SELECT S.*,C.[Original Price], C.[Adjusted Price (August 2024)] as [Adjusted Price]
INTO sales_consolidate
FROM console_sales AS S
JOIN costs AS C
	ON S.[Console Name] = C.Console
GO

-- Correct data types

ALTER TABLE sales_consolidate
ALTER COLUMN [Adjusted Price] MONEY

ALTER TABLE sales_consolidate
ALTER COLUMN [Original Price] MONEY

SELECT *
FROM sales_consolidate
GO
-- Create a column to estimate gross sales

ALTER TABLE sales_consolidate
ADD [Original gross sales] MONEY
ALTER TABLE sales_consolidate
ADD [Gross sales] MONEY
GO

UPDATE sales_consolidate
SET [Gross sales] = [Units sold] * [Adjusted Price],
	[Original gross sales] = [Units sold] * [Original Price]
GO

-- This is the second table we need to use in our visualizations

SELECT *
FROM sales_consolidate

DROP TABLE console_sales
DROP TABLE costs
GO

--Tables for analysis
-- Most years in "business" by Company


WITH years_calculation AS (SELECT Company, CASE WHEN MAX([Discontinuation Year]) < 2017 THEN MAX([Discontinuation Year])
																ELSE YEAR(GETDATE())
																END AS [Last running year]
						   FROM sales_consolidate
						   GROUP BY Company
						   )
SELECT S.Company, MIN(S.[Released Year]) AS [First console launch], Y.[Last running year], Y.[Last running year] - MIN(S.[Released Year]) AS [Running years]
FROM sales_consolidate AS S
JOIN years_calculation AS Y
	ON S.Company = Y.Company
GROUP BY S.Company, Y.[Last running year]
ORDER BY [Running years] DESC
GO

-- Most consoles sold in history until 2022

SELECT TOP 10 [Console Name], Type, Company, [Units sold]
FROM sales_consolidate
ORDER BY [Units sold] DESC
GO

-- Cost comparison at launch day vs ajusted to 2024 USD

SELECT Company, AVG([Original Price]) AS AVG_Launch_cost, ROUND(AVG([Adjusted Price]),2) AS AVG_Adjusted_Price
FROM sales_consolidate
GROUP BY Company
ORDER BY AVG([Adjusted Price]) DESC
GO

-- Revenue at original launch cost and adjusted to 2024 by company

SELECT Company, '$ '+LEFT(SUM([Original gross sales]/1000000000),6)+'B' AS Revenue_At_Launch_Cost, '$ '+LEFT(SUM([Gross sales])/1000000000,6)+'B' AS Adjusted_revenue
FROM sales_consolidate
GROUP BY Company
ORDER BY SUM([Gross sales]) DESC
GO