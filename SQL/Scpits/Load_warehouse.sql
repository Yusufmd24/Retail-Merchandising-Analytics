
/* =========================================================
   LOWE'S MERCHANDISING ANALYST PROJECT
   STAR SCHEMA LOAD SCRIPT
   BASE TABLE: dbo.retail_data

   FLOW:
   retail_data
   → Dimension Tables
   → Fact Table

   IMPORTANT:
   Run AFTER star_schema_lowes.sql
========================================================= */

------------------------------------------------------------
-- STEP 1 — LOAD DIM_CATEGORY
------------------------------------------------------------

INSERT INTO dim_category (category_name)
SELECT DISTINCT
    category
FROM dbo.retail_data
WHERE category IS NOT NULL
  AND LTRIM(RTRIM(category)) <> '';

------------------------------------------------------------
-- STEP 2 — LOAD DIM_PRODUCT
------------------------------------------------------------

INSERT INTO dim_product (
    product_id,
    description,
    category_key
)
SELECT DISTINCT
    r.product_id,
    r.description,
    dc.category_key
FROM dbo.retail_data r
LEFT JOIN dim_category dc
    ON r.category = dc.category_name
WHERE r.product_id IS NOT NULL;

------------------------------------------------------------
-- STEP 3 — LOAD DIM_CUSTOMER
------------------------------------------------------------

INSERT INTO dim_customer (
    customer_id,
    country
)
SELECT DISTINCT
    customer_id,
    country
FROM dbo.retail_data;



------------------------------------------------------------
-- STEP 4 — LOAD DIM_VENDOR
------------------------------------------------------------

INSERT INTO dim_vendor (
    vendor_name,
    fill_rate
)
SELECT DISTINCT
    vendor,
    CAST(AVG(fill_rate) OVER (
        PARTITION BY vendor
    ) AS DECIMAL(10,2))
FROM dbo.retail_data
WHERE vendor IS NOT NULL;



------------------------------------------------------------
-- STEP 5 — LOAD DIM_CHANNEL
------------------------------------------------------------

INSERT INTO dim_channel (channel_name)
SELECT DISTINCT
    channel
FROM dbo.retail_data
WHERE channel IS NOT NULL;



------------------------------------------------------------
-- STEP 6 — LOAD DIM_DATE
------------------------------------------------------------

INSERT INTO dim_date (
    invoice_date,
    year,
    month,
    week,
    quarter
)
SELECT DISTINCT
    CAST(invoice_date AS DATE),
    year,
    month,
    week,
    DATEPART(QUARTER, invoice_date)
FROM dbo.retail_data
WHERE invoice_date IS NOT NULL;



------------------------------------------------------------
-- STEP 7 — LOAD FACT_SALES
------------------------------------------------------------

INSERT INTO fact_sales (
    invoice_id,
    product_key,
    customer_key,
    vendor_key,
    channel_key,
    date_key,

    quantity,
    unit_price,
    sales,
    cost,
    profit,
    margin_pct,

    promo_flag,
    order_value,
    items_per_order,
    category_contribution
)

SELECT
    r.invoice_id,

    dp.product_key,
    dc.customer_key,
    dv.vendor_key,
    dch.channel_key,
    dd.date_key,

    r.quantity,

    CAST(r.unit_price AS DECIMAL(18,2)),
    CAST(r.sales AS DECIMAL(18,2)),
    CAST(r.cost AS DECIMAL(18,2)),
    CAST(r.profit AS DECIMAL(18,2)),
    CAST(r.margin_pct AS DECIMAL(18,2)),

    r.promo_flag,

    CAST(r.order_value AS DECIMAL(18,2)),
    r.items_per_order,

    NULL AS category_contribution

FROM dbo.retail_data r

LEFT JOIN dim_product dp
    ON r.product_id = dp.product_id

LEFT JOIN dim_customer dc
    ON r.customer_id = dc.customer_id
   AND ISNULL(r.country, '') = ISNULL(dc.country, '')

LEFT JOIN dim_vendor dv
    ON r.vendor = dv.vendor_name

LEFT JOIN dim_channel dch
    ON r.channel = dch.channel_name

LEFT JOIN dim_date dd
    ON CAST(r.invoice_date AS DATE) = dd.invoice_date;
