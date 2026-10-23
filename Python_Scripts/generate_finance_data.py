
import random
from datetime import date, timedelta

import pyodbc


# --------------------------------------------------
# 1. CONFIGURATION
# --------------------------------------------------

SERVER = r"localhost\SQLEXPRESS"
DATABASE = "FinanceAnalyticsDB"

TOTAL_ROWS = 100_000
BATCH_SIZE = 5_000
RANDOM_SEED = 42

random.seed(RANDOM_SEED)


# --------------------------------------------------
# 2. CONNECT TO SQL SERVER
# --------------------------------------------------

connection_string = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

connection = pyodbc.connect(connection_string)
cursor = connection.cursor()

# Improve bulk insertion performance.
cursor.fast_executemany = True


# --------------------------------------------------
# 3. DEFINE SYNTHETIC BUSINESS DATA
# --------------------------------------------------

customers = [
    "ABC Pharma",
    "Global MedTech",
    "Northstar Healthcare",
    "Apex Laboratories",
    "BlueSky Retail",
    "Summit Industries",
    "Crescent Medical",
    "Vertex Solutions",
    "Orion Healthcare",
    "Pioneer Biotech",
]

products = [
    "Product A",
    "Product B",
    "Product C",
    "Product D",
    "Product E",
]

departments = [
    "Finance",
    "Sales",
    "Marketing",
    "Operations",
    "Research",
    "IT",
]

regions = [
    "India",
    "US",
    "Europe",
]

currencies = {
    "India": "INR",
    "US": "USD",
    "Europe": "EUR",
}

source_systems = [
    "ERP",
    "Billing System",
    "Finance Application",
]

start_date = date(2024, 1, 1)
end_date = date(2026, 9, 30)

date_range_days = (end_date - start_date).days


# --------------------------------------------------
# 4. GENERATE ONE TRANSACTION
# --------------------------------------------------

def generate_transaction(row_number):

    transaction_id = f"TXN{row_number:07d}"

    # Introduce some duplicate business transaction IDs.
    if row_number % 997 == 0:
        transaction_id = f"TXN{row_number - 1:07d}"

    transaction_date = (
        start_date
        + timedelta(days=random.randint(0, date_range_days))
    ).isoformat()

    customer = random.choice(customers)
    product = random.choice(products)
    department = random.choice(departments)
    region = random.choice(regions)
    currency = currencies[region]

    # Introduce inconsistent customer-name formatting.
    if row_number % 101 == 0:
        customer = customer.lower()

    elif row_number % 137 == 0:
        customer = customer + " "

    # Generate plausible but synthetic financial amounts.
    revenue = round(random.uniform(5_000, 250_000), 2)
    cost_of_goods = round(
        revenue * random.uniform(0.40, 0.75), 2
    )
    operating_expense = round(
        revenue * random.uniform(0.05, 0.20), 2
    )

    # Raw data stores these values as text.
    revenue_text = f"{revenue:.2f}"
    cost_text = f"{cost_of_goods:.2f}"
    expense_text = f"{operating_expense:.2f}"

    # Introduce deliberately malformed values.
    # These will be detected and cleaned in later stages.
    if row_number % 503 == 0:
        revenue_text = "N/A"

    if row_number % 701 == 0:
        transaction_date = "Unknown"

    if row_number % 809 == 0:
        customer = None

    if row_number % 907 == 0:
        expense_text = ""

    if row_number % 613 == 0:
        region = "US "  # Inconsistent whitespace.

    return (
        transaction_id,
        transaction_date,
        customer,
        product,
        department,
        region,
        currency,
        revenue_text,
        cost_text,
        expense_text,
        random.choice(source_systems),
    )


# --------------------------------------------------
# 5. INSERT INTO SQL SERVER IN BATCHES
# --------------------------------------------------

insert_sql = """
INSERT INTO raw.Transactions (
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
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
"""

total_inserted = 0

try:
    for batch_start in range(1, TOTAL_ROWS + 1, BATCH_SIZE):

        batch_end = min(
            batch_start + BATCH_SIZE,
            TOTAL_ROWS + 1
        )

        batch = [
            generate_transaction(i)
            for i in range(batch_start, batch_end)
        ]

        cursor.executemany(insert_sql, batch)
        connection.commit()

        total_inserted += len(batch)

        print(
            f"Inserted {total_inserted:,} "
            f"of {TOTAL_ROWS:,} rows"
        )

    print("Data generation and insertion completed.")

except Exception:
    connection.rollback()
    raise

finally:
    cursor.close()
    connection.close()

print(f"Total rows submitted: {total_inserted:,}")
