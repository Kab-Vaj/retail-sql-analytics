-- =====================================================================
-- 04  Subqueries and CTEs: scalar, correlated, EXISTS, chained, recursive
-- =====================================================================
SET search_path TO retail;

-- 4.1  Scalar subquery: products priced above the catalog average
SELECT product_name, unit_price,
       ROUND((SELECT AVG(unit_price) FROM products), 2) AS catalog_avg
FROM products
WHERE unit_price > (SELECT AVG(unit_price) FROM products)
ORDER BY unit_price DESC;

-- 4.2  Correlated subquery: products priced above their own category's average
SELECT p.product_name, p.unit_price, c.category_name
FROM products p
JOIN categories c ON c.category_id = p.category_id
WHERE p.unit_price > (
    SELECT AVG(p2.unit_price)
    FROM products p2
    WHERE p2.category_id = p.category_id
)
ORDER BY c.category_name, p.unit_price DESC;

-- 4.3  EXISTS: customers who bought Footwear and also returned something
SELECT cu.customer_id, cu.email
FROM customers cu
WHERE EXISTS (
        SELECT 1
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        JOIN products p     ON p.product_id = oi.product_id
        JOIN categories c   ON c.category_id = p.category_id
        WHERE o.customer_id = cu.customer_id AND c.category_name = 'Footwear')
  AND EXISTS (
        SELECT 1
        FROM orders o
        JOIN order_items oi ON oi.order_id = o.order_id
        JOIN returns r      ON r.order_item_id = oi.order_item_id
        WHERE o.customer_id = cu.customer_id)
ORDER BY cu.customer_id
LIMIT 20;

-- 4.4  Derived table: average number of items per order, by sales channel
SELECT sales_channel,
       ROUND(AVG(items_in_order), 2) AS avg_items_per_order
FROM (
    SELECT o.order_id, o.sales_channel, SUM(oi.quantity) AS items_in_order
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.sales_channel
) per_order
GROUP BY sales_channel;

-- 4.5  Chained CTEs: build order totals once, then reuse them
--      Question: what share of revenue comes from first orders vs repeat orders?
WITH order_totals AS (
    SELECT o.order_id, o.customer_id, o.order_date,
           SUM(oi.quantity * oi.unit_price * (1 - oi.discount_pct)) AS order_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status <> 'cancelled'
    GROUP BY o.order_id, o.customer_id, o.order_date
),
first_orders AS (
    SELECT customer_id, MIN(order_date) AS first_order_date
    FROM order_totals
    GROUP BY customer_id
),
labeled AS (
    SELECT ot.*,
           CASE WHEN ot.order_date = fo.first_order_date THEN 'first order' ELSE 'repeat order' END AS order_type
    FROM order_totals ot
    JOIN first_orders fo ON fo.customer_id = ot.customer_id
)
SELECT order_type,
       COUNT(*)                     AS orders,
       ROUND(SUM(order_revenue), 2) AS revenue,
       ROUND(100.0 * SUM(order_revenue) / SUM(SUM(order_revenue)) OVER (), 1) AS pct_revenue
FROM labeled
GROUP BY order_type;

-- 4.6  RECURSIVE CTE: the full reporting chain for every employee
WITH RECURSIVE org_chart AS (
    SELECT employee_id, first_name || ' ' || last_name AS employee, title, manager_id,
           1 AS level,
           (first_name || ' ' || last_name)::TEXT AS reporting_path
    FROM employees
    WHERE manager_id IS NULL
    UNION ALL
    SELECT e.employee_id, e.first_name || ' ' || e.last_name, e.title, e.manager_id,
           oc.level + 1,
           oc.reporting_path || ' > ' || e.first_name || ' ' || e.last_name
    FROM employees e
    JOIN org_chart oc ON oc.employee_id = e.manager_id
)
SELECT level, REPEAT('    ', level - 1) || employee AS employee, title, reporting_path
FROM org_chart
ORDER BY reporting_path;

-- 4.7  RECURSIVE CTE to generate a calendar: months with zero orders still appear
WITH RECURSIVE months AS (
    SELECT DATE '2024-01-01' AS month_start
    UNION ALL
    SELECT (month_start + INTERVAL '1 month')::DATE FROM months
    WHERE month_start < DATE '2025-12-01'
)
SELECT TO_CHAR(m.month_start, 'YYYY-MM') AS month,
       COUNT(o.order_id) FILTER (WHERE o.promo_code = 'FLASH30') AS flash30_orders
FROM months m
LEFT JOIN orders o ON DATE_TRUNC('month', o.order_date) = m.month_start
GROUP BY m.month_start
ORDER BY m.month_start;
