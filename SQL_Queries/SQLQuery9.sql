SELECT SUM(revenue) AS TotalRevenue
FROM dw.FactTransactions;

-------------------------------------------------------------
-- Calculate the KPIs
USE FinanceAnalyticsDB;
GO

SELECT
    COUNT(*) AS TotalTransactions,

    COUNT(revenue) AS TransactionsWithRevenue,

    SUM(revenue) AS TotalRevenue,

    SUM(cost_of_goods) AS TotalCostOfGoods,

    SUM(operating_expense) AS TotalOperatingExpense,

    SUM(revenue - cost_of_goods) AS GrossProfit,

    SUM(revenue - cost_of_goods - operating_expense)
        AS OperatingProfit,

    CAST(
        100.0 * SUM(revenue - cost_of_goods - operating_expense)
        / NULLIF(SUM(revenue), 0)
        AS DECIMAL(10,2)
    ) AS OperatingMarginPercent

FROM dw.FactTransactions;


--------------------------------------------------------------------------------------
--Measure how many rows have complete financial data
USE FinanceAnalyticsDB;
GO

SELECT
    COUNT(*) AS TotalRows,

    SUM(
        CASE
            WHEN revenue IS NOT NULL
             AND cost_of_goods IS NOT NULL
             AND operating_expense IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS CompleteFinancialRows,

    SUM(
        CASE WHEN revenue IS NULL
             THEN 1 ELSE 0 END
    ) AS MissingRevenueRows,

    SUM(
        CASE WHEN cost_of_goods IS NULL
             THEN 1 ELSE 0 END
    ) AS MissingCostRows,

    SUM(
        CASE WHEN operating_expense IS NULL
             THEN 1 ELSE 0 END
    ) AS MissingExpenseRows,

    SUM(
        CASE
            WHEN revenue IS NULL
              OR cost_of_goods IS NULL
              OR operating_expense IS NULL
            THEN 1 ELSE 0
        END
    ) AS RowsWithAtLeastOneMissingAmount

FROM dw.FactTransactions;


-------------------------------------------------------------------------------
--Calculate reliable profit KPIs
USE FinanceAnalyticsDB;
GO

SELECT
    COUNT(*) AS TotalRows,

    SUM(
        CASE
            WHEN revenue IS NOT NULL
             AND cost_of_goods IS NOT NULL
             AND operating_expense IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS RowsIncludedInProfit,

    SUM(
        CASE
            WHEN revenue IS NOT NULL
             AND cost_of_goods IS NOT NULL
             AND operating_expense IS NOT NULL
            THEN revenue
        END
    ) AS RevenueForCompleteRows,

    SUM(
        CASE
            WHEN revenue IS NOT NULL
             AND cost_of_goods IS NOT NULL
             AND operating_expense IS NOT NULL
            THEN revenue - cost_of_goods
        END
    ) AS GrossProfitForCompleteRows,

    SUM(
        CASE
            WHEN revenue IS NOT NULL
             AND cost_of_goods IS NOT NULL
             AND operating_expense IS NOT NULL
            THEN revenue - cost_of_goods - operating_expense
        END
    ) AS OperatingProfitForCompleteRows,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN revenue IS NOT NULL
                 AND cost_of_goods IS NOT NULL
                 AND operating_expense IS NOT NULL
                THEN revenue - cost_of_goods - operating_expense
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN revenue IS NOT NULL
                     AND cost_of_goods IS NOT NULL
                     AND operating_expense IS NOT NULL
                    THEN revenue
                END
            ), 0
        )
        AS DECIMAL(10,2)
    ) AS OperatingMarginPercent

FROM dw.FactTransactions;


--------------------------------------------------------------------------------------
--Analyze financial KPIs by currency
USE FinanceAnalyticsDB;
GO

SELECT
    cur.CurrencyCode,

    COUNT(*) AS TotalTransactions,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS CompleteFinancialRows,

    SUM(f.revenue) AS TotalAvailableRevenue,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue
        END
    ) AS RevenueForCompleteRows,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue - f.cost_of_goods
        END
    ) AS GrossProfit,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue - f.cost_of_goods
                 - f.operating_expense
        END
    ) AS OperatingProfit,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN f.revenue IS NOT NULL
                 AND f.cost_of_goods IS NOT NULL
                 AND f.operating_expense IS NOT NULL
                THEN f.revenue - f.cost_of_goods
                     - f.operating_expense
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN f.revenue IS NOT NULL
                     AND f.cost_of_goods IS NOT NULL
                     AND f.operating_expense IS NOT NULL
                THEN f.revenue
                END
            ), 0
        )
        AS DECIMAL(10,2)
    ) AS OperatingMarginPercent

FROM dw.FactTransactions AS f

LEFT JOIN dw.DimCurrency AS cur
    ON f.CurrencyKey = cur.CurrencyKey

GROUP BY
    cur.CurrencyCode

ORDER BY
    cur.CurrencyCode;



-----------------------------------------------------------------------------------------
--Query 1 — Revenue and profit by department
USE FinanceAnalyticsDB;
GO

SELECT
    dep.DepartmentName,
    cur.CurrencyCode,

    COUNT(*) AS TotalTransactions,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS CompleteFinancialRows,

    SUM(f.revenue) AS TotalAvailableRevenue,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue - f.cost_of_goods
        END
    ) AS GrossProfit,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue - f.cost_of_goods
                 - f.operating_expense
        END
    ) AS OperatingProfit,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN f.revenue IS NOT NULL
                 AND f.cost_of_goods IS NOT NULL
                 AND f.operating_expense IS NOT NULL
                THEN f.revenue - f.cost_of_goods
                     - f.operating_expense
            END
        )
        /
        NULLIF(
            SUM(
                CASE
                    WHEN f.revenue IS NOT NULL
                     AND f.cost_of_goods IS NOT NULL
                     AND f.operating_expense IS NOT NULL
                THEN f.revenue
                END
            ), 0
        )
        AS DECIMAL(10,2)
    ) AS OperatingMarginPercent

FROM dw.FactTransactions AS f

INNER JOIN dw.DimDepartment AS dep
    ON f.DepartmentKey = dep.DepartmentKey

INNER JOIN dw.DimCurrency AS cur
    ON f.CurrencyKey = cur.CurrencyKey

GROUP BY
    dep.DepartmentName,
    cur.CurrencyCode

ORDER BY
    dep.DepartmentName,
    cur.CurrencyCode;


-------------------------------------------------------------------------------
--Query 2 — Rank departments by operating profit
USE FinanceAnalyticsDB;
GO

WITH DepartmentPerformance AS
(
    SELECT
        dep.DepartmentName,
        cur.CurrencyCode,

        SUM(
            CASE
                WHEN f.revenue IS NOT NULL
                 AND f.cost_of_goods IS NOT NULL
                 AND f.operating_expense IS NOT NULL
                THEN f.revenue - f.cost_of_goods
                     - f.operating_expense
            END
        ) AS OperatingProfit

    FROM dw.FactTransactions AS f

    INNER JOIN dw.DimDepartment AS dep
        ON f.DepartmentKey = dep.DepartmentKey

    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey

    GROUP BY
        dep.DepartmentName,
        cur.CurrencyCode
)
SELECT
    CurrencyCode,
    DepartmentName,
    OperatingProfit,

    RANK() OVER
    (
        PARTITION BY CurrencyCode
        ORDER BY OperatingProfit DESC
    ) AS ProfitRank

FROM DepartmentPerformance

ORDER BY
    CurrencyCode,
    ProfitRank;

-------------------------------------------------------------------------------------
--Query 3: Department revenue contribution
USE FinanceAnalyticsDB;
GO

WITH DepartmentRevenue AS
(
    SELECT
        dep.DepartmentName,
        cur.CurrencyCode,
        SUM(f.revenue) AS DepartmentRevenue
    FROM dw.FactTransactions AS f
    INNER JOIN dw.DimDepartment AS dep
        ON f.DepartmentKey = dep.DepartmentKey
    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey
    GROUP BY
        dep.DepartmentName,
        cur.CurrencyCode
)
SELECT
    CurrencyCode,
    DepartmentName,
    DepartmentRevenue,

    SUM(DepartmentRevenue) OVER
    (
        PARTITION BY CurrencyCode
    ) AS CurrencyTotalRevenue,

    CAST(
        100.0 * DepartmentRevenue
        / NULLIF(
            SUM(DepartmentRevenue) OVER
            (
                PARTITION BY CurrencyCode
            ),
            0
        )
        AS DECIMAL(6,2)
    ) AS RevenueContributionPercent

FROM DepartmentRevenue
ORDER BY
    CurrencyCode,
    RevenueContributionPercent DESC;


---------------------------------------------------------------------------------------
--Query 4 — Find the highest and lowest operating margins
USE FinanceAnalyticsDB;
GO

WITH DepartmentPerformance AS
(
    SELECT
        dep.DepartmentName,
        cur.CurrencyCode,

        SUM(
            CASE
                WHEN f.revenue IS NOT NULL
                 AND f.cost_of_goods IS NOT NULL
                 AND f.operating_expense IS NOT NULL
                THEN f.revenue
                   - f.cost_of_goods
                   - f.operating_expense
            END
        ) AS OperatingProfit,

        SUM(
            CASE
                WHEN f.revenue IS NOT NULL
                 AND f.cost_of_goods IS NOT NULL
                 AND f.operating_expense IS NOT NULL
                THEN f.revenue
            END
        ) AS RevenueForCompleteRows

    FROM dw.FactTransactions AS f
    INNER JOIN dw.DimDepartment AS dep
        ON f.DepartmentKey = dep.DepartmentKey
    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey

    GROUP BY
        dep.DepartmentName,
        cur.CurrencyCode
)
SELECT
    CurrencyCode,
    DepartmentName,
    OperatingProfit,
    RevenueForCompleteRows,

    CAST(
        100.0 * OperatingProfit
        / NULLIF(RevenueForCompleteRows, 0)
        AS DECIMAL(6,2)
    ) AS OperatingMarginPercent

FROM DepartmentPerformance
ORDER BY
    CurrencyCode,
    OperatingMarginPercent DESC;


-------------------------------------------------------------------------------
--Monthly revenue trends
USE FinanceAnalyticsDB;
GO

SELECT
    d.CalendarYear,
    d.MonthNumber,
    d.YearMonth,
    cur.CurrencyCode,

    COUNT(*) AS TotalTransactions,

    SUM(f.revenue) AS TotalAvailableRevenue,

    SUM(
        CASE
            WHEN f.revenue IS NOT NULL
             AND f.cost_of_goods IS NOT NULL
             AND f.operating_expense IS NOT NULL
            THEN f.revenue - f.cost_of_goods
                 - f.operating_expense
        END
    ) AS OperatingProfit

FROM dw.FactTransactions AS f

INNER JOIN dw.DimDate AS d
    ON f.DateKey = d.DateKey

INNER JOIN dw.DimCurrency AS cur
    ON f.CurrencyKey = cur.CurrencyKey

GROUP BY
    d.CalendarYear,
    d.MonthNumber,
    d.YearMonth,
    cur.CurrencyCode

ORDER BY
    d.CalendarYear,
    d.MonthNumber,
    cur.CurrencyCode;


-------------------------------------------------------------------------------
--Month-over-month revenue growth
--MoM Growth% = Previous Month RevenueCurrent Month Revenue−Previous Month Revenue​×100
USE FinanceAnalyticsDB;
GO

WITH MonthlyRevenue AS
(
    SELECT
        d.YearMonth,
        d.CalendarYear,
        d.MonthNumber,
        cur.CurrencyCode,
        SUM(f.revenue) AS TotalRevenue
    FROM dw.FactTransactions AS f
    INNER JOIN dw.DimDate AS d
        ON f.DateKey = d.DateKey
    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey
    GROUP BY
        d.YearMonth,
        d.CalendarYear,
        d.MonthNumber,
        cur.CurrencyCode
),
RevenueWithPreviousMonth AS
(
    SELECT
        YearMonth,
        CalendarYear,
        MonthNumber,
        CurrencyCode,
        TotalRevenue,

        LAG(TotalRevenue) OVER
        (
            PARTITION BY CurrencyCode
            ORDER BY CalendarYear, MonthNumber
        ) AS PreviousMonthRevenue

    FROM MonthlyRevenue
)
SELECT
    YearMonth,
    CurrencyCode,
    TotalRevenue,
    PreviousMonthRevenue,

    CAST(
        100.0 * (TotalRevenue - PreviousMonthRevenue)
        / NULLIF(PreviousMonthRevenue, 0)
        AS DECIMAL(8,2)
    ) AS MoMGrowthPercent

FROM RevenueWithPreviousMonth
ORDER BY
    CalendarYear,
    MonthNumber,
    CurrencyCode;


---------------------------------------------------------------------------------------
--Year-over-year (YoY) revenue growth
USE FinanceAnalyticsDB;
GO

WITH MonthlyRevenue AS
(
    SELECT
        d.YearMonth,
        d.CalendarYear,
        d.MonthNumber,
        cur.CurrencyCode,
        SUM(f.revenue) AS TotalRevenue
    FROM dw.FactTransactions AS f
    INNER JOIN dw.DimDate AS d
        ON f.DateKey = d.DateKey
    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey
    GROUP BY
        d.YearMonth,
        d.CalendarYear,
        d.MonthNumber,
        cur.CurrencyCode
),
RevenueWithPriorYear AS
(
    SELECT
        YearMonth,
        CalendarYear,
        MonthNumber,
        CurrencyCode,
        TotalRevenue,

        LAG(TotalRevenue, 12) OVER
        (
            PARTITION BY CurrencyCode
            ORDER BY CalendarYear, MonthNumber
        ) AS PreviousYearRevenue

    FROM MonthlyRevenue
)
SELECT
    YearMonth,
    CurrencyCode,
    TotalRevenue,
    PreviousYearRevenue,

    CAST(
        100.0 * (TotalRevenue - PreviousYearRevenue)
        / NULLIF(PreviousYearRevenue, 0)
        AS DECIMAL(8,2)
    ) AS YoYGrowthPercent

FROM RevenueWithPriorYear
ORDER BY
    CalendarYear,
    MonthNumber,
    CurrencyCode;


---------------------------------------------------------------------------
--Monthly trend analysis completed
USE FinanceAnalyticsDB;
GO

WITH MonthlyRevenue AS
(
    SELECT
        d.CalendarYear,
        d.MonthNumber,
        d.YearMonth,
        cur.CurrencyCode,
        SUM(f.revenue) AS MonthlyRevenue
    FROM dw.FactTransactions AS f
    INNER JOIN dw.DimDate AS d
        ON f.DateKey = d.DateKey
    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey
    GROUP BY
        d.CalendarYear,
        d.MonthNumber,
        d.YearMonth,
        cur.CurrencyCode
)
SELECT
    CalendarYear,
    YearMonth,
    CurrencyCode,
    MonthlyRevenue,

    SUM(MonthlyRevenue) OVER
    (
        PARTITION BY CalendarYear, CurrencyCode
        ORDER BY MonthNumber
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS YTDRevenue

FROM MonthlyRevenue
ORDER BY
    CalendarYear,
    MonthNumber,
    CurrencyCode;


------------------------------------------------------------------------
--One more validation query
USE FinanceAnalyticsDB;
GO

WITH MonthlyRevenue AS
(
    SELECT
        d.CalendarYear,
        d.MonthNumber,
        d.YearMonth,
        cur.CurrencyCode,
        SUM(f.revenue) AS MonthlyRevenue
    FROM dw.FactTransactions AS f
    INNER JOIN dw.DimDate AS d
        ON f.DateKey = d.DateKey
    INNER JOIN dw.DimCurrency AS cur
        ON f.CurrencyKey = cur.CurrencyKey
    GROUP BY
        d.CalendarYear,
        d.MonthNumber,
        d.YearMonth,
        cur.CurrencyCode
),
YTD AS
(
    SELECT
        CalendarYear,
        MonthNumber,
        YearMonth,
        CurrencyCode,
        MonthlyRevenue,
        SUM(MonthlyRevenue) OVER
        (
            PARTITION BY CalendarYear, CurrencyCode
            ORDER BY MonthNumber
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS YTDRevenue
    FROM MonthlyRevenue
)
SELECT *
FROM YTD
WHERE YearMonth IN ('2024-12', '2025-01')
ORDER BY CalendarYear, CurrencyCode;


