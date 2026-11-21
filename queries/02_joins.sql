-- =====================================================================
-- 02  Joins: inner, left, anti-join, self-join, multi-table
-- =====================================================================
SET search_path TO retail;

-- 2.1  INNER JOIN: each order line with its product and category
SELECT o.order_id,
       o.order_date,
       p.product_name,
       c.category_name,
       oi.quantity,
       oi.unit_price
FROM orders o
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products    p  ON p.product_id  = oi.product_id
JOIN categories  c  ON c.category_id = p.category_id
ORDER BY o.order_date DESC, o.order_id
LIMIT 20;

-- 2.2  LEFT JOIN: every customer with their order count, including zero
SELECT cu.customer_id,
       cu.first_name || ' ' || cu.last_name AS customer_name,
       COUNT(o.order_id)                    AS order_count
FROM customers cu
LEFT JOIN orders o ON o.customer_id = cu.customer_id
GROUP BY cu.customer_id, customer_name
ORDER BY order_count DESC
LIMIT 15;

-- 2.3  Anti-join: customers who signed up but never ordered
--      (a re-engagement email list for marketing)
SELECT cu.customer_id, cu.email, cu.signup_date, cu.acquisition_channel
FROM customers cu
LEFT JOIN orders o ON o.customer_id = cu.customer_id
WHERE o.order_id IS NULL
ORDER BY cu.signup_date;

-- 2.4  Anti-join with NOT EXISTS: products that have never sold
SELECT p.product_id, p.product_name, p.launch_date, p.is_active
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- 2.5  SELF-JOIN: each employee next to their manager
SELECT e.first_name || ' ' || e.last_name AS employee,
       e.title,
       COALESCE(m.first_name || ' ' || m.last_name, '(top of org)') AS manager
FROM employees e
LEFT JOIN employees m ON m.employee_id = e.manager_id
ORDER BY e.manager_id NULLS FIRST, e.employee_id;

-- 2.6  Five-table join: returned items with who processed the refund
SELECT r.return_id,
       r.return_date,
       cu.email,
       p.product_name,
       r.reason,
       r.refund_amount,
       COALESCE(e.first_name || ' ' || e.last_name, 'Unassigned') AS processed_by
FROM returns r
JOIN order_items oi ON oi.order_item_id = r.order_item_id
JOIN orders      o  ON o.order_id       = oi.order_id
JOIN customers   cu ON cu.customer_id   = o.customer_id
JOIN products    p  ON p.product_id     = oi.product_id
LEFT JOIN employees e ON e.employee_id  = r.processed_by
ORDER BY r.return_date DESC
LIMIT 20;

-- 2.7  Range join: the list price that was in effect on each order date
--      (checks that order_items.unit_price matches price history)
SELECT oi.order_item_id,
       o.order_date,
       oi.product_id,
       oi.unit_price      AS price_charged,
       ph.unit_price      AS list_price_at_time,
       ph.effective_from,
       ph.effective_to
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN product_price_history ph
  ON ph.product_id = oi.product_id
 AND o.order_date >= ph.effective_from
 AND o.order_date <= COALESCE(ph.effective_to, DATE '9999-12-31')
WHERE oi.product_id IN (SELECT product_id FROM product_price_history WHERE effective_to IS NOT NULL)
ORDER BY oi.product_id, o.order_date
LIMIT 20;
