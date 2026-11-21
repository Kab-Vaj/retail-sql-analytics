-- =====================================================================
-- 05  Window functions: ranking, running totals, LAG/LEAD, moving averages
-- =====================================================================
SET search_path TO retail;

-- 5.1  RANK vs DENSE_RANK vs ROW_NUMBER: top 3 products by revenue in each category
WITH product_revenue AS (
    SELECT c.category_name, p.product_name,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM order_items oi
    JOIN orders     o ON o.order_id    = oi.order_id
    JOIN products   p ON p.product_id  = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    WHERE o.status <> 'cancelled'
    GROUP BY c.category_name, p.product_name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS row_num,
           RANK()       OVER (PARTITION BY category_name ORDER BY revenue DESC) AS rnk,
           DENSE_RANK() OVER (PARTITION BY category_name ORDER BY revenue DESC) AS dense_rnk
    FROM product_revenue
)
SELECT category_name, product_name, ROUND(revenue, 2) AS revenue, row_num, rnk, dense_rnk
FROM ranked
WHERE row_num <= 3
ORDER BY category_name, row_num;

-- 5.2  Running total of revenue through 2025, plus each month's share of the year
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::DATE AS month,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled' AND o.order_date >= '2025-01-01'
    GROUP BY 1
)
SELECT TO_CHAR(month, 'YYYY-MM') AS month,
       ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total,
       ROUND(100 * revenue / SUM(revenue) OVER (), 1) AS pct_of_year
FROM monthly
ORDER BY month;

-- 5.3  LAG: month-over-month and year-over-year revenue growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_date)::DATE AS month,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY 1
)
SELECT TO_CHAR(month, 'YYYY-MM') AS month,
       ROUND(revenue, 0) AS revenue,
       ROUND(100 * (revenue / LAG(revenue)     OVER (ORDER BY month) - 1), 1) AS mom_growth_pct,
       ROUND(100 * (revenue / LAG(revenue, 12) OVER (ORDER BY month) - 1), 1) AS yoy_growth_pct
FROM monthly
ORDER BY month;

-- 5.4  Moving average: 7-day rolling average of daily orders in Q4 2025
WITH daily AS (
    SELECT order_date, COUNT(*) AS orders
    FROM orders
    WHERE order_date BETWEEN '2025-10-01' AND '2025-12-31'
    GROUP BY order_date
)
SELECT order_date, orders,
       ROUND(AVG(orders) OVER (ORDER BY order_date
                               ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS rolling_7day_avg
FROM daily
ORDER BY order_date;

-- 5.5  LEAD: days between a customer's consecutive orders (purchase cadence)
WITH gaps AS (
    SELECT customer_id, order_date,
           LEAD(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) - order_date AS days_to_next_order
    FROM orders
    WHERE status <> 'cancelled'
)
SELECT ROUND(AVG(days_to_next_order), 1)                                   AS avg_days_between_orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_next_order)     AS median_days_between_orders
FROM gaps
WHERE days_to_next_order IS NOT NULL;

-- 5.6  NTILE: split customers into spending quartiles and compare them
WITH spend AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS total_spend
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.customer_id
),
quartiles AS (
    SELECT *, NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile
    FROM spend
)
SELECT spend_quartile,
       COUNT(*)                   AS customers,
       ROUND(MIN(total_spend), 2) AS min_spend,
       ROUND(MAX(total_spend), 2) AS max_spend,
       ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1) AS pct_of_revenue
FROM quartiles
GROUP BY spend_quartile
ORDER BY spend_quartile;

-- 5.7  FIRST_VALUE: the first product category each customer ever bought
WITH lines AS (
    SELECT o.customer_id, o.order_date, oi.order_item_id, c.category_name
    FROM orders o
    JOIN order_items oi ON oi.order_id   = o.order_id
    JOIN products    p  ON p.product_id  = oi.product_id
    JOIN categories  c  ON c.category_id = p.category_id
),
firsts AS (
    SELECT DISTINCT customer_id,
           FIRST_VALUE(category_name) OVER (PARTITION BY customer_id
                                            ORDER BY order_date, order_item_id) AS entry_category
    FROM lines
)
SELECT entry_category, COUNT(*) AS customers
FROM firsts
GROUP BY entry_category
ORDER BY customers DESC;

-- 5.8  Deduplicate with ROW_NUMBER: keep only the latest order per customer
SELECT customer_id, order_id, order_date, status
FROM (
    SELECT o.*,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC, order_id DESC) AS rn
    FROM orders o
) t
WHERE rn = 1
ORDER BY order_date DESC
LIMIT 15;
