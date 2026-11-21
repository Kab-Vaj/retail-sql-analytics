-- =====================================================================
-- 03  Aggregations: GROUP BY, HAVING, conditional aggregation, ROLLUP
-- =====================================================================
SET search_path TO retail;

-- Net revenue for an order line = quantity * price * (1 - discount).
-- Cancelled orders are excluded from revenue throughout.

-- 3.1  Revenue, orders and average order value by year
SELECT EXTRACT(YEAR FROM o.order_date)                         AS order_year,
       COUNT(DISTINCT o.order_id)                              AS orders,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS net_revenue,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct))
             / COUNT(DISTINCT o.order_id), 2)                  AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY order_year
ORDER BY order_year;

-- 3.2  Revenue and gross profit by category
SELECT c.category_name,
       SUM(oi.quantity)                                                     AS units_sold,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2)    AS net_revenue,
       ROUND(SUM(oi.quantity * (oi.unit_price * (1 - oi.discount_pct) - p.unit_cost)), 2) AS gross_profit
FROM order_items oi
JOIN orders     o ON o.order_id    = oi.order_id
JOIN products   p ON p.product_id  = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.status <> 'cancelled'
GROUP BY c.category_name
ORDER BY net_revenue DESC;

-- 3.3  HAVING: customers who have spent more than $1,000 in total
SELECT o.customer_id,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS lifetime_spend
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status <> 'cancelled'
GROUP BY o.customer_id
HAVING SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) > 1000
ORDER BY lifetime_spend DESC;

-- 3.4  Conditional aggregation with FILTER: order mix per sales channel by year
SELECT EXTRACT(YEAR FROM order_date) AS order_year,
       COUNT(*)                                              AS total_orders,
       COUNT(*) FILTER (WHERE sales_channel = 'mobile_app')  AS mobile_orders,
       COUNT(*) FILTER (WHERE sales_channel = 'web')         AS web_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE sales_channel = 'mobile_app') / COUNT(*), 1) AS mobile_pct
FROM orders
GROUP BY order_year
ORDER BY order_year;

-- 3.5  Same idea with CASE (portable to databases without FILTER):
--      order status breakdown per month in 2025
SELECT TO_CHAR(order_date, 'YYYY-MM')                     AS month,
       SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
       SUM(CASE WHEN status = 'shipped'   THEN 1 ELSE 0 END) AS shipped,
       SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled
FROM orders
WHERE order_date >= '2025-01-01'
GROUP BY month
ORDER BY month;

-- 3.6  ROLLUP: revenue by category and year, with subtotals and a grand total
SELECT COALESCE(c.category_name, 'ALL CATEGORIES')         AS category,
       COALESCE(EXTRACT(YEAR FROM o.order_date)::TEXT, 'ALL YEARS') AS order_year,
       ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)), 2) AS net_revenue
FROM order_items oi
JOIN orders     o ON o.order_id    = oi.order_id
JOIN products   p ON p.product_id  = oi.product_id
JOIN categories c ON c.category_id = p.category_id
WHERE o.status <> 'cancelled'
GROUP BY ROLLUP (c.category_name, EXTRACT(YEAR FROM o.order_date))
ORDER BY c.category_name NULLS LAST, EXTRACT(YEAR FROM o.order_date) NULLS LAST;

-- 3.7  Return reasons ranked, with the share of all returns
SELECT reason,
       COUNT(*) AS returns,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_returns,
       ROUND(SUM(refund_amount), 2) AS refunded
FROM returns
GROUP BY reason
ORDER BY returns DESC;
