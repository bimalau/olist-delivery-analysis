-- Olist Delivery Performance Analysis (portfolio case study)
-- Author: Bimal K Augustine | Tool: SQLite (DB Browser for SQLite) | Written: October 2026
-- Data: Olist Brazilian E-Commerce Public Dataset (Kaggle), CC BY-NC-SA 4.0, educational use
-- Tables are the original Olist CSVs imported as-is, named after the files.
-- FILE 3 of 4: 03_analysis.sql
-- PURPOSE: the business questions. Reads from v_delivery (run 01_views.sql first).

-- Q1: Which states have the worst late rate? (states with 100+ orders only)
-- Expected: AL 397 (23.9), MA 717 (19.7), PI 476 (16.0), CE 1279 (15.3), SE 335 (15.2)
SELECT customer_state, COUNT(*) AS orders,
       ROUND(100.0*AVG(is_late),1) AS late_pct
FROM v_delivery
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC
LIMIT 5;

-- Q2: Late rate for the Jan 2017 to Aug 2018 window
-- Expected: 96203 | 7822 | 8.13
SELECT COUNT(*) AS orders, SUM(is_late) AS late,
       ROUND(100.0*AVG(is_late),2) AS late_pct
FROM v_delivery
WHERE order_month BETWEEN '2017-01' AND '2018-08';

-- Q3: Do late orders get worse reviews? (reviewed orders only)
-- Expected: On time 88163 | 4.29 | 9.2   Late 7661 | 2.57 | 54.1
SELECT CASE WHEN is_late = 1 THEN 'Late' ELSE 'On time' END AS status,
       COUNT(review_score) AS reviewed_orders,
       ROUND(AVG(review_score),2) AS avg_score,
       ROUND(100.0*SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)/COUNT(review_score),1) AS pct_1_2_star
FROM v_delivery
GROUP BY is_late;

-- Q4: Sellers with 30+ delivered orders: how many, and their combined late rate
-- Expected: 621 | 80383 | 8.08
SELECT COUNT(*) AS sellers, SUM(n) AS orders,
       ROUND(100.0*SUM(late)/SUM(n),2) AS late_pct
FROM (SELECT i.seller_id, COUNT(*) AS n, SUM(d.is_late) AS late
      FROM v_delivery d
      JOIN olist_order_items_dataset i
        ON i.order_id = d.order_id AND i.order_item_id = 1
      GROUP BY i.seller_id
      HAVING COUNT(*) >= 30);

-- Q5: Worst sellers by late rate (30+ orders)
-- Expected: top row ede0c03645598cdfc63ca8237acbe73d | 43 | 34.9
SELECT i.seller_id, COUNT(*) AS orders,
       ROUND(100.0*AVG(d.is_late),1) AS late_pct
FROM v_delivery d
JOIN olist_order_items_dataset i
  ON i.order_id = d.order_id AND i.order_item_id = 1
GROUP BY i.seller_id
HAVING COUNT(*) >= 30
ORDER BY late_pct DESC
LIMIT 5;

-- Q6: Top categories by revenue (canceled and unavailable orders excluded)
-- English name first, then the Portuguese name, then Unknown.
-- Expected: health_beauty 1255695.13, watches_gifts 1198185.21, bed_bath_table 1035964.06,
--           sports_leisure 979740.92, computers_accessories 904322.02
SELECT COALESCE(NULLIF(t.product_category_name_english,''),
                NULLIF(p.product_category_name,''), 'Unknown') AS category,
       COUNT(*) AS items, ROUND(SUM(i.price),2) AS revenue
FROM olist_order_items_dataset i
JOIN olist_orders_dataset o ON o.order_id = i.order_id
LEFT JOIN olist_products_dataset p ON p.product_id = i.product_id
LEFT JOIN product_category_name_translation t
       ON t.product_category_name = p.product_category_name
WHERE o.order_status NOT IN ('canceled','unavailable')
GROUP BY category
ORDER BY revenue DESC
LIMIT 5;
