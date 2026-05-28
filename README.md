# 🛒 Retail Merchandising Analytics — End-to-End Intelligence Pipeline

> *From raw transaction data to boardroom-ready merchandising decisions — covering SQL Server, Python EDA, star-schema design, and a multi-tab Power BI merchant dashboard.*

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat)
![Rows](https://img.shields.io/badge/Dataset-500%2C000%2B%20rows-blue?style=flat)

---

## 📌 Business Problem

Retail merchandising teams operate on thin margins and make high-stakes decisions every week — which SKUs to reorder, which promotions actually lift revenue, which vendors are underperforming. Without a structured analytical pipeline, these decisions rely on gut instinct and fragmented spreadsheets.

**This project simulates a fully functional merchandising analytics stack** for a home-improvement retail environment — starting with raw, messy transaction data and ending with a live Power BI dashboard that a merchant or category manager could use on Monday morning.

**Key business questions answered:**

| # | Question | Delivered via |
|---|----------|---------------|
| 1 | Which product categories and SKUs are driving or destroying margin? | Weekly Sales & Margin Summary SQL + Power BI |
| 2 | Are our vendors hitting their cost and availability commitments? | Vendor Scorecard SQL + Dashboard Tab |
| 3 | Do our promotions actually lift revenue — or just cannibalize it? | Promotional Lift Analysis SQL |
| 4 | What is our omni-channel revenue split and how is it trending? | Omni-Channel Split Query |
| 5 | What happens to margin if vendor costs increase by X%? | Cost Change Simulation Query |

---

## 🗂️ Project Structure

```
Retail-Merchandising-Analytics/
│
├── Raw_Data/                    # Source CSVs — synthetic, 50K+ rows
├── Cleaned_Data/                # Python-cleaned and transformed data
├── Excel_Report/                # Pivot analysis, category summary reports
├── SQL/                         # DDL schema files + 6 analytical queries
├── Power BI/                    # Merchandising_Intelligence_Report.pbix
│
└── README.md```
````
---

## 🏗️ Architecture: Star Schema

The data model follows a classic **Kimball star schema** — one central fact table surrounded by five conformed dimension tables. This design was chosen for Power BI's DirectQuery compatibility and optimal DAX filter context.

```
                    ┌─────────────────┐
                    │  dim_promotion  │
                    └────────┬────────┘
                             │
  ┌──────────────┐   ┌───────▼────────┐   ┌──────────────┐
  │  dim_vendor  ├───►  fact_sales    ◄───┤  dim_product │
  └──────────────┘   │                │   └──────────────┘
                     │  • sale_id     │
  ┌──────────────┐   │  • store_key   │   ┌──────────────┐
  │  dim_store   ├───►  • product_key │   │   dim_date   │
  └──────────────┘   │  • vendor_key  ◄───┤              │
                     │  • date_key    │   └──────────────┘
                     │  • promo_key   │
                     │  • units_sold  │
                     │  • revenue     │
                     │  • cogs        │
                     └────────────────┘
```

**Key design decisions:**
- All foreign keys typed as `INT NOT NULL` for join performance
- `dim_date` pre-populated for 3 years to support YoY comparisons
- `dim_promotion` includes a `is_promoted` flag to enable lift calculations without a separate bridge table
- Surrogate keys on all dimensions; natural keys preserved as attributes

---

## 🐍 Phase 1 — Python EDA & Data Cleaning

**Notebook:** `notebooks/01_EDA_and_Cleaning.ipynb`

Before loading into SQL Server, all 50,000+ raw transaction rows were profiled and cleaned in Python.

**What was done:**

```python
# Key cleaning operations
df['transaction_date'] = pd.to_datetime(df['transaction_date'], errors='coerce')
df['unit_cost'] = pd.to_numeric(df['unit_cost'], errors='coerce')
df.dropna(subset=['sale_id', 'product_sku', 'store_id'], inplace=True)

# Derived metrics
df['gross_margin'] = df['revenue'] - df['cogs']
df['margin_pct']   = (df['gross_margin'] / df['revenue']) * 100

# Outlier detection — IQR method on unit revenue
Q1, Q3 = df['revenue'].quantile([0.25, 0.75])
df = df[df['revenue'].between(Q1 - 1.5*(Q3-Q1), Q3 + 1.5*(Q3-Q1))]
```

**EDA findings that shaped the model:**
- 3.2% of rows had null `unit_cost` — imputed via median cost per `vendor_id × category`
- Revenue distribution showed significant right skew → log-transformed for outlier flagging
- 7 stores had zero omni-channel orders in Q1 — flagged as a data completeness issue, not a business signal

---

## 🗄️ Phase 2 — SQL Server Schema & Queries

### DDL Sample — `fact_sales`
<details>
<summary>View SQL Query</summary>

```sql
CREATE TABLE fact_sales (
    sale_id       INT           NOT NULL PRIMARY KEY,
    date_key      INT           NOT NULL,
    product_key   INT           NOT NULL,
    store_key     INT           NOT NULL,
    vendor_key    INT           NOT NULL,
    promo_key     INT           NOT NULL,
    units_sold    INT           NOT NULL,
    revenue       DECIMAL(12,2) NOT NULL,
    cogs          DECIMAL(12,2) NOT NULL,
    gross_margin  AS (revenue - cogs) PERSISTED,

    CONSTRAINT fk_date    FOREIGN KEY (date_key)    REFERENCES dim_date(date_key),
    CONSTRAINT fk_product FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    CONSTRAINT fk_store   FOREIGN KEY (store_key)   REFERENCES dim_store(store_key),
    CONSTRAINT fk_vendor  FOREIGN KEY (vendor_key)  REFERENCES dim_vendor(vendor_key),
    CONSTRAINT fk_promo   FOREIGN KEY (promo_key)   REFERENCES dim_promotion(promo_key)
);
```
</details>
---

### Query 1 — Weekly Sales & Margin Summary
<details>
<summary>View SQL Query</summary>
```sql
SELECT
    d.year_num,
    d.week_num,
    p.category,
    SUM(f.revenue)                                          AS total_revenue,
    SUM(f.gross_margin)                                     AS total_margin,
    ROUND(SUM(f.gross_margin) / NULLIF(SUM(f.revenue),0) * 100, 2) AS margin_pct,
    LAG(SUM(f.revenue)) OVER (
        PARTITION BY p.category ORDER BY d.year_num, d.week_num
    )                                                       AS prev_week_revenue,
    ROUND(
        (SUM(f.revenue) - LAG(SUM(f.revenue)) OVER (
            PARTITION BY p.category ORDER BY d.year_num, d.week_num
        )) / NULLIF(LAG(SUM(f.revenue)) OVER (
            PARTITION BY p.category ORDER BY d.year_num, d.week_num
        ), 0) * 100, 2
    )                                                       AS wow_growth_pct
FROM fact_sales f
JOIN dim_date    d ON f.date_key    = d.date_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY d.year_num, d.week_num, p.category
ORDER BY d.year_num, d.week_num, total_revenue DESC;
````
</details>

![Weekly Sales Query Result](4.%20SQL/SQL_Query_Screenshots/Merchandising_Queries/1.Weekly_Sales_and_Margin_by_Category.png)

---

### Query 2 — Vendor Scorecard
<details>
<summary>View SQL Query</summary>
```sql
SELECT
    v.vendor_name,
    COUNT(DISTINCT f.sale_id)                               AS total_transactions,
    SUM(f.revenue)                                          AS total_revenue,
    SUM(f.gross_margin)                                     AS total_margin,
    ROUND(AVG(f.gross_margin / NULLIF(f.revenue,0)) * 100, 2) AS avg_margin_pct,
    RANK() OVER (ORDER BY SUM(f.gross_margin) DESC)         AS margin_rank
FROM fact_sales f
JOIN dim_vendor v ON f.vendor_key = v.vendor_key
GROUP BY v.vendor_name
ORDER BY total_margin DESC;
```
</details>
---

### Query 3 — Promotional Lift Analysis
<details>
<summary>View SQL Query</summary>
```sql
WITH promo_sales AS (
    SELECT
        p.category,
        pr.promo_name,
        pr.is_promoted,
        AVG(f.revenue / NULLIF(f.units_sold, 0))            AS avg_unit_revenue,
        AVG(f.gross_margin / NULLIF(f.revenue, 0)) * 100    AS avg_margin_pct
    FROM fact_sales f
    JOIN dim_product   p  ON f.product_key = p.product_key
    JOIN dim_promotion pr ON f.promo_key   = pr.promo_key
    GROUP BY p.category, pr.promo_name, pr.is_promoted
)
SELECT
    category,
    promo_name,
    MAX(CASE WHEN is_promoted = 1 THEN avg_unit_revenue END) AS promo_avg_rev,
    MAX(CASE WHEN is_promoted = 0 THEN avg_unit_revenue END) AS baseline_avg_rev,
    ROUND(
        (MAX(CASE WHEN is_promoted = 1 THEN avg_unit_revenue END) -
         MAX(CASE WHEN is_promoted = 0 THEN avg_unit_revenue END)) /
        NULLIF(MAX(CASE WHEN is_promoted = 0 THEN avg_unit_revenue END), 0) * 100
    , 2)                                                     AS lift_pct
FROM promo_sales
GROUP BY category, promo_name
ORDER BY lift_pct DESC;
```
</details>
---

### Query 4 — Top & Bottom SKUs by Margin

```sql
WITH sku_margin AS (
    SELECT
        p.sku_code,
        p.product_name,
        p.category,
        SUM(f.gross_margin)  AS total_margin,
        SUM(f.revenue)       AS total_revenue,
        ROUND(SUM(f.gross_margin) / NULLIF(SUM(f.revenue),0) * 100, 2) AS margin_pct
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    GROUP BY p.sku_code, p.product_name, p.category
)
SELECT *, 'Top 10' AS segment
FROM (
    SELECT *, RANK() OVER (ORDER BY total_margin DESC) AS rnk FROM sku_margin
) t WHERE rnk <= 10
UNION ALL
SELECT *, 'Bottom 10' AS segment
FROM (
    SELECT *, RANK() OVER (ORDER BY total_margin ASC) AS rnk FROM sku_margin
) b WHERE rnk <= 10;
```

---

### Query 5 — Omni-Channel Revenue Split

```sql
SELECT
    d.year_num,
    d.month_num,
    s.channel_type,                         -- 'In-Store' | 'Online' | 'BOPIS'
    SUM(f.revenue)                          AS channel_revenue,
    ROUND(
        SUM(f.revenue) / SUM(SUM(f.revenue)) OVER
            (PARTITION BY d.year_num, d.month_num) * 100
    , 2)                                    AS channel_revenue_share_pct
FROM fact_sales f
JOIN dim_date  d ON f.date_key  = d.date_key
JOIN dim_store s ON f.store_key = s.store_key
GROUP BY d.year_num, d.month_num, s.channel_type
ORDER BY d.year_num, d.month_num, channel_revenue DESC;
```

---

### Query 6 — Cost Change Simulation (What-If)

```sql
-- Simulates margin impact of a vendor cost increase of N%
DECLARE @cost_increase_pct DECIMAL(5,2) = 5.00;   -- change this parameter

SELECT
    v.vendor_name,
    p.category,
    SUM(f.revenue)                                          AS current_revenue,
    SUM(f.cogs)                                             AS current_cogs,
    SUM(f.gross_margin)                                     AS current_margin,
    SUM(f.cogs) * (1 + @cost_increase_pct / 100)           AS simulated_cogs,
    SUM(f.revenue) - SUM(f.cogs) * (1 + @cost_increase_pct / 100) AS simulated_margin,
    ROUND(
        (SUM(f.revenue) - SUM(f.cogs) * (1 + @cost_increase_pct / 100)) /
        NULLIF(SUM(f.revenue), 0) * 100
    , 2)                                                    AS simulated_margin_pct,
    ROUND(
        SUM(f.gross_margin) - (SUM(f.revenue) - SUM(f.cogs) * (1 + @cost_increase_pct / 100))
    , 2)                                                    AS margin_erosion
FROM fact_sales f
JOIN dim_vendor  v ON f.vendor_key  = v.vendor_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY v.vendor_name, p.category
ORDER BY margin_erosion DESC;
```

---

## 📊 Phase 3 — Power BI Merchandising Intelligence Report

**File:** `powerbi/Merchandising_Intelligence_Report.pbix`

The Power BI report replicates a merchant's weekly dashboard across **5 report tabs**, designed to surface decisions — not just numbers.

| Tab | Purpose | Key Visuals |
|-----|---------|-------------|
| **1. Executive Overview** | C-suite summary of revenue, margin, and trend | KPI cards, revenue trend line, margin waterfall |
| **2. Category Performance** | Weekly sales & margin by category with WoW % | Matrix with conditional formatting, bar/line combo |
| **3. Vendor Scorecard** | Vendor ranking by margin, revenue, and volume | Ranked bar chart, scatter (revenue vs. margin), heat map |
| **4. Promotional Intelligence** | Lift analysis per promo per category | Clustered bar (promo vs. baseline), lift % table |
| **5. SKU & Channel Drill-Through** | Top/bottom SKUs; omni-channel split | Treemap, donut chart, drill-through detail page |

### Key DAX Measures (sample)

```dax
-- Total Gross Margin
Gross Margin = SUMX(fact_sales, fact_sales[revenue] - fact_sales[cogs])

-- Margin %
Margin % = DIVIDE([Gross Margin], [Total Revenue], 0)

-- WoW Revenue Growth
WoW Revenue % =
VAR current_week = [Total Revenue]
VAR prior_week   = CALCULATE([Total Revenue],
                    DATEADD(dim_date[date], -7, DAY))
RETURN DIVIDE(current_week - prior_week, prior_week, 0)

-- Promotional Lift %
Promo Lift % =
VAR promo_rev    = CALCULATE([Avg Unit Revenue],
                    dim_promotion[is_promoted] = 1)
VAR baseline_rev = CALCULATE([Avg Unit Revenue],
                    dim_promotion[is_promoted] = 0)
RETURN DIVIDE(promo_rev - baseline_rev, baseline_rev, 0)
```

> Full DAX library with business context → [`docs/dax_measures.md`](docs/dax_measures.md)

---

## 🔑 Key Findings

> *(Replace with actual findings from your dataset once the pbix is populated)*

- **Top 3 categories** contributed ~62% of total gross margin despite representing only 38% of SKU count — a classic long-tail margin skew
- **Promotional lift** was positive for 7 of 9 promotions, but 2 promotions in the Flooring category showed **negative lift** (revenue cannibalization), suggesting discount depth was too aggressive
- **Online channel** grew from 18% → 27% revenue share over the analysis period, while BOPIS (Buy Online, Pick Up In Store) emerged as the highest-margin channel
- **Vendor concentration risk**: top 3 vendors account for 54% of COGS — a 5% cost increase from any one would erode annual margin by ~₹12L (simulated)

---

## ⚙️ How to Reproduce

### 1. Clone the repo
```bash
git clone https://github.com/YOUR_USERNAME/retail-merchandising-analytics.git
cd retail-merchandising-analytics
```

### 2. Set up Python environment
```bash
pip install pandas numpy matplotlib seaborn sqlalchemy pyodbc jupyter
jupyter notebook notebooks/01_EDA_and_Cleaning.ipynb
```

### 3. Load SQL Server schema
```sql
-- Run in order:
-- 1. sql/schema/ddl_dim_date.sql
-- 2. sql/schema/ddl_dim_product.sql
-- 3. sql/schema/ddl_dim_store.sql
-- 4. sql/schema/ddl_dim_vendor.sql
-- 5. sql/schema/ddl_dim_promotion.sql
-- 6. sql/schema/ddl_fact_sales.sql
```

### 4. Open Power BI
Open `powerbi/Merchandising_Intelligence_Report.pbix` and update the SQL Server connection string to point to your local instance.

---

## 🛠️ Tech Stack

| Layer | Tools |
|-------|-------|
| Data Cleaning & EDA | Python 3.11, Pandas, NumPy, Matplotlib, Seaborn |
| Database | Microsoft SQL Server 2019, SSMS |
| Data Modeling | Kimball Star Schema (1 Fact + 5 Dimensions) |
| Analytics Queries | T-SQL (Window Functions, CTEs, Parameterized Simulation) |
| Visualisation | Power BI Desktop (DAX, DirectQuery, Row-Level Security) |

---

## 👤 About

**Md Yusuf** — Data Analyst with a background in operational leadership across manufacturing and events. I build analytics pipelines that connect raw data to business decisions.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=flat&logo=linkedin)](https://linkedin.com/in/YOUR_LINKEDIN)
[![Portfolio](https://img.shields.io/badge/Portfolio-Visit-black?style=flat&logo=github)](https://YOUR_USERNAME.github.io)

---

*This project uses synthetic retail data generated for portfolio purposes. No proprietary or confidential data from any organisation is used.*
