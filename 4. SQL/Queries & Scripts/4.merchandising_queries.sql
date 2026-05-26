/* =========================================================
   FILE: merchandising_queries.sql
   PROJECT: Lowe's Merchandising Analyst Case Study

   BUILT ON:
   Star Schema Warehouse
   - fact_sales
   - dim_product
   - dim_category
   - dim_customer
   - dim_vendor
   - dim_channel
   - dim_date

   GOAL: Business-facing analytical SQL Layer

========================================================= */



/* =========================================================
   QUERY 1 — Weekly Sales & Margin Summary by Category

   Business Question:
   Which categories drive revenue and margin week by week?
========================================================= */
SELECT
    d.year,
    d.week,
    c.category_name AS category,
    SUM(f.sales) AS revenue,
    SUM(f.cost) AS cost,
    SUM(f.profit) AS profit,
    100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0) AS margin_pct
FROM fact_sales f
JOIN dim_product p  ON f.product_key = p.product_key
JOIN dim_category c ON p.category_key = c.category_key
JOIN dim_date d     ON f.date_key = d.date_key
GROUP BY d.year, d.week, c.category_name
ORDER BY d.year, d.week, revenue DESC;

/* =========================================================
   QUERY 2 — Vendor Scorecard

   Business Question:
   Which vendors contribute most revenue and which vendors create supply risk?
   ========================================================= */
SELECT
    v.vendor_name AS vendor,
    AVG(v.fill_rate) AS fill_rate_pct,
    SUM(f.sales) AS revenue,
    SUM(f.profit) AS profit,
    100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0) AS margin_pct,
    DENSE_RANK() OVER (ORDER BY SUM(f.sales) DESC) AS vendor_rank
FROM fact_sales f
JOIN dim_vendor v
    ON f.vendor_key = v.vendor_key
GROUP BY v.vendor_name
ORDER BY vendor_rank;

/* =========================================================
   QUERY 3 — Promotional Lift Analysis

   Business Question:
   Are promotions actually driving incremental weekly sales?
   ========================================================= */
WITH x AS (
    SELECT
        c.category_name AS category,
        f.promo_flag,
        SUM(f.sales) * 1.0 /
        COUNT(DISTINCT CONCAT(d.year, '-', d.week)) AS avg_weekly_sales
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    JOIN dim_category c ON p.category_key = c.category_key
    JOIN dim_date d ON f.date_key = d.date_key
    GROUP BY c.category_name, f.promo_flag
)

SELECT
    category,
    MAX(CASE WHEN promo_flag = 'Promo' THEN avg_weekly_sales END) AS promo_sales,
    MAX(CASE WHEN promo_flag = 'Regular' THEN avg_weekly_sales END) AS regular_sales,
    100.0 *
    (
        MAX(CASE WHEN promo_flag = 'Promo' THEN avg_weekly_sales END) -
        MAX(CASE WHEN promo_flag = 'Regular' THEN avg_weekly_sales END)
    )
    /
    NULLIF(
        MAX(CASE WHEN promo_flag = 'Regular' THEN avg_weekly_sales END),
        0
    ) AS promo_lift_pct
FROM x
GROUP BY category
ORDER BY promo_lift_pct DESC;

/* =========================================================
   QUERY 4 — Top & Bottom 10 SKUs by Margin Contribution

   Business Question:
   Which SKUs are hero products and which are margin destroyers?
   ========================================================= */
WITH sku AS (
    SELECT
        p.product_id,
        p.description,
        c.category_name AS category,
        SUM(f.sales) AS revenue,
        SUM(f.profit) AS profit
    FROM fact_sales f
    JOIN dim_product p
        ON f.product_key = p.product_key
    JOIN dim_category c
        ON p.category_key = c.category_key
    GROUP BY
        p.product_id,
        p.description,
        c.category_name
),

ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            ORDER BY profit DESC
        ) AS top_rank,

        DENSE_RANK() OVER (
            ORDER BY profit ASC
        ) AS bottom_rank
    FROM sku
)

SELECT
    CASE
        WHEN top_rank <= 10 THEN 'TOP 10'
        WHEN bottom_rank <= 10 THEN 'BOTTOM 10'
    END AS performance_group,

    product_id,
    description,
    category,
    revenue,
    profit

FROM ranked

WHERE
    top_rank <= 10
    OR bottom_rank <= 10

ORDER BY
    CASE
        WHEN top_rank <= 10 THEN 1
        ELSE 2
    END,
    profit DESC;

/* =========================================================
   QUERY 5 — Omni-Channel Split

   Business Question:
   How does Online vs In-Store performance differ by category?
   ========================================================= */
SELECT
    c.category_name AS category,
    ch.channel_name AS channel,
    SUM(f.sales) AS revenue,
    SUM(f.cost) AS cost,
    SUM(f.profit) AS profit,
    100.0 * SUM(f.profit) / NULLIF(SUM(f.sales), 0) AS margin_pct
FROM fact_sales f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_category c ON p.category_key = c.category_key
JOIN dim_channel ch ON f.channel_key = ch.channel_key
GROUP BY
    c.category_name,
    ch.channel_name
ORDER BY category, revenue DESC;

/* =========================================================
   QUERY 6 — Cost Change Impact Simulation

   Business Question:
   What happens if vendor cost rises by +5%, +8%, +10% ?
   ========================================================= */
WITH base AS (
    SELECT
        c.category_name AS category,
        SUM(f.sales) AS revenue,
        SUM(f.cost) AS cost
    FROM fact_sales f
    JOIN dim_product p ON f.product_key = p.product_key
    JOIN dim_category c ON p.category_key = c.category_key
    GROUP BY c.category_name
)

SELECT
    category,
    revenue,
    cost,
    100.0 * (revenue - cost * 1.05) / NULLIF(revenue, 0) AS margin_5pct,
    100.0 * (revenue - cost * 1.08) / NULLIF(revenue, 0) AS margin_8pct,
    100.0 * (revenue - cost * 1.10) / NULLIF(revenue, 0) AS margin_10pct
FROM base
ORDER BY revenue DESC;