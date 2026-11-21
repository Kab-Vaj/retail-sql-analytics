-- =====================================================================
-- 01  SQL fundamentals: filtering, sorting, expressions, NULL handling
-- =====================================================================
SET search_path TO retail;

-- 1.1  The 10 most expensive active products
SELECT product_name, unit_price
FROM products
WHERE is_active
ORDER BY unit_price DESC
LIMIT 10;

-- 1.2  Gross margin per product as a percentage (calculated column)
SELECT product_name,
       unit_price,
       unit_cost,
       ROUND((unit_price - unit_cost) / unit_price * 100, 1) AS margin_pct
FROM products
ORDER BY margin_pct DESC
LIMIT 10;

-- 1.3  Customers in Illinois or Texas who signed up in 2025 (IN + BETWEEN)
SELECT customer_id, first_name, last_name, city, state, signup_date
FROM customers
WHERE state IN ('IL', 'TX')
  AND signup_date BETWEEN '2025-01-01' AND '2025-12-31'
ORDER BY signup_date;

-- 1.4  Pattern matching: every boot or shoe in the catalog (case-insensitive)
SELECT product_name, unit_price
FROM products
WHERE product_name ILIKE '%boot%'
   OR product_name ILIKE '%shoe%';

-- 1.5  Which distinct promo codes have been used?
SELECT DISTINCT promo_code
FROM orders
WHERE promo_code IS NOT NULL
ORDER BY promo_code;

-- 1.6  NULL handling: show a readable location even when the address is missing
SELECT customer_id,
       first_name || ' ' || last_name           AS customer_name,
       COALESCE(city || ', ' || state, 'Unknown') AS location
FROM customers
WHERE city IS NULL
LIMIT 10;

-- 1.7  CASE: bucket products into price tiers
SELECT product_name,
       unit_price,
       CASE
           WHEN unit_price < 40  THEN 'Budget'
           WHEN unit_price < 100 THEN 'Mid-range'
           ELSE 'Premium'
       END AS price_tier
FROM products
ORDER BY unit_price;

-- 1.8  Date functions: orders placed on Black Friday 2025 (Nov 28)
SELECT order_id, customer_id, sales_channel, promo_code
FROM orders
WHERE order_date = DATE '2025-11-28';

-- 1.9  Employees hired in the last 3 years before 2026, with tenure in years
SELECT first_name, last_name, title, hire_date,
       DATE_PART('year', AGE(DATE '2026-01-01', hire_date)) AS years_of_tenure
FROM employees
WHERE hire_date >= DATE '2023-01-01'
ORDER BY hire_date;
