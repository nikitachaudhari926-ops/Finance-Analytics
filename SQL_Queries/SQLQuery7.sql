--Create dw.DimDate
USE FinanceAnalyticsDB;
GO

IF OBJECT_ID('dw.DimDate', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimDate
    (
        DateKey INT NOT NULL PRIMARY KEY,
        FullDate DATE NOT NULL UNIQUE,
        CalendarYear SMALLINT NOT NULL,
        QuarterNumber TINYINT NOT NULL,
        MonthNumber TINYINT NOT NULL,
        MonthName VARCHAR(20) NOT NULL,
        YearMonth CHAR(7) NOT NULL,
        DayOfMonth TINYINT NOT NULL
    );
END;


----------------------------------------------------------------------------
--generate every date from January 1, 2024, through December 31, 2026.
USE FinanceAnalyticsDB;
GO

;WITH CalendarDates AS
(
    SELECT CAST('2024-01-01' AS DATE) AS FullDate

    UNION ALL

    SELECT DATEADD(DAY, 1, FullDate)
    FROM CalendarDates
    WHERE FullDate < '2026-12-31'
)
INSERT INTO dw.DimDate
(
    DateKey,
    FullDate,
    CalendarYear,
    QuarterNumber,
    MonthNumber,
    MonthName,
    YearMonth,
    DayOfMonth
)
SELECT
    YEAR(FullDate) * 10000
        + MONTH(FullDate) * 100
        + DAY(FullDate),
    FullDate,
    YEAR(FullDate),
    DATEPART(QUARTER, FullDate),
    MONTH(FullDate),
    DATENAME(MONTH, FullDate),
    CONVERT(CHAR(7), FullDate, 126),
    DAY(FullDate)
FROM CalendarDates
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.DimDate AS d
    WHERE d.FullDate = CalendarDates.FullDate
)
OPTION (MAXRECURSION 0);
GO


------------------------------------------------------------------
--Validate the date dimension
SELECT
    COUNT(*) AS total_dates,
    MIN(FullDate) AS first_date,
    MAX(FullDate) AS last_date
FROM dw.DimDate;

--------------------------------------------------------

SELECT TOP (10)
    DateKey,
    FullDate,
    CalendarYear,
    QuarterNumber,
    MonthNumber,
    MonthName,
    YearMonth
FROM dw.DimDate
ORDER BY FullDate;


-----------------------------------------------------------------
--Load the five other dimensions
USE FinanceAnalyticsDB;
GO

-- Customers: exclude missing or blank names.
INSERT INTO dw.DimCustomer (CustomerName)
SELECT DISTINCT s.customer_name
FROM staging.Transactions AS s
WHERE NULLIF(LTRIM(RTRIM(s.customer_name)), '') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dw.DimCustomer AS d
      WHERE d.CustomerName = s.customer_name
  );

-- Products
INSERT INTO dw.DimProduct (ProductName)
SELECT DISTINCT s.product_name
FROM staging.Transactions AS s
WHERE NULLIF(LTRIM(RTRIM(s.product_name)), '') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dw.DimProduct AS d
      WHERE d.ProductName = s.product_name
  );

-- Departments
INSERT INTO dw.DimDepartment (DepartmentName)
SELECT DISTINCT s.department_name
FROM staging.Transactions AS s
WHERE NULLIF(LTRIM(RTRIM(s.department_name)), '') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dw.DimDepartment AS d
      WHERE d.DepartmentName = s.department_name
  );

-- Regions
INSERT INTO dw.DimRegion (RegionName)
SELECT DISTINCT s.region
FROM staging.Transactions AS s
WHERE NULLIF(LTRIM(RTRIM(s.region)), '') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dw.DimRegion AS d
      WHERE d.RegionName = s.region
  );

-- Currencies
INSERT INTO dw.DimCurrency (CurrencyCode)
SELECT DISTINCT s.currency_code
FROM staging.Transactions AS s
WHERE NULLIF(LTRIM(RTRIM(s.currency_code)), '') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dw.DimCurrency AS d
      WHERE d.CurrencyCode = s.currency_code
  );
GO


----------------------------------------------------------------------------------------------
--Validate all six dimensions
SELECT 'DimDate' AS dimension_name, COUNT_BIG(*) AS row_count
FROM dw.DimDate

UNION ALL

SELECT 'DimCustomer', COUNT_BIG(*)
FROM dw.DimCustomer

UNION ALL

SELECT 'DimProduct', COUNT_BIG(*)
FROM dw.DimProduct

UNION ALL

SELECT 'DimDepartment', COUNT_BIG(*)
FROM dw.DimDepartment

UNION ALL

SELECT 'DimRegion', COUNT_BIG(*)
FROM dw.DimRegion

UNION ALL

SELECT 'DimCurrency', COUNT_BIG(*)
FROM dw.DimCurrency;



-----------------------------------------------------------------------
--Investigate the customer count
USE FinanceAnalyticsDB;
GO

-- Distinct, nonblank customer names in staging
SELECT COUNT(DISTINCT customer_name) AS staging_distinct_customers
FROM staging.Transactions
WHERE NULLIF(LTRIM(RTRIM(customer_name)), '') IS NOT NULL;

-- Actual customer records in the dimension
SELECT
    CustomerKey,
    CustomerName
FROM dw.DimCustomer
ORDER BY CustomerName;