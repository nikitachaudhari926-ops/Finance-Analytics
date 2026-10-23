--finance KPI summary
USE FinanceAnalyticsDB;
GO

SELECT
    cur.CurrencyCode,

    COUNT(*) AS TotalTransactions,

    SUM(CASE
        WHEN f.revenue IS NOT NULL THEN 1
        ELSE 0
    END) AS TransactionsWithRevenue,

    SUM(f.revenue) AS TotalAvailableRevenue,

    SUM(CASE
        WHEN f.revenue IS NOT NULL
         AND f.cost_of_goods IS NOT NULL
         AND f.operating_expense IS NOT NULL
        THEN 1
        ELSE 0
    END) AS CompleteFinancialRows,

    SUM(CASE
        WHEN f.revenue IS NOT NULL
         AND f.cost_of_goods IS NOT NULL
         AND f.operating_expense IS NOT NULL
        THEN f.revenue - f.cost_of_goods - f.operating_expense
    END) AS OperatingProfit,

    CAST(
        100.0 * SUM(CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue - f.cost_of_goods - f.operating_expense
        END)
        / NULLIF(SUM(CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue
        END), 0)
        AS DECIMAL(6,2)
    ) AS OperatingMarginPercent,

    SUM(CAST(f.invalid_date_flag AS INT)) AS InvalidDateRows,
    SUM(CAST(f.invalid_revenue_flag AS INT)) AS InvalidRevenueRows,
    SUM(CAST(f.invalid_expense_flag AS INT)) AS InvalidExpenseRows,
    SUM(CAST(f.missing_customer_flag AS INT)) AS MissingCustomerRows,
    SUM(CAST(f.duplicate_transaction_flag AS INT)) AS DuplicateTransactionRows

FROM dw.FactTransactions AS f
INNER JOIN dw.DimCurrency AS cur
    ON f.CurrencyKey = cur.CurrencyKey
GROUP BY cur.CurrencyCode
ORDER BY cur.CurrencyCode;


---------------------------------------------------------------------------------------


SELECT
    d.CalendarYear,
    cur.CurrencyCode,
    COUNT(*) AS TotalTransactions,
    SUM(f.revenue) AS TotalAvailableRevenue
FROM dw.FactTransactions AS f
INNER JOIN dw.DimDate AS d
    ON f.DateKey = d.DateKey
INNER JOIN dw.DimCurrency AS cur
    ON f.CurrencyKey = cur.CurrencyKey
GROUP BY
    d.CalendarYear,
    cur.CurrencyCode
ORDER BY
    d.CalendarYear,
    cur.CurrencyCode;