-- Olist Delivery Performance Analysis (portfolio case study)
-- Author: Bimal K Augustine | Tool: SQLite (DB Browser for SQLite) | Written: October 2026
-- Data: Olist Brazilian E-Commerce Public Dataset (Kaggle), CC BY-NC-SA 4.0, educational use
-- Tables are the original Olist CSVs imported as-is, named after the files.
-- FILE 4 of 4: 04_root_cause.sql
-- PURPOSE: where does the lateness come from? Supports the "Insights and Recommendations" document.
-- Reads from v_delivery (run 01_views.sql first). These numbers are SQL only (not on the Excel dashboard).

-- R1: Share of late orders by route type
-- Expected: Cross-state 5723 (73.1%), Same state 2103 (26.9%)
SELECT route_type, SUM(is_late) AS late_orders,
       ROUND(100.0*SUM(is_late)/(SELECT SUM(is_late) FROM v_delivery),1) AS share_of_late_pct
FROM v_delivery
GROUP BY route_type;

-- R2: Share of late orders by destination state (top 4)
-- Expected: SP 2387 (30.5%), RJ 1664 (21.3%), MG 637 (8.1%), BA 457 (5.8%)
SELECT customer_state, SUM(is_late) AS late_orders,
       ROUND(100.0*SUM(is_late)/(SELECT SUM(is_late) FROM v_delivery),1) AS share_of_late_pct
FROM v_delivery
GROUP BY customer_state
ORDER BY late_orders DESC
LIMIT 4;

-- R3: Promised days versus actual days (all delivered orders)
-- Expected: 23.74 promised | 12.56 actual
SELECT ROUND(AVG(julianday(estimated_at) - julianday(order_purchase_timestamp)),2) AS avg_promised_days,
       ROUND(AVG(delivery_days),2) AS avg_actual_days
FROM v_delivery;

-- R4: Time by stage, late versus on-time
-- to_carrier = purchase to handover to the carrier (seller side)
-- transit    = handover to the carrier until delivery to the customer
-- Expected: on-time (0) 88644 | 3.0 | 7.89   late (1) 7825 | 5.83 | 25.68
-- (one late order has no carrier date and is left out)
SELECT d.is_late, COUNT(*) AS orders,
       ROUND(AVG(julianday(o.order_delivered_carrier_date) - julianday(d.order_purchase_timestamp)),2) AS to_carrier_days,
       ROUND(AVG(julianday(d.delivered_at) - julianday(o.order_delivered_carrier_date)),2) AS transit_days
FROM v_delivery d
JOIN olist_orders_dataset o ON o.order_id = d.order_id
WHERE NULLIF(o.order_delivered_carrier_date,'') IS NOT NULL
GROUP BY d.is_late;

-- R5: Orders handed to the carrier after the seller's shipping limit date
-- (earliest shipping limit among the order's items)
-- Expected: on-time 88644 | 6595 missed   late 7825 | 2128 missed
SELECT d.is_late, COUNT(*) AS orders,
       SUM(CASE WHEN julianday(o.order_delivered_carrier_date) > julianday(f.shipping_limit_date)
                THEN 1 ELSE 0 END) AS missed_limit
FROM v_delivery d
JOIN olist_orders_dataset o ON o.order_id = d.order_id
JOIN (SELECT order_id, MIN(shipping_limit_date) AS shipping_limit_date
      FROM olist_order_items_dataset GROUP BY order_id) f ON f.order_id = d.order_id
WHERE NULLIF(o.order_delivered_carrier_date,'') IS NOT NULL
GROUP BY d.is_late;
-- Overall share that missed the limit: (6595 + 2128) / (88644 + 7825) = 9.0%
