-- experiments/01_filter_queries.sql
--
-- Experiment 1 — Filtering (prompt §6 A / §7.2)
-- Canonical query Q1 (see sql/baseline_queries.sql):
--   SELECT ... FROM orders
--   WHERE status = 'paid'
--     AND created_at >= '2025-11-01' AND created_at < '2025-12-01'
--   ORDER BY created_at DESC;
--
-- Protocol: 3 baseline trials (no dedicated index) → create a composite
-- B-tree (status, created_at) → ANALYZE → 3 identical trials again.
-- Numbers are environment-specific; documented in results/ + docs/findings.md.

\set ON_ERROR_STOP on
\timing on
\pset pager off
\echo '===== EXPERIMENT 01 — filter (status + date range) ====='

-- Ensure a clean starting state for THIS experiment's index (rerunnable).
DROP INDEX IF EXISTS idx_orders_status_created_at;

-- ---- Phase 1: baseline (no dedicated index) ---------------------------------
\echo '--- Phase 1: baseline, trial 1/3 (Seq Scan expected) ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-11-01'
  AND created_at <  TIMESTAMPTZ '2025-12-01'
ORDER BY created_at DESC;

\echo '--- Phase 1: baseline, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-11-01'
  AND created_at <  TIMESTAMPTZ '2025-12-01'
ORDER BY created_at DESC;

\echo '--- Phase 1: baseline, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-11-01'
  AND created_at <  TIMESTAMPTZ '2025-12-01'
ORDER BY created_at DESC;

-- ---- Phase 2: create the composite index ------------------------------------
-- Column order rule: equality column (status) first, range column second.
-- The planner will use it for status = 'paid' AND created_at >= x, but NOT
-- to serve ORDER BY created_at (created_at is not the leading/only column).
CREATE INDEX idx_orders_status_created_at
    ON orders (status, created_at);

ANALYZE orders;

\echo '--- Phase 2: after (status, created_at) index, trial 1/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-11-01'
  AND created_at <  TIMESTAMPTZ '2025-12-01'
ORDER BY created_at DESC;

\echo '--- Phase 2: after, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-11-01'
  AND created_at <  TIMESTAMPTZ '2025-12-01'
ORDER BY created_at DESC;

\echo '--- Phase 2: after, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, customer_id, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
  AND created_at >= TIMESTAMPTZ '2025-11-01'
  AND created_at <  TIMESTAMPTZ '2025-12-01'
ORDER BY created_at DESC;

-- ---- Observed summary (to be filled from results/) ---------------------------
\echo '--- Index size ---'
SELECT idx.relname AS index_name, pg_size_pretty(pg_relation_size(idx.oid)) AS size
FROM pg_index i
JOIN pg_class idx ON idx.oid = i.indexrelid
WHERE idx.relname IN ('idx_orders_status_created_at');

\echo '===== EXPERIMENT 01 done — compare plans above ====='
