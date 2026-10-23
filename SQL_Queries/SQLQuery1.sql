SELECT DB_NAME() AS CurrentDatabase;

USE FinanceAnalyticsDB;
GO

--CREATE SCHEMA raw;
--GO

/*CREATE TABLE raw.Transactions
(
    raw_row_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_id NVARCHAR(50),
    transaction_date NVARCHAR(50),
    customer_name NVARCHAR(200),
    product_name NVARCHAR(200),
    department_name NVARCHAR(100),
    region NVARCHAR(100),
    currency_code NVARCHAR(10),
    revenue NVARCHAR(50),
    cost_of_goods NVARCHAR(50),
    operating_expense NVARCHAR(50),
    source_system NVARCHAR(100),
    loaded_at DATETIME2 DEFAULT SYSDATETIME()
);
GO*/



SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME = 'Transactions';


SELECT COUNT(*) AS Total_Rows
FROM raw.Transactions;

--Count the rows
USE FinanceAnalyticsDB;
GO
SELECT COUNT(*) AS Total_Rows
FROM raw.Transactions;

--Preview sample records
SELECT TOP (20) *
FROM raw.Transactions
ORDER BY raw_row_id;

--Find duplicate transaction IDs
SELECT
    transaction_id,
    COUNT(*) AS Occurrences
FROM raw.Transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY Occurrences DESC;

--Inspect invalid revenue values
SELECT
    raw_row_id,
    transaction_id,
    revenue
FROM raw.Transactions
WHERE TRY_CONVERT(DECIMAL(18, 2), revenue) IS NULL;

--Inspect invalid dates
SELECT
    raw_row_id,
    transaction_id,
    transaction_date
FROM raw.Transactions
WHERE TRY_CONVERT(DATE, transaction_date) IS NULL;


--Verify the total number of records
USE FinanceAnalyticsDB;
GO

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT transaction_id) AS Unique_Transaction_IDs,
    COUNT(DISTINCT customer_name) AS Distinct_Customer_Names
FROM raw.Transactions;

--Understand the distribution of your data
SELECT
    region,
    currency_code,
    COUNT(*) AS Transaction_Count
FROM raw.Transactions
GROUP BY
    region,
    currency_code
ORDER BY Transaction_Count DESC;


SELECT
    source_system,
    COUNT(*) AS Transaction_Count
FROM raw.Transactions
GROUP BY source_system
ORDER BY Transaction_Count DESC;


--Identify missing values
SELECT
    SUM(CASE WHEN customer_name IS NULL
             THEN 1 ELSE 0 END) AS Missing_Customers,

    SUM(CASE WHEN transaction_date IS NULL
             THEN 1 ELSE 0 END) AS Missing_Dates,

    SUM(CASE WHEN revenue IS NULL
             THEN 1 ELSE 0 END) AS Missing_Revenue,

    SUM(CASE WHEN operating_expense IS NULL
             THEN 1 ELSE 0 END) AS Missing_Expenses
FROM raw.Transactions;


--Check the raw table's structure
EXEC sp_help 'raw.Transactions';


--Check the total number of rows
USE FinanceAnalyticsDB;
GO

SELECT
    COUNT(*) AS Total_Rows,
    COUNT(DISTINCT transaction_id) AS Distinct_Transaction_IDs,
    COUNT(DISTINCT raw_row_id) AS Distinct_Raw_Row_IDs
FROM raw.Transactions;


--Check missing and blank values
SELECT
    COUNT(*) AS Total_Rows,

    SUM(CASE
        WHEN customer_name IS NULL THEN 1 ELSE 0
    END) AS Null_Customers,

    SUM(CASE
        WHEN customer_name = '' THEN 1 ELSE 0
    END) AS Empty_Customer_Names,

    SUM(CASE
        WHEN customer_name IS NOT NULL
         AND LTRIM(RTRIM(customer_name)) = ''
        THEN 1 ELSE 0
    END) AS Whitespace_Only_Customers,

    SUM(CASE
        WHEN revenue IS NULL THEN 1 ELSE 0
    END) AS Null_Revenue,

    SUM(CASE
        WHEN LTRIM(RTRIM(revenue)) = '' THEN 1 ELSE 0
    END) AS Blank_Revenue
FROM raw.Transactions;

--Check whether text values follow expected patterns
SELECT
    region,
    currency_code,
    COUNT(*) AS Row_Count
FROM raw.Transactions
GROUP BY region, currency_code
ORDER BY region, currency_code;


--Find dates that cannot be converted
SELECT
    raw_row_id,
    transaction_id,
    transaction_date
FROM raw.Transactions
WHERE TRY_CONVERT(DATE, transaction_date, 23) IS NULL;


--count the invalid dates 
SELECT
    COUNT(*) AS Invalid_Date_Rows
FROM raw.Transactions
WHERE TRY_CONVERT(DATE, transaction_date, 23) IS NULL;


--Find invalid numeric values
SELECT
    raw_row_id,
    transaction_id,
    revenue,
    cost_of_goods,
    operating_expense
FROM raw.Transactions
WHERE TRY_CONVERT(DECIMAL(18,2), revenue) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), cost_of_goods) IS NULL
   OR TRY_CONVERT(DECIMAL(18,2), operating_expense) IS NULL;


--Identify suspicious financial values
SELECT
    raw_row_id,
    transaction_id,
    revenue,
    cost_of_goods,
    operating_expense
FROM raw.Transactions
WHERE TRY_CONVERT(DECIMAL(18,2), revenue) < 0
   OR TRY_CONVERT(DECIMAL(18,2), cost_of_goods) < 0
   OR TRY_CONVERT(DECIMAL(18,2), operating_expense) < 0;


--Find duplicate transaction IDs
SELECT
    transaction_id,
    COUNT(*) AS Occurrences
FROM raw.Transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY Occurrences DESC;

SELECT *
FROM raw.Transactions
WHERE transaction_id = 'TXN0000996'
ORDER BY raw_row_id;


--calculate the basic statistics for revenue values that can be converted to numbers. 
--This gives you the minimum, maximum, and average revenue for convertible values. 
SELECT
    COUNT(*) AS Valid_Revenue_Count,
    MIN(TRY_CONVERT(DECIMAL(18,2), revenue)) AS Minimum_Revenue,
    MAX(TRY_CONVERT(DECIMAL(18,2), revenue)) AS Maximum_Revenue,
    AVG(TRY_CONVERT(DECIMAL(18,2), revenue)) AS Average_Revenue
FROM raw.Transactions
WHERE TRY_CONVERT(DECIMAL(18,2), revenue) IS NOT NULL;


--inspect the largest 20 values
SELECT TOP (20)
    raw_row_id,
    transaction_id,
    transaction_date,
    customer_name,
    currency_code,
    revenue
FROM raw.Transactions
WHERE TRY_CONVERT(DECIMAL(18,2), revenue) IS NOT NULL
ORDER BY TRY_CONVERT(DECIMAL(18,2), revenue) DESC;
