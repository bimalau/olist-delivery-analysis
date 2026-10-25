-- Olist Delivery Performance Analysis (portfolio case study)
-- Author: Bimal K Augustine | Tool: SQLite (DB Browser for SQLite) | Written: October 2026
-- Data: Olist Brazilian E-Commerce Public Dataset (Kaggle), CC BY-NC-SA 4.0, educational use
-- Tables are the original Olist CSVs imported as-is, named after the files.
-- FILE 1 of 4: 01_views.sql
-- PURPOSE: rebuild the order-level model (same as the Excel Power Query model).
-- RUN FIRST. Later files read from these two views.

-- v_orders: one row per order (99,441 rows).
-- Items and reviews have many rows per order, so each is reduced to one row per order
-- BEFORE joining. Joining them directly would multiply rows and inflate totals.
DROP VIEW IF EXISTS v_orders;
CREATE VIEW v_orders AS
WITH item_tot AS (
  SELECT order_id, COUNT(*) AS item_count,
         SUM(price) AS item_revenue, SUM(freight_value) AS freight_total
  FROM olist_order_items_dataset GROUP BY order_id),
first_item AS (               -- seller of the first item = the order's seller
  SELECT i.order_id, s.seller_state
  FROM olist_order_items_dataset i
  JOIN olist_sellers_dataset s ON s.seller_id = i.seller_id
  WHERE i.order_item_id = 1),
first_review AS (             -- one review per order: the first one in the file
  SELECT r.order_id, CAST(r.review_score AS INTEGER) AS review_score
  FROM olist_order_reviews_dataset r
  JOIN (SELECT MIN(rowid) AS rid FROM olist_order_reviews_dataset GROUP BY order_id) f
       ON f.rid = r.rowid)
SELECT
  o.order_id, o.customer_id, c.customer_state, o.order_status,
  o.order_purchase_timestamp,
  NULLIF(o.order_delivered_customer_date,'') AS delivered_at,
  o.order_estimated_delivery_date            AS estimated_at,
  substr(o.order_purchase_timestamp,1,7)     AS order_month,
  COALESCE(t.item_count,0) AS item_count,
  t.item_revenue, t.freight_total,
  fi.seller_state, fr.review_score,
  CASE WHEN o.order_status='delivered'
        AND NULLIF(o.order_delivered_customer_date,'') IS NOT NULL
       THEN 1 ELSE 0 END AS in_delivery_base
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON c.customer_id = o.customer_id
LEFT JOIN item_tot t      ON t.order_id  = o.order_id
LEFT JOIN first_item fi   ON fi.order_id = o.order_id
LEFT JOIN first_review fr ON fr.order_id = o.order_id;

-- v_delivery: only the 96,470 delivered orders that have a customer delivery date.
-- Late = delivered after the estimated date that was shown at purchase.
DROP VIEW IF EXISTS v_delivery;
CREATE VIEW v_delivery AS
SELECT *,
  julianday(delivered_at) - julianday(order_purchase_timestamp) AS delivery_days,
  CASE WHEN julianday(delivered_at) > julianday(estimated_at) THEN 1 ELSE 0 END AS is_late,
  julianday(delivered_at) - julianday(estimated_at) AS days_late,
  CASE WHEN julianday(delivered_at) <= julianday(estimated_at) THEN 'On time'
       WHEN julianday(delivered_at) - julianday(estimated_at) <= 3  THEN '1-3 days late'
       WHEN julianday(delivered_at) - julianday(estimated_at) <= 7  THEN '3-7 days late'
       WHEN julianday(delivered_at) - julianday(estimated_at) <= 14 THEN '7-14 days late'
       ELSE 'Over 14 days late' END AS delay_bucket,
  CASE WHEN seller_state = customer_state THEN 'Same state' ELSE 'Cross-state' END AS route_type
FROM v_orders WHERE in_delivery_base = 1;
