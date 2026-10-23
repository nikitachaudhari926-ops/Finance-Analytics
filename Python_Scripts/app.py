import plotly.express as px
import pandas as pd
import streamlit as st
from sqlalchemy import create_engine, text
from urllib.parse import quote_plus

def format_compact(value):
    if pd.isna(value):
        return "N/A"

    value = float(value)
    abs_value = abs(value)

    if abs_value >= 1_000_000_000:
        return f"{value / 1_000_000_000:.2f}B"
    elif abs_value >= 1_000_000:
        return f"{value / 1_000_000:.2f}M"
    elif abs_value >= 1_000:
        return f"{value / 1_000:.1f}K"
    else:
        return f"{value:,.2f}"

# --------------------------------------------------
# 1. PAGE CONFIGURATION
# --------------------------------------------------

st.set_page_config(
    page_title="Finance Analytics Dashboard",
    page_icon="📊",
    layout="wide"
)

st.title("Finance Analytics Dashboard")
st.caption(
    "Data source: SQL Server | FinanceAnalyticsDB | "
    "Synthetic finance transactions"
)


# --------------------------------------------------
# 2. DATABASE CONNECTION
# --------------------------------------------------

@st.cache_resource
def get_engine():
    server = r"localhost\SQLEXPRESS"
    database = "FinanceAnalyticsDB"

    connection_string = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={server};"
        f"DATABASE={database};"
        "Trusted_Connection=yes;"
        "Encrypt=yes;"
        "TrustServerCertificate=yes;"
    )

    connection_url = (
        "mssql+pyodbc:///?odbc_connect="
        + quote_plus(connection_string)
    )

    return create_engine(connection_url)


engine = get_engine()


# --------------------------------------------------
# 3. LOAD REPORTING DATA FROM SQL SERVER
# --------------------------------------------------

@st.cache_data(ttl=300)
def load_data():
    with engine.connect() as connection:

        # Overall KPIs, calculated separately by currency
       
        kpi_query = text("""
            SELECT
                d.CalendarYear,
                cur.CurrencyCode,
                COUNT(*) AS TotalTransactions,
                SUM(f.revenue) AS TotalAvailableRevenue,

                SUM(
                    CASE
                        WHEN f.revenue IS NOT NULL
                         AND f.cost_of_goods IS NOT NULL
                         AND f.operating_expense IS NOT NULL
                        THEN 1 ELSE 0
                    END
                ) AS CompleteFinancialRows,

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
                    100.0 * SUM(
                        CASE
                            WHEN f.revenue IS NOT NULL
                             AND f.cost_of_goods IS NOT NULL
                             AND f.operating_expense IS NOT NULL
                            THEN f.revenue - f.cost_of_goods
                                 - f.operating_expense
                        END
                    )
                    / NULLIF(
                        SUM(
                            CASE
                                WHEN f.revenue IS NOT NULL
                                 AND f.cost_of_goods IS NOT NULL
                                 AND f.operating_expense IS NOT NULL
                                THEN f.revenue
                            END
                        ), 0
                    )
                    AS DECIMAL(6,2)
                ) AS OperatingMarginPercent

            FROM dw.FactTransactions AS f
            INNER JOIN dw.DimDate AS d
                ON f.DateKey = d.DateKey
            INNER JOIN dw.DimCurrency AS cur
                ON f.CurrencyKey = cur.CurrencyKey

            GROUP BY d.CalendarYear, cur.CurrencyCode
            ORDER BY d.CalendarYear, cur.CurrencyCode;
        """)

        kpi_df = pd.read_sql_query(kpi_query, connection)

        # Monthly trends
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
        """)

        monthly_df = pd.read_sql_query(
            monthly_query, connection
        )

        # Department performance
        
        department_query = text("""
            SELECT
                d.CalendarYear,
                dep.DepartmentName,
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
                ) AS OperatingProfit,

                CAST(
                    100.0 * SUM(
                        CASE
                            WHEN f.revenue IS NOT NULL
                             AND f.cost_of_goods IS NOT NULL
                             AND f.operating_expense IS NOT NULL
                            THEN f.revenue - f.cost_of_goods
                                 - f.operating_expense
                        END
                    )
                    / NULLIF(
                        SUM(
                            CASE
                                WHEN f.revenue IS NOT NULL
                                 AND f.cost_of_goods IS NOT NULL
                                 AND f.operating_expense IS NOT NULL
                                THEN f.revenue
                            END
                        ), 0
                    )
                    AS DECIMAL(6,2)
                ) AS OperatingMarginPercent

            FROM dw.FactTransactions AS f
            INNER JOIN dw.DimDate AS d
                ON f.DateKey = d.DateKey
            INNER JOIN dw.DimDepartment AS dep
                ON f.DepartmentKey = dep.DepartmentKey
            INNER JOIN dw.DimCurrency AS cur
                ON f.CurrencyKey = cur.CurrencyKey

            GROUP BY
                d.CalendarYear,
                dep.DepartmentName,
                cur.CurrencyCode

            ORDER BY
                d.CalendarYear,
                cur.CurrencyCode,
                dep.DepartmentName;
        """)

        department_df = pd.read_sql_query(
            department_query, connection
        )


        # Data quality by year and currency
        quality_query = text("""
            SELECT
                d.CalendarYear,
                cur.CurrencyCode,

                COUNT(*) AS TotalRows,

                SUM(CAST(f.invalid_revenue_flag AS INT))
                    AS InvalidRevenueRows,

                SUM(CAST(f.invalid_cost_flag AS INT))
                    AS InvalidCostRows,

                SUM(CAST(f.invalid_expense_flag AS INT))
                    AS InvalidExpenseRows,

                SUM(CAST(f.missing_customer_flag AS INT))
                    AS MissingCustomerRows,

                SUM(CAST(f.duplicate_transaction_flag AS INT))
                    AS DuplicateFlaggedRows

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
        """)

        quality_df = pd.read_sql_query(
            quality_query, connection
        )

        # Invalid dates cannot be assigned to a calendar year.
        # Report them separately by currency across all years.
        invalid_date_query = text("""
            SELECT
                cur.CurrencyCode,
                COUNT_BIG(*) AS InvalidDateRows
            FROM dw.FactTransactions AS f
            INNER JOIN dw.DimCurrency AS cur
                ON f.CurrencyKey = cur.CurrencyKey
            WHERE f.invalid_date_flag = 1
            GROUP BY cur.CurrencyCode
            ORDER BY cur.CurrencyCode;
        """)

        invalid_date_df = pd.read_sql_query(
            invalid_date_query, connection
        )
 # Return AFTER the connection block, but inside load_data()
    return (
        kpi_df,
        monthly_df,
        department_df,
        quality_df,
        invalid_date_df
    )

# --------------------------------------------------
# 4. LOAD DATA AND HANDLE ERRORS
# --------------------------------------------------

try:
    (
        kpi_df,
        monthly_df,
        department_df,
        quality_df,
        invalid_date_df
    ) = load_data()

except Exception as error:
    st.error("Unable to load data from SQL Server.")
    st.exception(error)
    st.stop()



# --------------------------------------------------
# 5. FILTERS
# --------------------------------------------------

st.sidebar.header("Dashboard Filters")

currency_options = sorted(kpi_df["CurrencyCode"].unique())

selected_currency = st.sidebar.selectbox(
    "Select currency",
    currency_options
)

currency_monthly = monthly_df[
    monthly_df["CurrencyCode"] == selected_currency
].copy()

year_options = sorted(
    currency_monthly["CalendarYear"].unique(),
    reverse=True
)

selected_year = st.sidebar.selectbox(
    "Select year",
    year_options
)

# Apply BOTH filters to every relevant dataset.
currency_kpi = kpi_df[
    (kpi_df["CurrencyCode"] == selected_currency)
    & (kpi_df["CalendarYear"] == selected_year)
]

year_monthly = currency_monthly[
    currency_monthly["CalendarYear"] == selected_year
].copy()

year_monthly = year_monthly.sort_values("MonthNumber")

currency_department = department_df[
    (department_df["CurrencyCode"] == selected_currency)
    & (department_df["CalendarYear"] == selected_year)
].copy()

# --------------------------------------------------
# 6. KPI CARDS
# --------------------------------------------------

kpi = currency_kpi.iloc[0]

st.subheader(f"Financial Overview — {selected_currency}")

col1, col2, col3, col4 = st.columns(4)

col1.metric(
    "Total Transactions",
    f"{int(kpi['TotalTransactions']):,}"
)

col2.metric(
    "Available Revenue",
    format_compact(kpi["TotalAvailableRevenue"])
)

col3.metric(
    "Operating Profit",
    format_compact(kpi["OperatingProfit"])
)

col4.metric(
    "Operating Margin",
    f"{kpi['OperatingMarginPercent']:.2f}%"
)

st.caption(
    "Financial overview covers all dates in the warehouse. "
    "Revenue and profit use different row populations when "
    "financial values are missing. Profit and margin use "
    "complete financial rows only."
)

st.divider()


# --------------------------------------------------
# 7. MONTHLY REVENUE TREND
# --------------------------------------------------

st.subheader(f"Monthly Revenue Trend — {selected_year}")

revenue_chart = year_monthly[
    ["YearMonth", "TotalAvailableRevenue"]
].copy()

fig = px.line(
    revenue_chart,
    x="YearMonth",
    y="TotalAvailableRevenue",
    markers=True,
    title=f"Monthly Revenue ({selected_currency})"
)

fig.update_yaxes(
    tickformat="~s",
    title="Revenue"
)

fig.update_xaxes(
    title="Month",
    type="category"
)

fig.update_layout(
    margin=dict(l=20, r=20, t=60, b=20),
    height=400
)

st.plotly_chart(fig, use_container_width=True)

st.caption(
    f"Monthly available revenue in {selected_currency}. "
    "Months with invalid dates are excluded."
)


# --------------------------------------------------
# 8. DEPARTMENT PERFORMANCE
# --------------------------------------------------

st.subheader(f"Department Performance — {selected_currency}")

department_chart = currency_department[
    ["DepartmentName", "OperatingProfit"]
].sort_values("OperatingProfit", ascending=False)

fig = px.bar(
    department_chart,
    x="DepartmentName",
    y="OperatingProfit",
    title="Operating Profit by Department",
    text_auto=False
)

fig.update_yaxes(
    tickformat="~s",
    title="Operating Profit"
)

fig.update_xaxes(
    title="Department"
)

fig.update_layout(
    margin=dict(l=20, r=20, t=60, b=20),
    height=400
)

st.plotly_chart(fig, use_container_width=True)

st.caption(
    "Operating profit is calculated from complete financial "
    "rows. Compare departments only within the selected currency."
)

st.subheader("Department Details")

display_df = currency_department[
    [
        "DepartmentName",
        "TotalTransactions",
        "TotalAvailableRevenue",
        "OperatingProfit",
        "OperatingMarginPercent"
    ]
].sort_values("OperatingProfit", ascending=False).copy()

display_df["TotalAvailableRevenue"] = (
    display_df["TotalAvailableRevenue"].map(
        lambda value: f"{value:,.2f}"
    )
)

display_df["OperatingProfit"] = (
    display_df["OperatingProfit"].map(
        lambda value: f"{value:,.2f}"
    )
)

display_df["OperatingMarginPercent"] = (
    display_df["OperatingMarginPercent"].map(
        lambda value: f"{value:.2f}%"
    )
)

st.dataframe(display_df, use_container_width=True, hide_index=True)


# --------------------------------------------------
# 9. DATA VALIDATION
# --------------------------------------------------

with st.expander("Data validation details"):
    st.write("Database: FinanceAnalyticsDB")
    st.write("Fact table rows: 100,000")
    st.write("Monthly trend rows:", len(monthly_df))
    st.write("Department-currency rows:", len(department_df))
    st.write("Data refresh cache: up to 5 minutes")


# --------------------------------------------------
# 10. DATA QUALITY MONITORING
# --------------------------------------------------

st.divider()
st.header("Data Quality Monitoring")

st.caption(
    f"Quality checks for {selected_currency}, "
    f"{selected_year}. Invalid-date counts are reported "
    "across all years because those records cannot be "
    "assigned to a reliable year."
)

selected_quality = quality_df[
    (quality_df["CurrencyCode"] == selected_currency)
    & (quality_df["CalendarYear"] == selected_year)
]

if not selected_quality.empty:
    quality = selected_quality.iloc[0]

    q1, q2, q3 = st.columns(3)

    q1.metric(
        "Invalid Revenue Rows",
        f"{int(quality['InvalidRevenueRows']):,}"
    )

    q2.metric(
        "Invalid Cost Rows",
        f"{int(quality['InvalidCostRows']):,}"
    )

    q3.metric(
        "Invalid Expense Rows",
        f"{int(quality['InvalidExpenseRows']):,}"
    )

    q4, q5 = st.columns(2)

    q4.metric(
        "Missing Customer Rows",
        f"{int(quality['MissingCustomerRows']):,}"
    )

    q5.metric(
        "Duplicate-Flagged Rows",
        f"{int(quality['DuplicateFlaggedRows']):,}"
    )

    st.caption(
        f"Date-valid transactions in this period: "
        f"{int(quality['TotalRows']):,}"
    )

# Invalid dates across all years for the selected currency
selected_invalid_dates = invalid_date_df[
    invalid_date_df["CurrencyCode"] == selected_currency
]

if not selected_invalid_dates.empty:
    invalid_dates = int(
        selected_invalid_dates.iloc[0]["InvalidDateRows"]
    )

    st.metric(
        "Invalid-Date Rows — All Years",
        f"{invalid_dates:,}"
    )

st.info(
    "A duplicate-flagged row is a row whose transaction ID "
    "was flagged as duplicated; this is not necessarily the "
    "same as the number of distinct duplicate IDs. Quality "
    "counts may overlap because one transaction can have "
    "multiple issues."
)