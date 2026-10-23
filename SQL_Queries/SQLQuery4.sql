USE FinanceAnalyticsDB;
GO

IF OBJECT_ID('staging.Transactions', 'U') IS NULL
BEGIN
    IF SCHEMA_ID('staging') IS NULL
        EXEC('CREATE SCHEMA staging');

    CREATE TABLE staging.Transactions
    (
        raw_row_id BIGINT NOT NULL,
        transaction_id VARCHAR(50) NULL,
        transaction_date DATE NULL,
        customer_name VARCHAR(200) NULL,
        product_name VARCHAR(200) NULL,
        department_name VARCHAR(100) NULL,
        region VARCHAR(100) NULL,
        currency_code VARCHAR(10) NULL,
        revenue DECIMAL(18,2) NULL,
        cost_of_goods DECIMAL(18,2) NULL,
        operating_expense DECIMAL(18,2) NULL,
        source_system VARCHAR(100) NULL,
        invalid_date_flag BIT NOT NULL,
        invalid_revenue_flag BIT NOT NULL,
        invalid_cost_flag BIT NOT NULL,
        invalid_expense_flag BIT NOT NULL,
        missing_customer_flag BIT NOT NULL,
        duplicate_transaction_flag BIT NOT NULL
    );
END;
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = 'staging'
  AND t.name = 'Transactions';
GO