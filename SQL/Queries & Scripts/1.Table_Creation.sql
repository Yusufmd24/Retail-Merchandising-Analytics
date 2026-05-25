CREATE TABLE sales_transactions (

    invoice_id        VARCHAR(20) NOT NULL,
    product_id        VARCHAR(20) NOT NULL,

    description       VARCHAR(255) NOT NULL,
    category          VARCHAR(50) NOT NULL,
    vendor            VARCHAR(100) NOT NULL,

    customer_id       VARCHAR(50) NOT NULL,
    customer_segment  VARCHAR(50) NOT NULL,
    country           VARCHAR(50) NOT NULL,

    invoice_date      DATETIME2 NOT NULL,
    year              SMALLINT NOT NULL,
    month             TINYINT NOT NULL,
    week              TINYINT NOT NULL,
    day               TINYINT NOT NULL,
    weekday           VARCHAR(20) NOT NULL,

    quantity          INT NOT NULL,
    items_per_order   INT NOT NULL,

    unit_price        DECIMAL(10,2) NOT NULL,
    cost              DECIMAL(10,2) NOT NULL,
    sales             DECIMAL(12,2) NOT NULL,
    profit            DECIMAL(12,2) NOT NULL,
    margin_pct        DECIMAL(5,2) NOT NULL,
    revenue_per_unit  DECIMAL(10,2) NOT NULL,
    order_value       DECIMAL(12,2) NOT NULL,
    category_contribution DECIMAL(5,2) NOT NULL,

    promo_flag        VARCHAR(10) NOT NULL,
    channel           VARCHAR(50) NOT NULL,

    high_revenue_product  BIT NOT NULL,
    high_volume_product   BIT NOT NULL,
    low_margin_flag       BIT NOT NULL,
    high_margin_flag      BIT NOT NULL,

    fill_rate         DECIMAL(5,2) NOT NULL,

    CONSTRAINT PK_sales PRIMARY KEY (invoice_id, product_id)
);

-- Renaming the Imported table

EXEC sp_rename 'dbo.clean_final', 'sales_transactions_imported';

SELECT TOP 10 * FROM sales_transactions_imported;

-- Transfer data
INSERT INTO sales_transactions (
    invoice_id,
    product_id,
    description,
    category,
    vendor,
    customer_id,
    customer_segment,
    country,
    invoice_date,
    year,
    month,
    week,
    day,
    weekday,
    quantity,
    items_per_order,
    unit_price,
    cost,
    sales,
    profit,
    margin_pct,
    revenue_per_unit,
    order_value,
    category_contribution,
    promo_flag,
    channel,
    high_revenue_product,
    high_volume_product,
    low_margin_flag,
    high_margin_flag,
    fill_rate
)

SELECT
    invoice_id,
    product_id,
    description,
    category,
    vendor,
    customer_id,
    customer_segment,
    country,

    -- 🔥 FIXED DATE CONVERSION (handles DD/MM/YYYY)
    TRY_CONVERT(DATETIME2, invoice_date, 103) AS invoice_date,

    year,
    month,
    week,
    day,
    weekday,
    quantity,
    items_per_order,

    CAST(unit_price AS DECIMAL(10,2)),
    CAST(cost AS DECIMAL(10,2)),
    CAST(sales AS DECIMAL(12,2)),
    CAST(profit AS DECIMAL(12,2)),
    CAST(margin_pct AS DECIMAL(5,2)),
    CAST(revenue_per_unit AS DECIMAL(10,2)),
    CAST(order_value AS DECIMAL(12,2)),
    CAST(category_contribution AS DECIMAL(5,2)),

    promo_flag,
    channel,

    CAST(high_revenue_product AS BIT),
    CAST(high_volume_product AS BIT),
    CAST(low_margin_flag AS BIT),
    CAST(high_margin_flag AS BIT),

    CAST(fill_rate AS DECIMAL(5,2))

FROM sales_transactions_imported;

-- 🚫 Skip bad date rows (prevents crash)
--WHERE TRY_CONVERT(DATETIME2, invoice_date, 103) IS NOT NULL;