-- experiments/02_customer_lookup.sql
--
-- Experiment 2 — Customer lookup (prompt §6 B / §7.1 / §7.2)
-- Canonical query Q2 (see sql/baseline_queries.sql):
--   SELECT id, status, total_amount, created_at
--   FROM orders
--   WHERE customer_id = 42
--   ORDER BY created_at DESC
--   LIMIT 20;
--
-- Progression: baseline Seq Scan → single-column index (customer_id)
-- → composite (customer_id, created_at DESC). The single-column index is
-- deliberately dropped after the comparison: the composite replaces it
-- for this workload, and keeping both would be redundant (§7.5).

\set ON_ERROR_STOP on
\timing on
\pset pager off
\echo '===== EXPERIMENT 02 — customer lookup + newest-20 sort ====='

-- Clean starting state for this experiment's indexes (rerunnable).
DROP INDEX IF EXISTS idx_orders_customer_id;
DROP INDEX IF EXISTS idx_orders_customer_created_at;

-- ---- Phase 1: baseline -------------------------------------------------------
\echo '--- Phase 1: baseline, trial 1/3 (Seq Scan + top-N sort expected) ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Phase 1: baseline, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Phase 1: baseline, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

-- ---- Phase 2: single-column B-tree on customer_id ----------------------------
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
ANALYZE orders;

\echo '--- Phase 2: single-column (customer_id), trial 1/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Phase 2: single-column (customer_id), trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Phase 2: single-column (customer_id), trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

-- ---- Phase 3: replace with the composite (customer_id, created_at DESC) ------
-- With the composite the top-20 lookup becomes a single ordered index
-- scan that stops after 20 entries: no filter-then-sort at all.
DROP INDEX idx_orders_customer_id;

CREATE INDEX idx_orders_customer_created_at
    ON orders (customer_id, created_at DESC);
ANALYZE orders;

\echo '--- Phase 3: composite (customer_id, created_at DESC), trial 1/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Phase 3: composite, trial 2/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

\echo '--- Phase 3: composite, trial 3/3 ---'
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, status, total_amount, created_at
FROM orders
WHERE customer_id = 42
ORDER BY created_at DESC
LIMIT 20;

-- ---- Sizes -------------------------------------------------------------------
\echo '--- Index sizes (this experiment) ---'
SELECT idx.relname AS index_name, pg_size_pretty(pg_relation_size(idx.oid)) AS size
FROM pg_index i
JOIN pg_class idx ON idx.oid = i.indexrelid
WHERE idx.relname IN ('idx_orders_customer_created_at');

\echo '===== EXPERIMENT 02 done — single-column index dropped on purpose ====='
