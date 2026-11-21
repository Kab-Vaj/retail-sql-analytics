-- =====================================================================
-- Automated data tests (pass/fail), in the style of dbt tests
-- =====================================================================
-- Each test counts the rows that BREAK a rule. Zero = pass.
-- Run with: ./scripts/run_tests.sh   (exits non-zero if any test fails)
-- =====================================================================
SET search_path TO analytics, retail;

WITH tests AS (
    -- ---------- uniqueness: each model's grain is really unique ----------
    SELECT 'dim_customers: customer_id is unique' AS test_name,
           (SELECT COUNT(*) FROM (SELECT customer_id FROM dim_customers
                                  GROUP BY 1 HAVING COUNT(*) > 1) d) AS failures
    UNION ALL
    SELECT 'dim_customers: email is unique after merging duplicates',
           (SELECT COUNT(*) FROM (SELECT email FROM dim_customers
                                  GROUP BY 1 HAVING COUNT(*) > 1) d)
    UNION ALL
    SELECT 'fct_order_lines: order_item_id is unique',
           (SELECT COUNT(*) FROM (SELECT order_item_id FROM fct_order_lines
                                  GROUP BY 1 HAVING COUNT(*) > 1) d)
    UNION ALL
    SELECT 'fct_monthly_revenue: month is unique',
           (SELECT COUNT(*) FROM (SELECT month FROM fct_monthly_revenue
                                  GROUP BY 1 HAVING COUNT(*) > 1) d)

    -- ---------- not null on key columns ----------
    UNION ALL
    SELECT 'fct_order_lines: no null keys',
           (SELECT COUNT(*) FROM fct_order_lines
            WHERE order_id IS NULL OR customer_id IS NULL OR product_id IS NULL OR order_date IS NULL)

    -- ---------- relationships: every fact row joins to its dimensions ----------
    UNION ALL
    SELECT 'fct_order_lines: every customer_id exists in dim_customers',
           (SELECT COUNT(*) FROM fct_order_lines f
            LEFT JOIN dim_customers d ON d.customer_id = f.customer_id WHERE d.customer_id IS NULL)
    UNION ALL
    SELECT 'fct_order_lines: every product_id exists in dim_products',
           (SELECT COUNT(*) FROM fct_order_lines f
            LEFT JOIN dim_products d ON d.product_id = f.product_id WHERE d.product_id IS NULL)
    UNION ALL
    SELECT 'orders: every order has at least one line',
           (SELECT COUNT(*) FROM retail.orders o
            WHERE NOT EXISTS (SELECT 1 FROM retail.order_items oi WHERE oi.order_id = o.order_id))

    -- ---------- accepted values ----------
    UNION ALL
    SELECT 'stg_orders: promo_code is a known code',
           (SELECT COUNT(*) FROM stg_orders
            WHERE promo_code NOT IN ('NONE','WELCOME10','HOLIDAY20','FLASH30','FREESHIP'))

    -- ---------- business rules ----------
    UNION ALL
    SELECT 'returns: return date is on or after the order date',
           (SELECT COUNT(*) FROM retail.returns r
            JOIN retail.order_items oi ON oi.order_item_id = r.order_item_id
            JOIN retail.orders o ON o.order_id = oi.order_id
            WHERE r.return_date < o.order_date)
    UNION ALL
    SELECT 'returns: no returns on cancelled orders',
           (SELECT COUNT(*) FROM retail.returns r
            JOIN retail.order_items oi ON oi.order_item_id = r.order_item_id
            JOIN retail.orders o ON o.order_id = oi.order_id
            WHERE o.status = 'cancelled')
    UNION ALL
    SELECT 'fct_order_lines: refund never exceeds the amount charged',
           (SELECT COUNT(*) FROM fct_order_lines WHERE refund_amount > net_revenue)
    UNION ALL
    SELECT 'price history: no overlapping date ranges per product',
           (SELECT COUNT(*) FROM retail.product_price_history a
            JOIN retail.product_price_history b
              ON a.product_id = b.product_id AND a.effective_from < b.effective_from
             AND COALESCE(a.effective_to, DATE '9999-12-31') >= b.effective_from)
    UNION ALL
    SELECT 'order_items: price charged matches the list price in effect that day',
           (SELECT COUNT(*) FROM retail.order_items oi
            JOIN retail.orders o ON o.order_id = oi.order_id
            WHERE NOT EXISTS (
                SELECT 1 FROM retail.product_price_history ph
                WHERE ph.product_id = oi.product_id
                  AND o.order_date BETWEEN ph.effective_from AND COALESCE(ph.effective_to, DATE '9999-12-31')
                  AND ph.unit_price = oi.unit_price))

    -- ---------- reconciliation: models agree with the raw source ----------
    UNION ALL
    SELECT 'reconciliation: monthly revenue total equals order-line revenue total',
           (SELECT CASE WHEN ABS((SELECT SUM(net_revenue) FROM fct_monthly_revenue)
                               - (SELECT SUM(net_revenue) FROM fct_order_lines)) < 0.01 THEN 0 ELSE 1 END)
    UNION ALL
    SELECT 'reconciliation: fact rows equal raw lines on non-cancelled orders',
           (SELECT ABS((SELECT COUNT(*) FROM fct_order_lines)
                     - (SELECT COUNT(*) FROM retail.order_items oi
                        JOIN retail.orders o ON o.order_id = oi.order_id
                        WHERE o.status <> 'cancelled')))
)
SELECT CASE WHEN failures = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
       test_name,
       failures
FROM tests
ORDER BY result, test_name;
