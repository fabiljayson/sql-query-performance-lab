-- experiments/05_write_overhead.sql
--
-- Experiment 5 — Write overhead (prompt §7.5 use-cases, §9)
--
-- Measures the cost of the retained index set on INSERTs:
--   * bare phase  : all experimental indexes dropped (through cleanup
--                   statements), 3 trials of a 5 000-row INSERT,
--                   every trial inside BEGIN…ROLLBACK so the lab data
--                   stays untouched;
--   * indexed phase: sql/indexes.sql re-applies the retained set
--                   (exactly the same DDL as the other experiments),
--                   then 3 identical rolled-back trials.
--
-- The INSERT shape reuses the seed's distributions (alpha=2 customer
-- skew, weighted statuses) with setseed pinned per trial so the three
-- trials differ only by chance-level noise. \timing prints wall-clock
-- time; the EXPLAIN (ANALYZE) "Execution Time" is the planner view.

\set ON_ERROR_STOP on
\timing on
\pset pager off
\echo '===== EXPERIMENT 05 — write overhead ====='

-- ---- Phase 1: bare-table insert baseline --------------------------------------
-- Temporary removal is deliberate; the retained set returns in Phase 2.
DROP INDEX IF EXISTS idx_orders_status_created_at;
DROP INDEX IF EXISTS idx_orders_customer_created_at;
DROP INDEX IF EXISTS idx_order_items_order_id;
DROP INDEX IF EXISTS idx_orders_pending_recent;

\echo '--- Phase 1: bare tables, trial 1/3 (5 000-row INSERT, rolled back) ---'
BEGIN;
SELECT setseed(0.10);
\timing on
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT 1 + floor(pow(random(), 2) * 100000)::bigint, s.status, s.amount,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT
        CASE
            WHEN r < 0.45 THEN 'delivered'::text
            WHEN r < 0.65 THEN 'paid'::text
            WHEN r < 0.80 THEN 'shipped'::text
            WHEN r < 0.90 THEN 'cancelled'::text
            WHEN r < 0.95 THEN 'refunded'::text
            ELSE 'pending'::text
        END AS status,
        round((random() * 1900 + 60)::numeric, 2) AS amount,
        r
      FROM (SELECT random() AS r
            FROM generate_series(1, 5000)) g) s;
\timing off
ROLLBACK;

\echo '--- Phase 1: bare tables, trial 2/3 ---'
BEGIN;
SELECT setseed(0.11);
\timing on
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT 1 + floor(pow(random(), 2) * 100000)::bigint, s.status, s.amount,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT
        CASE
            WHEN r < 0.45 THEN 'delivered'::text
            WHEN r < 0.65 THEN 'paid'::text
            WHEN r < 0.80 THEN 'shipped'::text
            WHEN r < 0.90 THEN 'cancelled'::text
            WHEN r < 0.95 THEN 'refunded'::text
            ELSE 'pending'::text
        END AS status,
        round((random() * 1900 + 60)::numeric, 2) AS amount,
        r
      FROM (SELECT random() AS r
            FROM generate_series(1, 5000)) g) s;
\timing off
ROLLBACK;

\echo '--- Phase 1: bare tables, trial 3/3 ---'
BEGIN;
SELECT setseed(0.12);
\timing on
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT 1 + floor(pow(random(), 2) * 100000)::bigint, s.status, s.amount,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT
        CASE
            WHEN r < 0.45 THEN 'delivered'::text
            WHEN r < 0.65 THEN 'paid'::text
            WHEN r < 0.80 THEN 'shipped'::text
            WHEN r < 0.90 THEN 'cancelled'::text
            WHEN r < 0.95 THEN 'refunded'::text
            ELSE 'pending'::text
        END AS status,
        round((random() * 1900 + 60)::numeric, 2) AS amount,
        r
      FROM (SELECT random() AS r
            FROM generate_series(1, 5000)) g) s;
\timing off
ROLLBACK;

-- ---- Phase 2: retained index set re-applied ------------------------------------
\echo '--- Phase 2: re-apply the retained index set (single DDL source) ---'
\ir ../sql/indexes.sql

\echo '--- Phase 2: with indexes, trial 1/3 (5 000-row INSERT, rolled back) ---'
BEGIN;
SELECT setseed(0.20);
\timing on
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT 1 + floor(pow(random(), 2) * 100000)::bigint, s.status, s.amount,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT
        CASE
            WHEN r < 0.45 THEN 'delivered'::text
            WHEN r < 0.65 THEN 'paid'::text
            WHEN r < 0.80 THEN 'shipped'::text
            WHEN r < 0.90 THEN 'cancelled'::text
            WHEN r < 0.95 THEN 'refunded'::text
            ELSE 'pending'::text
        END AS status,
        round((random() * 1900 + 60)::numeric, 2) AS amount,
        r
      FROM (SELECT random() AS r
            FROM generate_series(1, 5000)) g) s;
\timing off
ROLLBACK;

\echo '--- Phase 2: with indexes, trial 2/3 ---'
BEGIN;
SELECT setseed(0.21);
\timing on
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT 1 + floor(pow(random(), 2) * 100000)::bigint, s.status, s.amount,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT
        CASE
            WHEN r < 0.45 THEN 'delivered'::text
            WHEN r < 0.65 THEN 'paid'::text
            WHEN r < 0.80 THEN 'shipped'::text
            WHEN r < 0.90 THEN 'cancelled'::text
            WHEN r < 0.95 THEN 'refunded'::text
            ELSE 'pending'::text
        END AS status,
        round((random() * 1900 + 60)::numeric, 2) AS amount,
        r
      FROM (SELECT random() AS r
            FROM generate_series(1, 5000)) g) s;
\timing off
ROLLBACK;

\echo '--- Phase 2: with indexes, trial 3/3 ---'
BEGIN;
SELECT setseed(0.22);
\timing on
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO orders (customer_id, status, total_amount, created_at)
SELECT 1 + floor(pow(random(), 2) * 100000)::bigint, s.status, s.amount,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT
        CASE
            WHEN r < 0.45 THEN 'delivered'::text
            WHEN r < 0.65 THEN 'paid'::text
            WHEN r < 0.80 THEN 'shipped'::text
            WHEN r < 0.90 THEN 'cancelled'::text
            WHEN r < 0.95 THEN 'refunded'::text
            ELSE 'pending'::text
        END AS status,
        round((random() * 1900 + 60)::numeric, 2) AS amount,
        r
      FROM (SELECT random() AS r
            FROM generate_series(1, 5000)) g) s;
\timing off
ROLLBACK;

-- ---- Sizes: per-index storage report -------------------------------------------
\echo '--- Per-index storage after experiment 5 ---'
SELECT idx.relname AS index_name,
       pg_size_pretty(pg_relation_size(idx.oid)) AS index_size
FROM   pg_class idx
JOIN   pg_index i  ON i.indexrelid = idx.oid
JOIN   pg_class t  ON t.oid = i.indrelid
WHERE  t.relname IN ('orders', 'order_items')
  AND  idx.relname
       IN ('idx_orders_status_created_at',
           'idx_orders_customer_created_at',
           'idx_order_items_order_id',
           'idx_orders_pending_recent')
ORDER BY 1;

\echo '===== EXPERIMENT 05 done — every trial was rolled back ====='
