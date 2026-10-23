USE FinanceAnalyticsDB;
GO

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'staging'
  AND TABLE_NAME = 'Transactions'
ORDER BY ORDINAL_POSITION;






USE FinanceAnalyticsDB;
GO

DROP TABLE IF EXISTS staging.Transactions;
GO

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
GO

SELECT
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'staging'
  AND TABLE_NAME = 'Transactions'
ORDER BY ORDINAL_POSITION;
GO




USE FinanceAnalyticsDB;
GO

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'staging'
  AND TABLE_NAME = 'Transactions'
ORDER BY ORDINAL_POSITION;