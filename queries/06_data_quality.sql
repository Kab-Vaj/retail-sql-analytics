-- =====================================================================
-- 06  Data quality checks: the queries an analyst runs before trusting data
-- =====================================================================
SET search_path TO retail;

-- 6.1  Row counts for every table
SELECT 'customers'   AS table_name, COUNT(*) AS row_count FROM customers   UNION ALL
SELECT 'products',                  COUNT(*)              FROM products    UNION ALL
SELECT 'product_price_history',     COUNT(*)              FROM product_price_history UNION ALL
SELECT 'orders',                    COUNT(*)              FROM orders      UNION ALL
SELECT 'order_items',               COUNT(*)              FROM order_items UNION ALL
SELECT 'returns',                   COUNT(*)              FROM returns     UNION ALL
SELECT 'employees',                 COUNT(*)              FROM employees;

-- 6.2  Missing values in customer profiles
SELECT COUNT(*)                                   AS total_customers,
       COUNT(*) FILTER (WHERE city  IS NULL)      AS missing_city,
       COUNT(*) FILTER (WHERE state IS NULL)      AS missing_state,
       ROUND(100.0 * COUNT(*) FILTER (WHERE city IS NULL) / COUNT(*), 1) AS pct_missing_city
FROM customers;

-- 6.3  Duplicate customers: same email ignoring letter case
--      (the UNIQUE constraint is case-sensitive, so these slipped through)
SELECT LOWER(email)              AS normalized_email,
       COUNT(*)                  AS accounts,
       STRING_AGG(customer_id::TEXT, ', ' ORDER BY customer_id) AS customer_ids
FROM customers
GROUP BY LOWER(email)
HAVING COUNT(*) > 1;

-- 6.4  Orders with no line items (should be zero)
SELECT o.order_id
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_item_id IS NULL;

-- 6.5  Business-rule check: returns dated before the order was placed (should be zero)
SELECT r.return_id, o.order_date, r.return_date
FROM returns r
JOIN order_items oi ON oi.order_item_id = r.order_item_id
JOIN orders o       ON o.order_id = oi.order_id
WHERE r.return_date < o.order_date;

-- 6.6  Business-rule check: returns on cancelled orders (should be zero)
SELECT r.return_id, o.order_id, o.status
FROM returns r
JOIN order_items oi ON oi.order_item_id = r.order_item_id
JOIN orders o       ON o.order_id = oi.order_id
WHERE o.status = 'cancelled';

-- 6.7  Price-history integrity: overlapping effective-date ranges (should be zero)
SELECT a.product_id, a.effective_from, a.effective_to, b.effective_from AS overlaps_from
FROM product_price_history a
JOIN product_price_history b
  ON a.product_id = b.product_id
 AND a.effective_from < b.effective_from
 AND COALESCE(a.effective_to, DATE '9999-12-31') >= b.effective_from;

-- 6.8  Refunds that exceed what was charged for the line (should be zero)
SELECT r.return_id, r.refund_amount,
       ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct), 2) AS line_amount
FROM returns r
JOIN order_items oi ON oi.order_item_id = r.order_item_id
WHERE r.refund_amount > ROUND(oi.quantity * oi.unit_price * (1 - oi.discount_pct), 2);
