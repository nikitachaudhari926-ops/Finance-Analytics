--First, verify all dimension tables
USE FinanceAnalyticsDB;
GO

SELECT 'DimDate' AS DimensionName, COUNT(*) AS TotalRows
FROM dw.DimDate

UNION ALL

SELECT 'DimCustomer', COUNT(*)
FROM dw.DimCustomer

UNION ALL

SELECT 'DimProduct', COUNT(*)
FROM dw.DimProduct

UNION ALL

SELECT 'DimDepartment', COUNT(*)
FROM dw.DimDepartment

UNION ALL

SELECT 'DimRegion', COUNT(*)
FROM dw.DimRegion

UNION ALL

SELECT 'DimCurrency', COUNT(*)
FROM dw.DimCurrency;


-----------------------------------------------------------------------------
--Check the staging columns
USE FinanceAnalyticsDB;
GO

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'staging'
  AND TABLE_NAME = 'Transactions'
ORDER BY ORDINAL_POSITION;


--------------------------------------------------------------------------------
--Create the fact table
USE FinanceAnalyticsDB;
GO

CREATE TABLE dw.FactTransactions
(
    raw_row_id BIGINT NOT NULL PRIMARY KEY,

    transaction_id VARCHAR(50) NULL,

    DateKey INT NULL,
    CustomerKey INT NULL,
    ProductKey INT NULL,
    DepartmentKey INT NULL,
    RegionKey INT NULL,
    CurrencyKey INT NULL,

    revenue DECIMAL(18,2) NULL,
    cost_of_goods DECIMAL(18,2) NULL,
    operating_expense DECIMAL(18,2) NULL,

    invalid_date_flag BIT NOT NULL,
    invalid_revenue_flag BIT NOT NULL,
    invalid_cost_flag BIT NOT NULL,
    invalid_expense_flag BIT NOT NULL,
    missing_customer_flag BIT NOT NULL,
    duplicate_transaction_flag BIT NOT NULL,

    CONSTRAINT FK_FactTransactions_DimDate
        FOREIGN KEY (DateKey)
        REFERENCES dw.DimDate(DateKey),

    CONSTRAINT FK_FactTransactions_DimCustomer
        FOREIGN KEY (CustomerKey)
        REFERENCES dw.DimCustomer(CustomerKey),

    CONSTRAINT FK_FactTransactions_DimProduct
        FOREIGN KEY (ProductKey)
        REFERENCES dw.DimProduct(ProductKey),

    CONSTRAINT FK_FactTransactions_DimDepartment
        FOREIGN KEY (DepartmentKey)
        REFERENCES dw.DimDepartment(DepartmentKey),

    CONSTRAINT FK_FactTransactions_DimRegion
        FOREIGN KEY (RegionKey)
        REFERENCES dw.DimRegion(RegionKey),

    CONSTRAINT FK_FactTransactions_DimCurrency
        FOREIGN KEY (CurrencyKey)
        REFERENCES dw.DimCurrency(CurrencyKey)
);
GO


----------------------------------------------------------------------------
--Validate that the table exists
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dw'
  AND TABLE_NAME = 'FactTransactions';


----------------------------------------------------------------------------
--Load the fact table
USE FinanceAnalyticsDB;
GO

INSERT INTO dw.FactTransactions
(
    raw_row_id,
    transaction_id,
    DateKey,
    CustomerKey,
    ProductKey,
    DepartmentKey,
    RegionKey,
    CurrencyKey,
    revenue,
    cost_of_goods,
    operating_expense,
    invalid_date_flag,
    invalid_revenue_flag,
    invalid_cost_flag,
    invalid_expense_flag,
    missing_customer_flag,
    duplicate_transaction_flag
)
SELECT
    s.raw_row_id,
    s.transaction_id,
    d.DateKey,
    c.CustomerKey,
    p.ProductKey,
    dep.DepartmentKey,
    r.RegionKey,
    cur.CurrencyKey,
    s.revenue,
    s.cost_of_goods,
    s.operating_expense,
    s.invalid_date_flag,
    s.invalid_revenue_flag,
    s.invalid_cost_flag,
    s.invalid_expense_flag,
    s.missing_customer_flag,
    s.duplicate_transaction_flag
FROM staging.Transactions AS s
LEFT JOIN dw.DimDate AS d
    ON d.FullDate = s.transaction_date
LEFT JOIN dw.DimCustomer AS c
    ON c.CustomerName = s.customer_name
LEFT JOIN dw.DimProduct AS p
    ON p.ProductName = s.product_name
LEFT JOIN dw.DimDepartment AS dep
    ON dep.DepartmentName = s.department_name
LEFT JOIN dw.DimRegion AS r
    ON r.RegionName = s.region
LEFT JOIN dw.DimCurrency AS cur
    ON cur.CurrencyCode = s.currency_code;
GO


--------------------------------------------------------------------------------
--Check data-quality flags
SELECT
    SUM(CAST(invalid_date_flag AS INT)) AS InvalidDates,
    SUM(CAST(invalid_revenue_flag AS INT)) AS InvalidRevenue,
    SUM(CAST(invalid_cost_flag AS INT)) AS InvalidCosts,
    SUM(CAST(invalid_expense_flag AS INT)) AS InvalidExpenses,
    SUM(CAST(missing_customer_flag AS INT)) AS MissingCustomers,
    SUM(CAST(duplicate_transaction_flag AS INT)) AS DuplicateRows
FROM dw.FactTransactions;


----------------------------------------------------------------------------------
--Validate dimension-key mappings
USE FinanceAnalyticsDB;
GO

SELECT
    COUNT(*) AS TotalFactRows,

    SUM(CASE WHEN DateKey IS NULL
             THEN 1 ELSE 0 END) AS MissingDateKeys,

    SUM(CASE WHEN CustomerKey IS NULL
             THEN 1 ELSE 0 END) AS MissingCustomerKeys,

    SUM(CASE WHEN ProductKey IS NULL
             THEN 1 ELSE 0 END) AS MissingProductKeys,

    SUM(CASE WHEN DepartmentKey IS NULL
             THEN 1 ELSE 0 END) AS MissingDepartmentKeys,

    SUM(CASE WHEN RegionKey IS NULL
             THEN 1 ELSE 0 END) AS MissingRegionKeys,

    SUM(CASE WHEN CurrencyKey IS NULL
             THEN 1 ELSE 0 END) AS MissingCurrencyKeys

FROM dw.FactTransactions;


--------------------------------------------------------------------------------
--Final warehouse validation
USE FinanceAnalyticsDB;
GO

SELECT
    'Staging' AS DataLayer,
    COUNT(*) AS TotalRows,
    SUM(revenue) AS TotalRevenue,
    SUM(cost_of_goods) AS TotalCostOfGoods,
    SUM(operating_expense) AS TotalOperatingExpense
FROM staging.Transactions

UNION ALL

SELECT
    'FactTable',
    COUNT(*),
    SUM(revenue),
    SUM(cost_of_goods),
    SUM(operating_expense)
FROM dw.FactTransactions;