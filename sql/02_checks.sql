-- Olist Delivery Performance Analysis (portfolio case study)
-- Author: Bimal K Augustine | Tool: SQLite (DB Browser for SQLite) | Written: October 2026
-- Data: Olist Brazilian E-Commerce Public Dataset (Kaggle), CC BY-NC-SA 4.0, educational use
-- Tables are the original Olist CSVs imported as-is, named after the files.
-- FILE 2 of 4: 02_checks.sql
-- PURPOSE: prove the SQL model matches the Excel model. Expected results are in comments.

-- Check A: headline KPIs
-- Expected: 96470 | 7826 | 8.11 | 12.56 | 4.1563
SELECT COUNT(*) AS delivery_base, SUM(is_late) AS late_orders,
       ROUND(100.0*SUM(is_late)/COUNT(*),2) AS late_pct,
       ROUND(AVG(delivery_days),2) AS avg_delivery_days,
       ROUND(AVG(review_score),4) AS avg_review
FROM v_delivery;

-- Check B: delay buckets
-- Expected: On time 88644 (4.29), 1-3 days 2662 (3.76), 3-7 days 1819 (2.32),
--           7-14 days 1790 (1.75), Over 14 days 1555 (1.71)
SELECT delay_bucket, COUNT(*) AS orders, ROUND(AVG(review_score),2) AS avg_score
FROM v_delivery GROUP BY delay_bucket;

-- Check C: same-state vs cross-state
-- Expected: Cross-state 61769 | 9.27 | 15.15   Same state 34701 | 6.06 | 7.95
SELECT route_type, COUNT(*) AS orders,
       ROUND(100.0*AVG(is_late),2) AS late_pct,
       ROUND(AVG(delivery_days),2) AS avg_days
FROM v_delivery GROUP BY route_type;

-- Check D: revenue and freight, excluding canceled and unavailable orders
-- Expected: 99441 | 13494400.74 | 2241126.29
SELECT COUNT(*) AS all_orders,
       ROUND(SUM(CASE WHEN order_status NOT IN ('canceled','unavailable') THEN item_revenue END),2) AS revenue_counted,
       ROUND(SUM(CASE WHEN order_status NOT IN ('canceled','unavailable') THEN freight_total END),2) AS freight_counted
FROM v_orders;

-- Check E: the join-inflation trap
-- Joining items straight to payments repeats items for orders paid in several instalments.
-- Expected: 117601 rows (real item rows: 112650) | overstated by 617471.64
SELECT COUNT(*) AS joined_rows,
       ROUND(SUM(i.price),2) AS wrong_revenue,
       ROUND((SELECT SUM(price) FROM olist_order_items_dataset),2) AS true_revenue,
       ROUND(SUM(i.price) - (SELECT SUM(price) FROM olist_order_items_dataset),2) AS overstated_by
FROM olist_order_items_dataset i
JOIN olist_order_payments_dataset p ON p.order_id = i.order_id;
