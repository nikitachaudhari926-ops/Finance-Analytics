
import pandas as pd
from sqlalchemy import create_engine
from urllib.parse import quote_plus

# --------------------------------------------------
# 1. DATABASE CONFIGURATION
# --------------------------------------------------

SERVER = r"localhost\SQLEXPRESS"
DATABASE = "FinanceAnalyticsDB"

# IMPORTANT:
# Replace YOUR_SERVER_NAME with the exact server name
# you already used successfully in your previous script.

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

# --------------------------------------------------
# 2. EXTRACT DATA FROM SQL SERVER
# --------------------------------------------------

query = """
SELECT
    raw_row_id,
    transaction_id,
    transaction_date,
    customer_name,
    product_name,
    department_name,
    region,
    currency_code,
    revenue,
    cost_of_goods,
    operating_expense,
    source_system
FROM raw.Transactions
ORDER BY raw_row_id;
"""

engine = create_engine(connection_url)

with engine.connect() as connection:
    df = pd.read_sql_query(query, connection)

print("Extraction successful")
print("Rows extracted:", len(df))

print("\nColumn names:")
print(df.columns.tolist())

print("\nFirst five rows:")
print(df.head())

print("\nData types:")
print(df.dtypes)

# --------------------------------------------------
# 3. DATA PROFILING
# --------------------------------------------------

print("\n--- 1. Dataset shape ---")
print("Rows:", df.shape[0])
print("Columns:", df.shape[1])

print("\n--- 2. Missing values by column ---")
print(df.isnull().sum())

print("\n--- 3. Unique values by column ---")
print(df.nunique())

print("\n--- 4. Invalid dates ---")
parsed_dates = pd.to_datetime(
    df["transaction_date"],
    format="%Y-%m-%d",
    errors="coerce"
)
print("Invalid dates:", parsed_dates.isna().sum())

print("\n--- 5. Invalid revenue values ---")
parsed_revenue = pd.to_numeric(
    df["revenue"],
    errors="coerce"
)
print("Invalid revenue:", parsed_revenue.isna().sum())

print("\n--- 6. Invalid cost of goods values ---")
parsed_cost = pd.to_numeric(
    df["cost_of_goods"],
    errors="coerce"
)
print("Invalid cost of goods:", parsed_cost.isna().sum())

print("\n--- 7. Invalid operating expense values ---")
parsed_expenses = pd.to_numeric(
    df["operating_expense"],
    errors="coerce"
)
print(
    "Invalid operating expenses:",
    parsed_expenses.isna().sum()
)

print("\n--- 8. Duplicate transaction IDs ---")
print(df["transaction_id"].duplicated().sum())

print("\n--- 9. Text whitespace issues ---")

for column in [
    "customer_name",
    "product_name",
    "department_name",
    "region",
    "currency_code",
]:
    whitespace_count = (
        df[column].notna()
        & df[column].ne(df[column].str.strip())
    ).sum()

    print(f"{column}: {whitespace_count}")

# --------------------------------------------------
# 4. CLOSE DATABASE CONNECTION POOL
# --------------------------------------------------


# --------------------------------------------------
# 4. CLEAN AND STANDARDIZE DATA
# --------------------------------------------------

print("\n--- CLEANING DATA ---")

# Keep a separate copy so the extracted raw DataFrame
# remains available for comparison.
clean_df = df.copy()

# 1. Standardize text by removing leading/trailing spaces.
text_columns = [
    "transaction_id",
    "customer_name",
    "product_name",
    "department_name",
    "region",
    "currency_code",
    "source_system",
]

for column in text_columns:
    clean_df[column] = clean_df[column].str.strip()

print("Text whitespace standardized.")

# 2. Preserve customer-name capitalization.
# We trim whitespace but do not alter brand or company names.
print("Customer-name capitalization preserved.")

# 3. Convert transaction dates to real date/time values.
clean_df["transaction_date"] = pd.to_datetime(
    clean_df["transaction_date"],
    format="%Y-%m-%d",
    errors="coerce"
)

# 4. Convert financial columns to numeric values.
numeric_columns = [
    "revenue",
    "cost_of_goods",
    "operating_expense",
]

for column in numeric_columns:
    clean_df[column] = pd.to_numeric(
        clean_df[column],
        errors="coerce"
    )

print("Dates and financial columns converted.")

# 5. Add quality flags instead of deleting records.
clean_df["invalid_date_flag"] = (
    clean_df["transaction_date"].isna()
)

clean_df["invalid_revenue_flag"] = (
    clean_df["revenue"].isna()
)

clean_df["invalid_cost_flag"] = (
    clean_df["cost_of_goods"].isna()
)

clean_df["invalid_expense_flag"] = (
    clean_df["operating_expense"].isna()
)

clean_df["missing_customer_flag"] = (
    clean_df["customer_name"].isna()
    | clean_df["customer_name"].eq("")
)

clean_df["duplicate_transaction_flag"] = (
    clean_df["transaction_id"].duplicated(keep=False)
)

print("Data-quality flags created.")

# --------------------------------------------------
# 5. VALIDATE CLEANED DATA
# --------------------------------------------------

print("\n--- CLEANING VALIDATION ---")

print("Raw row count:", len(df))
print("Cleaned row count:", len(clean_df))

print("\nCleaned data types:")
print(clean_df.dtypes)

print("\nInvalid or missing values after conversion:")
print(
    clean_df[
        [
            "transaction_date",
            "revenue",
            "cost_of_goods",
            "operating_expense",
            "customer_name",
        ]
    ].isna().sum()
)

print("\nQuality-flag totals:")
for flag in [
    "invalid_date_flag",
    "invalid_revenue_flag",
    "invalid_cost_flag",
    "invalid_expense_flag",
    "missing_customer_flag",
    "duplicate_transaction_flag",
]:
    print(f"{flag}: {int(clean_df[flag].sum())}")

print("\nFirst five cleaned rows:")
print(
    clean_df[
        [
            "raw_row_id",
            "transaction_id",
            "transaction_date",
            "customer_name",
            "revenue",
            "cost_of_goods",
            "operating_expense",
        ]
    ].head()
)

# Confirm no rows were removed during cleaning.
assert len(df) == len(clean_df), (
    "Unexpected row-count change during cleaning."
)

print("\nCleaning and validation completed.")


# --------------------------------------------------
# 6. LOAD CLEANED DATA INTO SQL SERVER
# --------------------------------------------------


print("\n--- LOADING DATA INTO SQL SERVER ---")

# Step 1: Ensure the staging schema exists.
with engine.begin() as connection:
    connection.exec_driver_sql("""
        IF SCHEMA_ID('staging') IS NULL
            EXEC('CREATE SCHEMA staging');
    """)

# Step 2: Check whether the table exists and has the intended structure.
with engine.connect() as connection:
    table_exists = connection.exec_driver_sql("""
        SELECT CASE
            WHEN OBJECT_ID('staging.Transactions', 'U') IS NULL
            THEN 0 ELSE 1
        END;
    """).scalar()

if table_exists:
    print("Existing staging table found.")
    print(
        "Its existing SQL data types will be checked before loading."
    )
else:
    print("Creating staging table with explicit SQL data types.")

    with engine.begin() as connection:
        connection.exec_driver_sql("""
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
        """)

# Step 3: Confirm the staging schema before loading.
with engine.connect() as connection:
    schema_df = pd.read_sql_query("""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'staging'
          AND TABLE_NAME = 'Transactions'
        ORDER BY ORDINAL_POSITION;
    """, connection)

expected_types = {
    "raw_row_id": "bigint",
    "transaction_id": "varchar",
    "transaction_date": "date",
    "customer_name": "varchar",
    "product_name": "varchar",
    "department_name": "varchar",
    "region": "varchar",
    "currency_code": "varchar",
    "revenue": "decimal",
    "cost_of_goods": "decimal",
    "operating_expense": "decimal",
    "source_system": "varchar",
    "invalid_date_flag": "bit",
    "invalid_revenue_flag": "bit",
    "invalid_cost_flag": "bit",
    "invalid_expense_flag": "bit",
    "missing_customer_flag": "bit",
    "duplicate_transaction_flag": "bit",
}

actual_types = dict(
    zip(schema_df["COLUMN_NAME"], schema_df["DATA_TYPE"])
)

if actual_types != expected_types:
    raise RuntimeError(
        "The existing staging table has different SQL data types. "
        "No data was loaded. Review the table schema before proceeding."
    )

# Step 4: Prepare the DataFrame to match the SQL table.
load_columns = list(expected_types.keys())
load_df = clean_df[load_columns].copy()

# SQL BIT columns require boolean values.
flag_columns = [
    "invalid_date_flag",
    "invalid_revenue_flag",
    "invalid_cost_flag",
    "invalid_expense_flag",
    "missing_customer_flag",
    "duplicate_transaction_flag",
]

for column in flag_columns:
    load_df[column] = load_df[column].astype(bool)

# Step 5: Replace the staging sample in a transaction.
# If insertion fails, SQL Server rolls back the delete and inserts.
with engine.begin() as connection:
    connection.exec_driver_sql(
        "DELETE FROM staging.Transactions;"
    )

    load_df.to_sql(
        name="Transactions",
        con=connection,
        schema="staging",
        if_exists="append",
        index=False,
        chunksize=5000,
    )

# Step 6: Validate row counts.
with engine.connect() as connection:
    staging_count = connection.exec_driver_sql("""
        SELECT COUNT_BIG(*)
        FROM staging.Transactions;
    """).scalar()

    raw_count = connection.exec_driver_sql("""
        SELECT COUNT_BIG(*)
        FROM raw.Transactions;
    """).scalar()

print("\n--- LOAD VALIDATION ---")
print("Rows extracted and cleaned:", len(load_df))
print("Rows in staging.Transactions:", staging_count)
print("Rows in raw.Transactions:", raw_count)

assert staging_count == len(load_df), (
    "Staging row count does not match the cleaned DataFrame."
)

assert raw_count == 100000, (
    "The raw table does not contain the expected 100,000 rows."
)

assert staging_count == raw_count, (
    "Staging and raw row counts do not match."
)

print("\nRow-count validation passed.")

# Step 7: Validate the data-quality flags.
with engine.connect() as connection:
    flag_results = pd.read_sql_query("""
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
                     THEN 1 ELSE 0 END) AS duplicate_rows
        FROM staging.Transactions;
    """, connection)

print("\n--- DATA QUALITY FLAGS ---")
print(flag_results.to_string(index=False))

engine.dispose()
print("\nETL pipeline completed successfully.")

