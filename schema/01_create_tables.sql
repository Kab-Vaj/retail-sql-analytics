-- =====================================================================
-- Northbrook Outfitters: online retail database schema (PostgreSQL)
-- A fictional outdoor and home goods e-commerce store, 2024 to 2025.
--
-- This is a normalized OLTP (transactional) design: the store's "source
-- system". The companion data warehouse project extracts from it and
-- models it into a star schema. The updated_at columns support
-- incremental loads, and product_price_history supports a
-- slowly changing product dimension.
-- =====================================================================

DROP SCHEMA IF EXISTS retail CASCADE;
CREATE SCHEMA retail;
SET search_path TO retail;

-- Make new connections find tables without a schema prefix, so a single
-- highlighted query runs on its own in any SQL editor.
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path TO retail, analytics, public',
                   current_database());
END $$;

-- Staff, with a self-referencing manager hierarchy
CREATE TABLE employees (
    employee_id   INT PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    title         VARCHAR(80)  NOT NULL,
    department    VARCHAR(50)  NOT NULL,
    manager_id    INT REFERENCES employees(employee_id),
    hire_date     DATE         NOT NULL
);

CREATE TABLE customers (
    customer_id         INT PRIMARY KEY,
    first_name          VARCHAR(50)  NOT NULL,
    last_name           VARCHAR(50)  NOT NULL,
    email               VARCHAR(120) NOT NULL UNIQUE,
    city                VARCHAR(60),             -- nullable: some sign-ups skip address
    state               CHAR(2),
    signup_date         DATE         NOT NULL,
    acquisition_channel VARCHAR(20)  NOT NULL
        CHECK (acquisition_channel IN ('organic_search','paid_social','email','referral','affiliate')),
    updated_at          TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE categories (
    category_id   INT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(100)  NOT NULL,
    category_id   INT           NOT NULL REFERENCES categories(category_id),
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    unit_cost     NUMERIC(10,2) NOT NULL CHECK (unit_cost > 0),
    launch_date   DATE          NOT NULL,
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    updated_at    TIMESTAMP     NOT NULL DEFAULT now()
);

-- Every list-price change, so history can be reconstructed
CREATE TABLE product_price_history (
    product_id     INT           NOT NULL REFERENCES products(product_id),
    unit_price     NUMERIC(10,2) NOT NULL,
    effective_from DATE          NOT NULL,
    effective_to   DATE,                         -- NULL = current price
    PRIMARY KEY (product_id, effective_from)
);

CREATE TABLE orders (
    order_id      INT PRIMARY KEY,
    customer_id   INT          NOT NULL REFERENCES customers(customer_id),
    order_date    DATE         NOT NULL,
    status        VARCHAR(20)  NOT NULL
        CHECK (status IN ('delivered','shipped','cancelled')),
    sales_channel VARCHAR(10)  NOT NULL CHECK (sales_channel IN ('web','mobile_app')),
    promo_code    VARCHAR(20),                     -- NULL when no promo was used
    shipping_fee  NUMERIC(8,2) NOT NULL DEFAULT 0,
    updated_at    TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id      INT           NOT NULL REFERENCES orders(order_id),
    product_id    INT           NOT NULL REFERENCES products(product_id),
    quantity      INT           NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL,          -- price at time of sale
    discount_pct  NUMERIC(4,2)  NOT NULL DEFAULT 0 CHECK (discount_pct BETWEEN 0 AND 0.9)
);

CREATE TABLE returns (
    return_id     INT PRIMARY KEY,
    order_item_id INT           NOT NULL UNIQUE REFERENCES order_items(order_item_id),
    return_date   DATE          NOT NULL,
    reason        VARCHAR(40)   NOT NULL,
    refund_amount NUMERIC(10,2) NOT NULL,
    processed_by  INT           REFERENCES employees(employee_id)
);

-- Indexes that support the most common query paths
CREATE INDEX idx_orders_customer    ON orders(customer_id);
CREATE INDEX idx_orders_date        ON orders(order_date);
CREATE INDEX idx_items_order        ON order_items(order_id);
CREATE INDEX idx_items_product      ON order_items(product_id);
CREATE INDEX idx_products_category  ON products(category_id);
