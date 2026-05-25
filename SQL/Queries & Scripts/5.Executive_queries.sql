/* =========================================================
   FILE: executive_queries.sql
   PROJECT: Lowe's Merchandising Analyst Case Study

   PURPOSE:
   Executive-Level SQL Analysis
   Built for leadership decisions:
   - supply risk
   - customer value
   - seasonal planning
   - pricing strategy
   - inventory concentration risk

   BUILT ON:
   fact_sales + dimension tables

========================================================= */


/* =========================================================
   QUERY 1 — Stock Risk / Low Fill Rate Alert

   BUSINESS PURPOSE: Identify vendors creating operational risk.

   Why it matters: High revenue + low fill rate vendors can cause stockouts, lost sales, and customer dissatisfaction.
   ========================================================= */
SELECT
    v.vendor_name AS vendor,
    c.category_name AS category,
    AVG(v.fill_rate) AS fill_rate_pct,
    SUM(f.sales) AS revenue,
    SUM(f.profit) AS profit
FROM fact_sales f
JOIN dim_vendor v   ON f.vendor_key = v.vendor_key
JOIN dim_product p  ON f.product_key = p.product_key
JOIN dim_category c ON p.category_key = c.category_key
GROUP BY
    v.vendor_name,
    c.category_name
HAVING AVG(v.fill_rate) < 90
ORDER BY revenue DESC;

/* =========================================================
   QUERY 2 — Repeat Purchase / High Value Customers

   BUSINESS PURPOSE: Identify customers driving repeat revenue.

   Why it matters: Repeat buyers are cheaper to retain than acquiring
   new customers and are critical for long-term growth.
   ========================================================= */
SELECT TOP 20
    cu.customer_id,
    cu.country,
    COUNT(DISTINCT f.invoice_id) AS orders,
    SUM(f.sales) AS spend,
    AVG(f.order_value) AS avg_order_value
FROM fact_sales f
JOIN dim_customer cu
    ON f.customer_key = cu.customer_key
WHERE cu.customer_id IS NOT NULL
GROUP BY
    cu.customer_id,
    cu.country
ORDER BY spend DESC;


/* =========================================================
   QUERY 3 — Seasonal Trend Analysis

   BUSINESS PURPOSE: Understand which categories peak in which months.

   Why it matters: Supports inventory planning, forecasting,
   vendor negotiations, and seasonal promotions.
   ========================================================= */
SELECT
    d.month,
    c.category_name AS category,
    SUM(f.sales) AS revenue,
    SUM(f.quantity) AS units,
    SUM(f.profit) AS profit
FROM fact_sales f
JOIN dim_date d     ON f.date_key = d.date_key
JOIN dim_product p  ON f.product_key = p.product_key
JOIN dim_category c ON p.category_key = c.category_key
GROUP BY
    d.month,
    c.category_name
ORDER BY
    d.month,
    revenue DESC;

/* =========================================================
   QUERY 4 — Price Sensitivity Analysis

   BUSINESS PURPOSE: Measure whether price increases reduce quantity sold.

   Why it matters: Helps merchandising teams optimize pricing strategy
   without damaging demand.
   ========================================================= */
SELECT
    p.product_id,
    p.description,
    c.category_name AS category,
    AVG(f.unit_price) AS avg_price,
    SUM(f.quantity) AS units_sold,
    SUM(f.sales) AS revenue
FROM fact_sales f
JOIN dim_product p  ON f.product_key = p.product_key
JOIN dim_category c ON p.category_key = c.category_key
GROUP BY
    p.product_id,
    p.description,
    c.category_name
ORDER BY
    avg_price DESC,
    units_sold ASC;

/* =========================================================
   QUERY 5 — Revenue Concentration Risk

   BUSINESS PURPOSE: Identify over-dependence on a few categories.

   Why it matters: If too much revenue comes from one category,
   business becomes vulnerable to supply shocks and demand shifts.
   ========================================================= */
WITH x AS (
    SELECT
        c.category_name AS category,
        SUM(f.sales) AS revenue
    FROM fact_sales f
    JOIN dim_product p  ON f.product_key = p.product_key
    JOIN dim_category c ON p.category_key = c.category_key
    GROUP BY c.category_name
)

SELECT
    category,
    revenue,
    100.0 * revenue / SUM(revenue) OVER () AS contribution_pct
FROM x
ORDER BY contribution_pct DESC;