-- sql/indexes.sql — the retained experimental index set ("final state").
--
-- These four indexes are the ones the benchmark suite leaves in place,
-- each justified by a measured benefit in docs/findings.md:
--   * idx_orders_status_created_at    exp 01 -- composite status filter
--   * idx_orders_customer_created_at  exp 02 -- composite lookup+sort
--   * idx_order_items_order_id        exp 03 -- FK index for joins
--   * idx_orders_pending_recent       exp 04 -- tiny operational partial
--
-- Idempotent and safe to (re)run: CREATE INDEX IF NOT EXISTS + ANALYZE.
-- Drop helpers live in sql/cleanup.sql. The two transient demo indexes
-- (single-column customer_id, covering INCLUDE) are NOT here — see
-- sql/advanced_indexes.sql for their documented lifecycle.

\set ON_ERROR_STOP on

CREATE INDEX IF NOT EXISTS idx_orders_status_created_at
    ON orders (status, created_at);

CREATE INDEX IF NOT EXISTS idx_orders_customer_created_at
    ON orders (customer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items (order_id);

CREATE INDEX IF NOT EXISTS idx_orders_pending_recent
    ON orders (created_at DESC)
    WHERE status = 'pending'
      AND created_at >= TIMESTAMPTZ '2025-06-01';

-- Refresh statistics so the optimizer sees the new indexes immediately.
ANALYZE orders;
ANALYZE order_items;

\echo 'Retained index set applied.'
