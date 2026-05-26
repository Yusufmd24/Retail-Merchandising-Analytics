
select * from retail_data;

/* =========================================================
   LOWE'S MERCHANDISING ANALYST PROJECT
   STAR SCHEMA DESIGN
   SQL SERVER VERSION

   FLOW:
   Raw Import Table
   → Dimension Tables
   → Fact Table
========================================================= */


/* =========================================================
   DIMENSION TABLE 1 — CATEGORY
========================================================= */

CREATE TABLE dim_category (
    category_key INT IDENTITY(1,1) PRIMARY KEY,
    category_name VARCHAR(100) UNIQUE
);



/* =========================================================
   DIMENSION TABLE 2 — PRODUCT
========================================================= */

CREATE TABLE dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_id VARCHAR(50),
    description VARCHAR(255),
    category_key INT,

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_key)
        REFERENCES dim_category(category_key)
);



/* =========================================================
   DIMENSION TABLE 3 — CUSTOMER
========================================================= */

CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_id VARCHAR(50) NULL,
    country VARCHAR(100)
);



/* =========================================================
   DIMENSION TABLE 4 — VENDOR
========================================================= */

CREATE TABLE dim_vendor (
    vendor_key INT IDENTITY(1,1) PRIMARY KEY,
    vendor_name VARCHAR(150),
    fill_rate DECIMAL(10,2)
);



/* =========================================================
   DIMENSION TABLE 5 — CHANNEL
========================================================= */

CREATE TABLE dim_channel (
    channel_key INT IDENTITY(1,1) PRIMARY KEY,
    channel_name VARCHAR(50)
);



/* =========================================================
   DIMENSION TABLE 6 — DATE
========================================================= */

CREATE TABLE dim_date (
    date_key INT IDENTITY(1,1) PRIMARY KEY,
    invoice_date DATE,
    year INT,
    month INT,
    week INT,
    quarter INT
);



/* =========================================================
   FACT TABLE — SALES
========================================================= */

CREATE TABLE fact_sales (
    sales_key BIGINT IDENTITY(1,1) PRIMARY KEY,

    invoice_id VARCHAR(50) NULL,

    product_key INT,
    customer_key INT,
    vendor_key INT,
    channel_key INT,
    date_key INT,

    quantity INT,

    unit_price DECIMAL(18,2),
    sales DECIMAL(18,2),
    cost DECIMAL(18,2),
    profit DECIMAL(18,2),
    margin_pct DECIMAL(18,2),

    promo_flag VARCHAR(50),
    order_value DECIMAL(18,2),
    items_per_order INT,
    category_contribution DECIMAL(18,2) NULL,

    CONSTRAINT fk_fact_product
        FOREIGN KEY (product_key)
        REFERENCES dim_product(product_key),

    CONSTRAINT fk_fact_customer
        FOREIGN KEY (customer_key)
        REFERENCES dim_customer(customer_key),

    CONSTRAINT fk_fact_vendor
        FOREIGN KEY (vendor_key)
        REFERENCES dim_vendor(vendor_key),

    CONSTRAINT fk_fact_channel
        FOREIGN KEY (channel_key)
        REFERENCES dim_channel(channel_key),

    CONSTRAINT fk_fact_date
        FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key)
);