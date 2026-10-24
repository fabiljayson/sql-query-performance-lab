-- sql/cleanup.sql — remove the LABORATORY experimental indexes.
--
-- Safe by design: it touches index objects only, never table data, and
-- only the six experiment index names are referenced. Run before
-- re-running the suite from scratch, or to return the schema to its
-- "constraints only" baseline state.
--
-- NOT a data reset: dropping tables happens only in
-- scripts/reset_database.sh (which requires explicit confirmation).

\set ON_ERROR_STOP on

DROP INDEX IF EXISTS idx_orders_status_created_at;
DROP INDEX IF EXISTS idx_orders_customer_created_at;
DROP INDEX IF EXISTS idx_order_items_order_id;
DROP INDEX IF EXISTS idx_orders_pending_recent;
DROP INDEX IF EXISTS idx_orders_customer_id;
DROP INDEX IF EXISTS idx_orders_customer_covering;

\echo 'Experimental indexes removed; constraints-only baseline restored.'
