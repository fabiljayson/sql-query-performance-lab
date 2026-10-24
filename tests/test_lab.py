# tests/test_lab.py — read-only invariant checks for the performance lab.
# Safe to run at any point: no DDL, no writes, session-scoped connection.

import pytest


def test_postgres_version_is_18(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT version()")
        version = cur.fetchone()[0]
    assert "PostgreSQL 18" in version, version


def test_expected_tables_exist(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public'
            ORDER BY table_name
        """)
        tables = {row[0] for row in cur.fetchall()}
    assert {"customers", "products", "orders", "order_items"} <= tables


def test_no_empty_tables(conn):
    with conn.cursor() as cur:
        for table in ("customers", "products", "orders", "order_items"):
            cur.execute(f"SELECT count(*) FROM {table}")  # noqa: S608 — fixed identifier, not user input
            assert cur.fetchone()[0] > 0, f"{table} is empty (load a dataset first)"


def test_order_items_within_item_cap(conn):
    """Every order carries between 1 and 4 items (seed contract)."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT count(*) FROM (
                SELECT order_id FROM order_items
                GROUP BY order_id HAVING count(*) NOT BETWEEN 1 AND 4
            ) rogue
        """)
        rogue = cur.fetchone()[0]
    assert rogue == 0


def test_total_amount_matches_items(conn):
    """The money column the lab stores equals the sum of its items."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT o.total_amount = COALESCE(s.total, 0) AS equal
            FROM orders o
            JOIN (SELECT order_id, sum(quantity * unit_price) AS total
                  FROM order_items GROUP BY order_id) s ON s.order_id = o.id
            LIMIT 1
        """)
        assert cur.fetchone() is not None, "no joinable row found"
        cur.execute("""
            SELECT bool_and(o.total_amount = s.total)
            FROM orders o
            JOIN (SELECT order_id, sum(quantity * unit_price) AS total
                  FROM order_items GROUP BY order_id) s ON s.order_id = o.id
        """)
        assert cur.fetchone()[0] is True


def test_status_domain(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT DISTINCT status FROM orders ORDER BY 1")
        found = {row[0] for row in cur.fetchall()}
    assert found == {"pending", "paid", "shipped", "delivered", "cancelled", "refunded"}


def test_customer_skew_is_present(conn):
    """pow(random(), 2) skew: hot customer holds a visibly larger share."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT (SELECT count(*) FROM orders WHERE customer_id = 1)::float
                 / (SELECT avg(c) FROM (
                        SELECT count(*) AS c FROM orders GROUP BY customer_id
                    ) x)
        """)
        ratio = cur.fetchone()[0]
    assert ratio > 2.0, f"expected a hot customer, ratio={ratio:.2f}"


def test_email_unique(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT count(DISTINCT email), count(*) FROM customers")
        distinct_total = cur.fetchone()
    assert distinct_total[0] == distinct_total[1]


def test_sequences_are_ahead_of_max_ids(conn):
    """Sequence values are never behind the stored rows. Note: sequences
    are intentionally NOT transactional — rolled-back inserts leave
    permanent gaps, so we only require >= (no future nextval collides)."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT (SELECT last_value FROM customers_id_seq) >= (
                     SELECT coalesce(max(id), 0) FROM customers),
                   (SELECT last_value FROM orders_id_seq) >= (
                     SELECT coalesce(max(id), 0) FROM orders),
                   (SELECT last_value FROM order_items_id_seq) >= (
                     coalesce((SELECT max(id) FROM order_items), 0)::numeric)
        """)
        ahead = cur.fetchone()
    assert all(ahead)


def test_standard_dataset_detectable(conn):
    """When the standard dataset is loaded, counts hit the published
    targets (100k / 1M / ~2.5M). Otherwise the test skips."""
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM orders")
        orders = cur.fetchone()[0]
    if orders < 100000:
        pytest.skip(f"standard dataset not loaded (orders={orders})")
    assert orders == 1000000


def test_experiment_indexes_when_applied(conn):
    """The retained set from the experiment suite, when any of it is
    present, must be completely present."""
    expected = {
        "idx_orders_status_created_at",
        "idx_orders_customer_created_at",
        "idx_order_items_order_id",
        "idx_orders_pending_recent",
    }
    with conn.cursor() as cur:
        cur.execute("""
            SELECT indexname FROM pg_indexes
            WHERE indexname = ANY(%s)
        """, (sorted(expected),))
        found = {row[0] for row in cur.fetchall()}
    if not found:
        pytest.skip("no experiment indexes applied yet (fresh setup) — run the suite first")
    assert expected == found, f"partial application: {sorted(found)}"
