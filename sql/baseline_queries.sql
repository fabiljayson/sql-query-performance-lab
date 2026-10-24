-- sql/baseline_queries.sql — the five canonical read queries.
--
-- EXECUTION lives in the experiment files (single source of truth):
--   experiments/01_filter_queries.sql    → Q1
--   experiments/02_customer_lookup.sql   → Q2
--   experiments/03_join_queries.sql      → Q3, Q3-covering
--   experiments/04_partial_indexes.sql   → Q4, Q4-broad
--   experiments/05_write_overhead.sql    → INSERT benchmark
--
-- This file documents the EXACT SQL text that every plan comparison
-- must guard: the same query text and the same literal parameters must
-- be used before and after indexing (adapted only by the index state).

-- Q1 — Filter: paid orders placed in November 2025 (~8 500 of 1 M rows)
-- EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- SELECT id, customer_id, status, total_amount, created_at
-- FROM orders
-- WHERE status = 'paid'
--   AND created_at >= TIMESTAMPTZ '2025-11-01'
--   AND created_at <  TIMESTAMPTZ '2025-12-01'
-- ORDER BY created_at DESC;

-- Q2 — Customer lookup: newest 20 orders of customer 42 (~32 total)
-- EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- SELECT id, status, total_amount, created_at
-- FROM orders
-- WHERE customer_id = 42
-- ORDER BY created_at DESC
-- LIMIT 20;

-- Q3 — Join: total spending of customer 42 through their items
-- EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- SELECT c.id, c.full_name,
--        round(SUM(oi.quantity * oi.unit_price), 2) AS total_spent
-- FROM customers c
-- JOIN orders o          ON o.customer_id = c.id
-- JOIN order_items oi    ON oi.order_id = o.id
-- WHERE c.id = 42
-- GROUP BY c.id, c.full_name
-- ORDER BY total_spent DESC;

-- Q3-covering — index-only candidate: spend over the "heavy" customers 1..1000
-- EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- SELECT customer_id, SUM(total_amount) AS total_spend
-- FROM orders
-- WHERE customer_id BETWEEN 1 AND 1000
-- GROUP BY customer_id;

-- Q4 — Partial-index candidate: pending orders created since June 2025
-- EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
-- SELECT id, customer_id, total_amount, created_at
-- FROM orders
-- WHERE status = 'pending'
--   AND created_at >= TIMESTAMPTZ '2025-06-01'
-- ORDER BY created_at DESC;

-- Q4-broad — deliberately INCOMPATIBLE with the partial index: the date
-- predicate widens by one year (created_at >= '2024-06-01'), which is not
-- contained in the partial index predicate, so the optimizer must ignore it.
