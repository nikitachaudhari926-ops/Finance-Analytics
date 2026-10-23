-- Preview the cleaned data
SELECT TOP (10) *
FROM staging.Transactions
ORDER BY raw_row_id;

-- Confirm the original raw data remains intact
SELECT COUNT(*) AS raw_row_count
FROM raw.Transactions;


-- 1. Check total rows
SELECT COUNT(*) AS staging_row_count
FROM staging.Transactions;


-- 2. Check data types assigned to staging columns
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'staging'
  AND TABLE_NAME = 'Transactions'
ORDER BY ORDINAL_POSITION;


-- 3. Check invalid date and financial-value flags
SELECT
    SUM(CASE WHEN invalid_date_flag = 1
             THEN 1 ELSE 0 END) AS invalid_dates,
    SUM(CASE WHEN invalid_revenue_flag = 1
             THEN 1 ELSE 0 END) AS invalid_revenue,
    SUM(CASE WHEN invalid_cost_flag = 1
             THEN 1 ELSE 0 END) AS invalid_cost,
    SUM(CASE WHEN invalid_expense_flag = 1
             THEN 1 ELSE 0 END) AS invalid_expenses,
    SUM(CASE WHEN missing_customer_flag = 1
             THEN 1 ELSE 0 END) AS missing_customers,
    SUM(CASE WHEN duplicate_transaction_flag = 1
             THEN 1 ELSE 0 END) AS duplicate_transaction_rows
FROM staging.Transactions;


-- 4. Inspect the records flagged for investigation
SELECT *
FROM staging.Transactions
WHERE invalid_date_flag = 1
   OR invalid_revenue_flag = 1
   OR invalid_expense_flag = 1
   OR missing_customer_flag = 1
   OR duplicate_transaction_flag = 1
ORDER BY raw_row_id;