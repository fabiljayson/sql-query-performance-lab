-- experiments/04_partial_indexes.sql
--
-- Experiment 4 — Partial index + predicate compatibility (prompt §6 D / §7.3)
--
-- The partial index targets a well-defined operational subset: pending
-- orders created since June 2025. Two canonical queries:
--   Q4        status='pending' AND created_at >= '2025-06-01'  (compatible)
--   Q4-broad  status='pending' AND created_at >= '2024-06-01'  (NOT contained
--             in the index predicate → the optimizer must ignore the index)
--
-- To isolate the partial index effect, the fuller composite
-- idx_orders_status_created_at (from experiment 01) is dropped first and
-- re-created at the end (documented, purposeful churn inside the lab only).

\set ON_ERROR_STOP on
\timing on
\pset pager off
\echo '===== EXPERIMENT 04 — partial index + predicate compatibility ====='

-- Clean state for this experiment's index (rerunnable) and temporarily
-- remove the composite to isolate the partial-index comparison.
DROP INDEX IF EXISTS idx_orders_pending_recent;
DROP INDEX IF EXISTS idx_orders_status_created_at;

-- ---- Phase 1: baseline (no status/date index at all) ---------------------------
\echo '--- Phase 1: baseline, trial 1/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2025-06-01'
ORDER BY created_at DESC;

\echo '--- Phase 1: baseline, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2025-06-01'
ORDER BY created_at DESC;

\echo '--- Phase 1: baseline, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2025-06-01'
ORDER BY created_at DESC;

-- ---- Phase 2: create a tiny partial index --------------------------------------
-- The predicate bakes the operational subset into the index: only the
-- ~4 k pending rows since June 2025 ever live inside it.
CREATE INDEX idx_orders_pending_recent
    ON orders (created_at DESC)
    WHERE status = 'pending'
      AND created_at >= TIMESTAMPTZ '2025-06-01';
ANALYZE orders;

\echo '--- Phase 2: after partial index, trial 1/3 (exact plan nodes decide, not hope) ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2025-06-01'
ORDER BY created_at DESC;

\echo '--- Phase 2: after partial index, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2025-06-01'
ORDER BY created_at DESC;

\echo '--- Phase 2: after partial index, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2025-06-01'
ORDER BY created_at DESC;

\echo '--- index size (tiny on purpose) + full-table size for scale ---'
SELECT idx.relname AS index_name, pg_size_pretty(pg_relation_size(idx.oid)) AS size
FROM pg_index i
JOIN pg_class idx ON idx.oid = i.indexrelid
WHERE idx.relname IN ('idx_orders_pending_recent');
SELECT pg_size_pretty(pg_relation_size('orders')) AS orders_table_size;

-- ---- Phase 3: the broad query must NOT use the partial index -------------------
\echo '--- Phase 3: broad query (one year wider) — partial index must be ignored ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2024-06-01'
ORDER BY created_at DESC;

-- ---- Phase 4: restore the composite (fuller workload index) -------------------
CREATE INDEX idx_orders_status_created_at
    ON orders (status, created_at);
ANALYZE orders;

\echo '--- Phase 4: broad query with composite restored (fuller-token plan) ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, total_amount, created_at
FROM orders
WHERE status = 'pending'
  AND created_at >= TIMESTAMPTZ '2024-06-01'
ORDER BY created_at DESC;

\echo '===== EXPERIMENT 04 done — composite restored, partial index kept ====='
