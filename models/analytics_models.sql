-- =====================================================================
-- Analytics layer: business-ready models built on the raw retail tables
-- =====================================================================
-- Layering, the same pattern used in dbt projects:
--   retail.*                 raw source tables (as the app writes them)
--   analytics.stg_*          staging: one per source table, renamed,
--                            typed, cleaned, no business logic
--   analytics.fct_* / dim_*  business-ready tables that analysts and
--                            dashboards query directly
--
-- Each model states its grain (what one row means) so it is clear how
-- to join and aggregate it safely.
-- =====================================================================

DROP SCHEMA IF EXISTS analytics CASCADE;
CREATE SCHEMA analytics;
SET search_path TO analytics, retail;

-- ---------------------------------------------------------------------
-- STAGING
-- ---------------------------------------------------------------------

-- Grain: one row per customer account.
-- Cleans emails, labels missing locations, and flags duplicate accounts
-- (same email with different letter case), pointing each one to the
-- original (earliest) account.
CREATE VIEW stg_customers AS
WITH base AS (
    SELECT customer_id,
           INITCAP(first_name)                    AS first_name,
           INITCAP(last_name)                     AS last_name,
           LOWER(TRIM(email))                     AS email,
           COALESCE(city,  'Unknown')             AS city,
           COALESCE(state, '??')                  AS state,
           signup_date,
           acquisition_channel,
           updated_at
    FROM retail.customers
)
SELECT base.*,
       MIN(customer_id) OVER (PARTITION BY email) AS canonical_customer_id,
       customer_id <> MIN(customer_id) OVER (PARTITION BY email) AS is_duplicate_account
FROM base;

-- Grain: one row per order. Adds a revenue-eligibility flag in one place.
CREATE VIEW stg_orders AS
SELECT order_id,
       customer_id,
       order_date,
       status,
       sales_channel,
       COALESCE(promo_code, 'NONE')   AS promo_code,
       shipping_fee,
       status <> 'cancelled'          AS is_revenue_eligible,
       updated_at
FROM retail.orders;

-- Grain: one row per order line, with money columns computed once.
CREATE VIEW stg_order_items AS
SELECT oi.order_item_id,
       oi.order_id,
       oi.product_id,
       oi.quantity,
       oi.unit_price                                       AS list_unit_price,
       oi.discount_pct,
       ROUND(oi.quantity * oi.unit_price, 2)               AS gross_amount,
       ROUND(oi.quantity * oi.unit_price * oi.discount_pct, 2) AS discount_amount,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct), 2) AS net_amount
FROM retail.order_items oi;

-- ---------------------------------------------------------------------
-- DIMENSIONS
-- ---------------------------------------------------------------------

-- Grain: one row per product (current state).
CREATE VIEW dim_products AS
SELECT p.product_id,
       p.product_name,
       c.category_name,
       p.unit_price                                      AS current_price,
       p.unit_cost,
       ROUND((p.unit_price - p.unit_cost) / p.unit_price, 4) AS current_margin_pct,
       CASE WHEN p.unit_price < 40 THEN 'Budget'
            WHEN p.unit_price < 100 THEN 'Mid-range'
            ELSE 'Premium' END                           AS price_tier,
       p.launch_date,
       p.is_active
FROM retail.products p
JOIN retail.categories c ON c.category_id = p.category_id;

-- Grain: one row per real person (duplicate accounts merged).
-- Lifetime metrics are pre-computed so dashboards do not re-derive them.
CREATE VIEW dim_customers AS
WITH orders_by_person AS (
    SELECT sc.canonical_customer_id                 AS customer_id,
           o.order_id, o.order_date, o.is_revenue_eligible
    FROM stg_customers sc
    JOIN stg_orders o ON o.customer_id = sc.customer_id
),
order_value AS (
    SELECT order_id, SUM(net_amount) AS net_amount
    FROM stg_order_items GROUP BY order_id
),
lifetime AS (
    SELECT obp.customer_id,
           MIN(obp.order_date)          AS first_order_date,
           MAX(obp.order_date)          AS last_order_date,
           COUNT(*)                     AS lifetime_orders,
           SUM(ov.net_amount)           AS lifetime_revenue
    FROM orders_by_person obp
    JOIN order_value ov ON ov.order_id = obp.order_id
    WHERE obp.is_revenue_eligible
    GROUP BY obp.customer_id
)
SELECT sc.customer_id,
       sc.first_name, sc.last_name, sc.email, sc.city, sc.state,
       sc.signup_date,
       sc.acquisition_channel,
       l.first_order_date,
       l.last_order_date,
       COALESCE(l.lifetime_orders, 0)        AS lifetime_orders,
       COALESCE(l.lifetime_revenue, 0)       AS lifetime_revenue,
       CASE WHEN l.lifetime_orders IS NULL THEN 'never ordered'
            WHEN l.lifetime_orders = 1     THEN 'one-time buyer'
            ELSE 'repeat buyer' END          AS buyer_type
FROM stg_customers sc
LEFT JOIN lifetime l ON l.customer_id = sc.customer_id
WHERE NOT sc.is_duplicate_account;

-- ---------------------------------------------------------------------
-- FACTS
-- ---------------------------------------------------------------------

-- Grain: one row per order line (revenue-eligible orders only).
-- The single source of truth for revenue, profit and returns.
CREATE VIEW fct_order_lines AS
SELECT oi.order_item_id,
       oi.order_id,
       sc.canonical_customer_id                         AS customer_id,
       oi.product_id,
       o.order_date,
       o.sales_channel,
       o.promo_code,
       oi.quantity,
       oi.gross_amount,
       oi.discount_amount,
       oi.net_amount                                    AS net_revenue,
       ROUND(oi.net_amount - oi.quantity * p.unit_cost, 2) AS gross_profit,
       r.return_id IS NOT NULL                          AS is_returned,
       COALESCE(r.refund_amount, 0)                     AS refund_amount
FROM stg_order_items oi
JOIN stg_orders o       ON o.order_id = oi.order_id
JOIN stg_customers sc   ON sc.customer_id = o.customer_id
JOIN retail.products p  ON p.product_id = oi.product_id
LEFT JOIN retail.returns r ON r.order_item_id = oi.order_item_id
WHERE o.is_revenue_eligible;

-- Grain: one row per calendar month. The table a finance dashboard reads.
CREATE VIEW fct_monthly_revenue AS
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_date)::DATE AS month,
           COUNT(DISTINCT order_id)              AS orders,
           COUNT(DISTINCT customer_id)           AS active_customers,
           SUM(net_revenue)                      AS net_revenue,
           SUM(gross_profit)                     AS gross_profit,
           SUM(refund_amount)                    AS refunds
    FROM fct_order_lines
    GROUP BY 1
)
SELECT month,
       orders,
       active_customers,
       net_revenue,
       gross_profit,
       refunds,
       ROUND(net_revenue / orders, 2)                                   AS avg_order_value,
       ROUND(100 * (net_revenue / LAG(net_revenue, 12) OVER (ORDER BY month) - 1), 1) AS yoy_growth_pct
FROM monthly;
