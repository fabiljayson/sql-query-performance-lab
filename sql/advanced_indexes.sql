-- sql/advanced_indexes.sql — transient demo indexes (educational only).
--
-- Two indexes used inside experiments and deliberately NOT part of the
-- retained set:
--   * idx_orders_customer_id      exp 02 -- single-column; superseded by
--                                          the composite, so it is dropped
--                                          right after the comparison.
--   * idx_orders_customer_covering exp 03 -- INCLUDE/covering demo; its
--                                          leading columns duplicate
--                                          idx_orders_customer_created_at,
--                                          so it is dropped on purpose
--                                          (redundancy lesson, §7.5).
--
-- The suite creates and drops these itself. Applying this file manually
-- recreates the dupe state mentioned above — acceptable only for
-- isolated exploration, never for the benchmarked "final state".

\set ON_ERROR_STOP on

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON orders (customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_customer_covering
    ON orders (customer_id, created_at) INCLUDE (total_amount);

ANALYZE orders;

\echo 'Transient demo indexes applied (drop them to converge on the retained set).'
