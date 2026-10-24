-- experiments/03_join_queries.sql
--
-- Experiment 3 — Join performance + FK index + covering index
-- (prompt §6 C / §7.4 / §7.5)
--
-- 3a. Canonical query Q3: total spending of customer 42. Before the
--     FK index on order_items(order_id) the executor must scan the whole
--     2.5 M-row order_items table; after it, a nested loop probes
--     only that customer's items.
-- 3b. Covering index (INCLUDE): same query shape as Q3-covering over the
--     "heavy" customers 1..1000 — the INCLUDE additions let the executor
--     return everything from the index (index-only scan, possible only
--     when the visibility map marks pages all-visible: seed ran VACUUM).
--     The covering index is then DROPPED: its leading columns duplicate
--     idx_orders_customer_created_at, so keeping it would be redundant.

\set ON_ERROR_STOP on
\timing on
\pset pager off
\echo '===== EXPERIMENT 03 — join + FK index + covering index ====='

-- Clean state for this experiment's indexes (rerunnable).
DROP INDEX IF EXISTS idx_order_items_order_id;
DROP INDEX IF EXISTS idx_orders_customer_covering;

-- ---- 3a Phase 1: baseline (no index on order_items.order_id) ------------------
\echo '--- 3a Phase 1: baseline, trial 1/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.id, c.full_name,
       round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o          ON o.customer_id = c.id
JOIN order_items oi    ON oi.order_id = o.id
WHERE c.id = 42
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC;

\echo '--- 3a Phase 1: baseline, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.id, c.full_name,
       round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o          ON o.customer_id = c.id
JOIN order_items oi    ON oi.order_id = o.id
WHERE c.id = 42
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC;

\echo '--- 3a Phase 1: baseline, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.id, c.full_name,
       round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o          ON o.customer_id = c.id
JOIN order_items oi    ON oi.order_id = o.id
WHERE c.id = 42
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC;

-- ---- 3a Phase 2: FK index on order_items.order_id -----------------------------
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
ANALYZE order_items;

\echo '--- 3a Phase 2: after FK index, trial 1/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.id, c.full_name,
       round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o          ON o.customer_id = c.id
JOIN order_items oi    ON oi.order_id = o.id
WHERE c.id = 42
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC;

\echo '--- 3a Phase 2: after FK index, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.id, c.full_name,
       round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o          ON o.customer_id = c.id
JOIN order_items oi    ON oi.order_id = o.id
WHERE c.id = 42
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC;

\echo '--- 3a Phase 2: after FK index, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT c.id, c.full_name,
       round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
FROM customers c
JOIN orders o          ON o.customer_id = c.id
JOIN order_items oi    ON oi.order_id = o.id
WHERE c.id = 42
GROUP BY c.id, c.full_name
ORDER BY total_spent DESC;

-- ---- 3b Covering index with INCLUDE columns -----------------------------------
\echo '--- 3b Phase 1: baseline for covering demo (with composite index present; total_amount requires heap fetches) ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT customer_id, SUM(total_amount) AS total_spend
FROM orders
WHERE customer_id BETWEEN 1 AND 1000
GROUP BY customer_id;

CREATE INDEX idx_orders_customer_covering
    ON orders (customer_id, created_at) INCLUDE (total_amount);
ANALYZE orders;

\echo '--- 3b Phase 2: after covering index (index-only scan possible thanks to VACUUM-ed visibility map) ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT customer_id, SUM(total_amount) AS total_spend
FROM orders
WHERE customer_id BETWEEN 1 AND 1000
GROUP BY customer_id;

\echo '--- 3b The index is DROPPED: leading columns duplicate idx_orders_customer_created_at (redundancy, §7.5) ---'
DROP INDEX idx_orders_customer_covering;

-- ---- Sizes --------------------------------------------------------------------
\echo '--- FK index size ---'
SELECT idx.relname AS index_name, pg_size_pretty(pg_relation_size(idx.oid)) AS size
FROM pg_index i
JOIN pg_class idx ON idx.oid = i.indexrelid
WHERE idx.relname IN ('idx_order_items_order_id');

\echo '===== EXPERIMENT 03 done — FK index kept, covering index dropped ====='
