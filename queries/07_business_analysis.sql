-- =====================================================================
-- 07  Business analysis: seven questions leadership would actually ask
-- =====================================================================
-- Every question uses one shared definition of revenue (net of line
-- discounts, excluding cancelled orders), built in a reusable view.
SET search_path TO retail;

CREATE OR REPLACE VIEW order_lines AS
SELECT o.order_id,
       o.customer_id,
       o.order_date,
       o.sales_channel,
       o.promo_code,
       oi.order_item_id,
       oi.product_id,
       c.category_name,
       oi.quantity,
       oi.quantity * oi.unit_price * (1 - oi.discount_pct)                 AS net_revenue,
       oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost) AS gross_profit,
       COALESCE(r.refund_amount, 0)                                         AS refund_amount,
       (r.return_id IS NOT NULL)                                            AS was_returned
FROM orders o
JOIN order_items oi ON oi.order_id    = o.order_id
JOIN products    p  ON p.product_id   = oi.product_id
JOIN categories  c  ON c.category_id  = p.category_id
LEFT JOIN returns r ON r.order_item_id = oi.order_item_id
WHERE o.status <> 'cancelled';


-- ---------------------------------------------------------------------
-- Q1. How fast are we growing, and how dependent are we on the holidays?
-- ---------------------------------------------------------------------
WITH yearly AS (
    SELECT EXTRACT(YEAR FROM order_date)::INT AS yr,
           SUM(net_revenue)                                                     AS revenue,
           SUM(net_revenue) FILTER (WHERE EXTRACT(MONTH FROM order_date) IN (11, 12)) AS nov_dec_revenue,
           COUNT(DISTINCT order_id)                                             AS orders,
           COUNT(DISTINCT customer_id)                                          AS active_customers
    FROM order_lines
    GROUP BY 1
)
SELECT yr,
       ROUND(revenue)                                             AS revenue,
       ROUND(100 * (revenue / LAG(revenue) OVER (ORDER BY yr) - 1), 1) AS yoy_growth_pct,
       orders,
       active_customers,
       ROUND(100 * nov_dec_revenue / revenue, 1)                  AS nov_dec_share_pct
FROM yearly
ORDER BY yr;


-- ---------------------------------------------------------------------
-- Q2. Which categories make us money once returns are taken out?
-- ---------------------------------------------------------------------
SELECT category_name,
       ROUND(SUM(net_revenue))                                         AS net_revenue,
       ROUND(100.0 * AVG(was_returned::INT), 1)                        AS return_rate_pct,
       ROUND(SUM(refund_amount))                                       AS refunds,
       ROUND(SUM(gross_profit) - SUM(refund_amount * (gross_profit / NULLIF(net_revenue, 0)))) AS profit_after_returns,
       ROUND(100 * (SUM(gross_profit) - SUM(refund_amount * (gross_profit / NULLIF(net_revenue, 0))))
                 / SUM(net_revenue - refund_amount), 1)                AS margin_after_returns_pct
FROM order_lines
GROUP BY category_name
ORDER BY profit_after_returns DESC;
-- Note: a returned line loses its profit, so the refunded share of the line's
-- profit is removed. (Simplification: returned goods are restocked and resold.)


-- ---------------------------------------------------------------------
-- Q3. Are our promo codes worth it?
-- ---------------------------------------------------------------------
WITH by_order AS (
    SELECT order_id,
           COALESCE(promo_code, '(none)') AS promo_code,
           SUM(net_revenue)   AS revenue,
           SUM(gross_profit)  AS profit,
           BOOL_OR(was_returned) AS any_return
    FROM order_lines
    GROUP BY order_id, COALESCE(promo_code, '(none)')
)
SELECT promo_code,
       COUNT(*)                                 AS orders,
       ROUND(AVG(revenue), 2)                   AS avg_order_value,
       ROUND(100 * SUM(profit) / SUM(revenue), 1) AS gross_margin_pct,
       ROUND(100.0 * AVG(any_return::INT), 1)   AS orders_with_return_pct
FROM by_order
GROUP BY promo_code
ORDER BY orders DESC;


-- ---------------------------------------------------------------------
-- Q4. Which acquisition channels bring the most valuable customers?
-- ---------------------------------------------------------------------
WITH customer_value AS (
    SELECT cu.customer_id,
           cu.acquisition_channel,
           COUNT(DISTINCT ol.order_id)               AS orders,
           COALESCE(SUM(ol.gross_profit - ol.refund_amount * (ol.gross_profit / NULLIF(ol.net_revenue, 0))), 0) AS lifetime_profit
    FROM customers cu
    LEFT JOIN order_lines ol ON ol.customer_id = cu.customer_id
    GROUP BY cu.customer_id, cu.acquisition_channel
)
SELECT acquisition_channel,
       COUNT(*)                                                      AS customers,
       ROUND(100.0 * AVG((orders > 0)::INT), 1)                      AS pct_ever_ordered,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders >= 2)
                   / NULLIF(COUNT(*) FILTER (WHERE orders >= 1), 0), 1) AS repeat_rate_pct,
       ROUND(AVG(orders) FILTER (WHERE orders > 0), 2)               AS avg_orders_per_buyer,
       ROUND(AVG(lifetime_profit), 2)                                AS avg_profit_per_customer
FROM customer_value
GROUP BY acquisition_channel
ORDER BY avg_profit_per_customer DESC;


-- ---------------------------------------------------------------------
-- Q5. Do customers come back? Monthly cohort retention for 2024 cohorts
-- ---------------------------------------------------------------------
-- A customer's cohort is the month of their first order. Retention at
-- month N = share of the cohort that placed any order N months later.
WITH first_order AS (
    SELECT customer_id, DATE_TRUNC('month', MIN(order_date))::DATE AS cohort_month
    FROM order_lines
    GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT ol.customer_id, fo.cohort_month,
           (EXTRACT(YEAR FROM AGE(DATE_TRUNC('month', ol.order_date), fo.cohort_month)) * 12
          + EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', ol.order_date), fo.cohort_month)))::INT AS month_number
    FROM order_lines ol
    JOIN first_order fo ON fo.customer_id = ol.customer_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS customers FROM first_order GROUP BY cohort_month
)
SELECT TO_CHAR(a.cohort_month, 'YYYY-MM') AS cohort,
       cs.customers                       AS cohort_size,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_number = 1)  / cs.customers, 1) AS m1_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_number = 3)  / cs.customers, 1) AS m3_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_number = 6)  / cs.customers, 1) AS m6_pct,
       ROUND(100.0 * COUNT(DISTINCT a.customer_id) FILTER (WHERE month_number = 12) / cs.customers, 1) AS m12_pct
FROM activity a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month
WHERE a.cohort_month BETWEEN '2024-01-01' AND '2024-12-01'
GROUP BY a.cohort_month, cs.customers
ORDER BY a.cohort_month;


-- ---------------------------------------------------------------------
-- Q6. Who are our best customers, and who is slipping away? (RFM segments)
-- ---------------------------------------------------------------------
-- Recency, Frequency and Monetary value each scored 1-5 with NTILE,
-- measured as of the end of the data (2025-12-31).
WITH rfm_base AS (
    SELECT customer_id,
           DATE '2025-12-31' - MAX(order_date) AS days_since_last_order,
           COUNT(DISTINCT order_id)            AS frequency,
           SUM(net_revenue)                    AS monetary
    FROM order_lines
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY days_since_last_order DESC) AS r_score,  -- recent = 5
           NTILE(5) OVER (ORDER BY frequency)                  AS f_score,
           NTILE(5) OVER (ORDER BY monetary)                   AS m_score
    FROM rfm_base
),
segmented AS (
    SELECT *,
           CASE
               WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '1 Champions'
               WHEN r_score >= 3 AND f_score >= 3                  THEN '2 Loyal'
               WHEN r_score >= 4 AND f_score <= 2                  THEN '3 New / promising'
               WHEN r_score <= 2 AND f_score >= 3                  THEN '4 At risk'
               WHEN r_score <= 2                                    THEN '5 Lapsed'
               ELSE                                                      '6 Needs attention'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                       AS customers,
       ROUND(AVG(days_since_last_order))              AS avg_days_since_order,
       ROUND(AVG(frequency), 1)                       AS avg_orders,
       ROUND(AVG(monetary), 2)                        AS avg_spend,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_revenue
FROM segmented
GROUP BY segment
ORDER BY segment;


-- ---------------------------------------------------------------------
-- Q7. Is the mobile app worth investing in?
-- ---------------------------------------------------------------------
SELECT TO_CHAR(DATE_TRUNC('quarter', order_date), 'YYYY-"Q"Q') AS quarter,
       ROUND(100.0 * COUNT(DISTINCT order_id) FILTER (WHERE sales_channel = 'mobile_app')
                   / COUNT(DISTINCT order_id), 1)                        AS mobile_order_share_pct,
       ROUND(SUM(net_revenue) FILTER (WHERE sales_channel = 'mobile_app')
             / NULLIF(COUNT(DISTINCT order_id) FILTER (WHERE sales_channel = 'mobile_app'), 0), 2) AS mobile_aov,
       ROUND(SUM(net_revenue) FILTER (WHERE sales_channel = 'web')
             / NULLIF(COUNT(DISTINCT order_id) FILTER (WHERE sales_channel = 'web'), 0), 2)        AS web_aov
FROM order_lines
GROUP BY DATE_TRUNC('quarter', order_date)
ORDER BY 1;
