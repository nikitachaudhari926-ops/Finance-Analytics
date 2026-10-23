
import pandas as pd
from sqlalchemy import create_engine, text
from urllib.parse import quote_plus

# 1. DATABASE CONFIGURATION
SERVER = r"localhost\SQLEXPRESS"
DATABASE = "FinanceAnalyticsDB"

connection_string = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

connection_url = (
    "mssql+pyodbc:///?odbc_connect="
    + quote_plus(connection_string)
)

# 2. CREATE THE DATABASE ENGINE
engine = create_engine(connection_url)

# 3. TEST THE CONNECTION
try:
    with engine.connect() as connection:
        database_name = connection.execute(
            text("SELECT DB_NAME()")
        ).scalar()

        print("Database connection successful.")
        print("Connected database:", database_name)

        # 4. CHECK THAT THE WAREHOUSE FACT TABLE IS ACCESSIBLE
        result = connection.execute(
            text("""
                SELECT
                    COUNT_BIG(*) AS TotalRows,
                    COUNT(DISTINCT raw_row_id) AS DistinctRawRows
                FROM dw.FactTransactions
            """)
        )

        row = result.fetchone()

        print("Fact table row count:", row[0])
        print("Distinct raw row IDs:", row[1])


        # 5. RETRIEVE FINANCE KPIs BY CURRENCY
        query = text("""
            SELECT
                cur.CurrencyCode,
                COUNT(*) AS TotalTransactions,
                SUM(f.revenue) AS TotalAvailableRevenue,

                SUM(
                    CASE
                        WHEN f.revenue IS NOT NULL
                         AND f.cost_of_goods IS NOT NULL
                         AND f.operating_expense IS NOT NULL
                        THEN 1
                        ELSE 0
                    END
                ) AS CompleteFinancialRows,

                SUM(
                    CASE
                        WHEN f.revenue IS NOT NULL
                         AND f.cost_of_goods IS NOT NULL
                         AND f.operating_expense IS NOT NULL
                        THEN f.revenue
                           - f.cost_of_goods
                           - f.operating_expense
                    END
                ) AS OperatingProfit

            FROM dw.FactTransactions AS f
            INNER JOIN dw.DimCurrency AS cur
                ON f.CurrencyKey = cur.CurrencyKey
            GROUP BY cur.CurrencyCode
            ORDER BY cur.CurrencyCode;
        """)

        df = pd.read_sql_query(query, connection)

        print("\n--- FINANCE KPIs BY CURRENCY ---")
        print(df.to_string(index=False))

        # 6. RETRIEVE MONTHLY FINANCIAL TRENDS
        monthly_query = text("""
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
                        THEN f.revenue
                           - f.cost_of_goods
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
        """)

        monthly_df = pd.read_sql_query(
            monthly_query, connection
        )

        print("\n--- MONTHLY FINANCIAL TRENDS ---")
        print("Rows retrieved:", len(monthly_df))
        print(monthly_df.head(9).to_string(index=False))

        # 7. RETRIEVE DEPARTMENT PERFORMANCE
        department_query = text("""
            SELECT
                dep.DepartmentName,
                cur.CurrencyCode,

                COUNT(*) AS TotalTransactions,

                SUM(
                    CASE
                        WHEN f.revenue IS NOT NULL
                         AND f.cost_of_goods IS NOT NULL
                         AND f.operating_expense IS NOT NULL
                        THEN 1
                        ELSE 0
                    END
                ) AS CompleteFinancialRows,

                SUM(f.revenue) AS TotalAvailableRevenue,

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

                CAST(
                    100.0 *
                    SUM(
                        CASE
                            WHEN f.revenue IS NOT NULL
                             AND f.cost_of_goods IS NOT NULL
                             AND f.operating_expense IS NOT NULL
                            THEN f.revenue
                               - f.cost_of_goods
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
                        ),
                        0
                    )
                    AS DECIMAL(6,2)
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
                cur.CurrencyCode,
                OperatingProfit DESC;
        """)

        department_df = pd.read_sql_query(
            department_query, connection
        )

        print("\n--- DEPARTMENT PERFORMANCE ---")
        print("Rows retrieved:", len(department_df))
        print(department_df.head(18).to_string(index=False))

except Exception as error:
    print("Database connection or query failed.")
    print(error)

finally:
    engine.dispose()