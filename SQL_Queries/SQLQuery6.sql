--Create the warehouse schema and dimension tables
USE FinanceAnalyticsDB;
GO

-- Create the warehouse schema if it does not exist.
IF SCHEMA_ID('dw') IS NULL
    EXEC('CREATE SCHEMA dw');
GO

-- 1. Customer dimension
IF OBJECT_ID('dw.DimCustomer', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimCustomer
    (
        CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
        CustomerName VARCHAR(200) NOT NULL UNIQUE
    );
END;
GO

-- 2. Product dimension
IF OBJECT_ID('dw.DimProduct', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimProduct
    (
        ProductKey INT IDENTITY(1,1) PRIMARY KEY,
        ProductName VARCHAR(200) NOT NULL UNIQUE
    );
END;
GO

-- 3. Department dimension
IF OBJECT_ID('dw.DimDepartment', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimDepartment
    (
        DepartmentKey INT IDENTITY(1,1) PRIMARY KEY,
        DepartmentName VARCHAR(100) NOT NULL UNIQUE
    );
END;
GO

-- 4. Region dimension
IF OBJECT_ID('dw.DimRegion', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimRegion
    (
        RegionKey INT IDENTITY(1,1) PRIMARY KEY,
        RegionName VARCHAR(100) NOT NULL UNIQUE
    );
END;
GO

-- 5. Currency dimension
IF OBJECT_ID('dw.DimCurrency', 'U') IS NULL
BEGIN
    CREATE TABLE dw.DimCurrency
    (
        CurrencyKey INT IDENTITY(1,1) PRIMARY KEY,
        CurrencyCode VARCHAR(10) NOT NULL UNIQUE
    );
END;
GO




-----------------------------------------------------------------------
--Valiate the data
USE FinanceAnalyticsDB;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = 'dw'
ORDER BY t.name;
GO