-- sql/seed.sql — deterministic synthetic dataset for the performance lab.
--
-- Usage:  psql ... -f sql/seed.sql -v dataset=standard   (default benchmarks)
--         psql ... -f sql/seed.sql -v dataset=small      (quick validation)
-- Sizes:                                     small    standard
--   customers                                 1 000     100 000
--   products                                    200       5 000
--   orders                                   10 000   1 000 000
--   order_items   (uniform 1..4 items/order)  ~25 000  ~2 500 000
--
-- Determinism notes:
--   * setseed(0.42) pins the random() stream for the session.
--   * Row counts are fixed by :dataset; per-row assignments may differ
--     slightly across PostgreSQL major versions (documented limitation).
--   * orders.total_amount is recomputed from order_items so join
--     integrity checks can rely on exact equality.
--   * No psql metacommand conditionals are used: psql \if cannot compare
--     strings (Boolean expected), so size selection lives in SQL CASE.
--   * random() appears only in target lists. On this PostgreSQL build a
--     volatile expression in a join qual is evaluated once per statement
--     (observed), so per-row randomness must never sit in WHERE.
--   * Sequences are bumped after explicit-id inserts so later inserts
--     (experiment 05, write overhead) cannot collide.

\set ON_ERROR_STOP on
\timing on

-- Guards: refuse missing or invalid dataset names before touching data.
-- (psql does not interpolate variables inside dollar-quoted blocks, so the
-- validation value travels through a temp table, not a `:` substitution.)
CREATE TEMP TABLE _dataset_err AS
SELECT 'Pass -v dataset=small or -v dataset=standard (got: ' || :'dataset' || ')' AS msg
WHERE :'dataset' NOT IN ('small', 'standard');

DO $guard$
DECLARE m text;
BEGIN
    SELECT msg INTO m FROM _dataset_err LIMIT 1;
    IF m IS NOT NULL THEN
        RAISE EXCEPTION '%', m;
    END IF;
END
$guard$;

CREATE TEMP TABLE _lab_sizes AS
SELECT CASE :'dataset' WHEN 'standard' THEN 100000 ELSE 1000 END::bigint AS n_customers,
       CASE :'dataset' WHEN 'standard' THEN 5000   ELSE 200  END::bigint AS n_products,
       CASE :'dataset' WHEN 'standard' THEN 1000000 ELSE 10000 END::bigint AS n_orders;

SELECT setseed(0.42);

-- 1. customers ---------------------------------------------------------------
TRUNCATE order_items, orders, products, customers RESTART IDENTITY CASCADE;

INSERT INTO customers (id, full_name, email, city, created_at) OVERRIDING SYSTEM VALUE
SELECT g,
       (ARRAY['Ava','Liam','Noah','Emma','Olivia','Mia','Lucas','Emina','Souad','Idris',
              'Noor','Karim','Yuki','Chen','Alice','Bruno','Diego','Fatou','Hugo','Ines'])[1 + floor(random()*20)::int]
       || ' '
       || (ARRAY['Smith','Doe','Johnson','Lee','Garcia','Muller','Rossi','Traore','Kim','Nowak',
                 'Silva','Adamu','Okafor','Belkacem','Ndiaye','Fontaine','Moreau','Popov','Ito','Osei'])[1 + floor(random()*20)::int],
       'cust' || g || '@example.com',
       (ARRAY['Paris','Lyon','Marseille','Toulouse','Lille','Bordeaux','Nantes','Nice',
              'Douala','Yaounde','Dakar','Abidjan','Casablanca','Cairo','Lagos','Nairobi',
              'Berlin','Madrid','Rome','Lisbon'])[1 + floor(random()*20)::int],
       TIMESTAMPTZ '2023-01-01' + (random() * interval '365 days')
FROM generate_series(1, (SELECT n_customers FROM _lab_sizes)) g;

-- 2. products ---------------------------------------------------------------
INSERT INTO products (id, name, category, price, is_active) OVERRIDING SYSTEM VALUE
SELECT g,
       (ARRAY['Keyboard','Mouse','Monitor','Headset','Webcam','Dock','Laptop Stand','USB Hub',
              'Charger','Cable','Lamp','Alarm'])[1 + (g % 12)] || ' v' || (1 + (g / 1000)),
       (ARRAY['accessories','audio','displays','networking','power','desk-setup'])[1 + (g % 6)],
       round((random() * 1995 + 5)::numeric, 2),
       random() < 0.92
FROM generate_series(1, (SELECT n_products FROM _lab_sizes)) g;

-- 3. orders (skewed buyers: low ids are heavy customers) ---------------------
-- Expected shape (standard): customer 1 ~3 200 orders, the first 1 000
-- customers own ~100 000 orders, tail customers get ~5 each (alpha=2).
INSERT INTO orders (id, customer_id, status, total_amount, created_at) OVERRIDING SYSTEM VALUE
SELECT g,
       1 + floor(pow(random(), 2) * (SELECT n_customers FROM _lab_sizes))::bigint,
       CASE
           WHEN r < 0.45 THEN 'delivered'
           WHEN r < 0.65 THEN 'paid'
           WHEN r < 0.80 THEN 'shipped'
           WHEN r < 0.90 THEN 'cancelled'
           WHEN r < 0.95 THEN 'refunded'
           ELSE 'pending'
       END,
       0,
       TIMESTAMPTZ '2024-01-01' + (random() * interval '730 days')
FROM (SELECT g, random() AS r
      FROM generate_series(1, (SELECT n_orders FROM _lab_sizes)) g) s;

-- 3b. count scale notes: items-per-order slot expansion lives in step 4.

-- 4. order_items (uniform 1..4 items per order) ------------------------------
-- The per-order item count is materialised in a subselect target list;
-- never rely on volatile expressions inside join quals.
INSERT INTO order_items (id, order_id, product_id, quantity, unit_price) OVERRIDING SYSTEM VALUE
SELECT ROW_NUMBER() OVER () AS id,
       o.id,
       1 + floor(random() * (SELECT n_products FROM _lab_sizes))::bigint,
       1 + floor(random() * 4)::int,
       0
FROM (SELECT id, 1 + floor(random() * 4)::int AS n_items FROM orders) o
CROSS JOIN generate_series(1, 4) s
WHERE s <= o.n_items;

-- 5. Restore referential prices; reconcile totals to the cent ----------------
UPDATE order_items oi
SET    unit_price = p.price
FROM   products p
WHERE  p.id = oi.product_id;

UPDATE orders o
SET    total_amount = s.total
FROM   (SELECT order_id, round(SUM(quantity * unit_price), 2) AS total
        FROM order_items GROUP BY order_id) s
WHERE  o.id = s.order_id;

-- 6. Sequences past the explicit ids ------------------------------------------
SELECT setval(pg_get_serial_sequence('customers', 'id'),   (SELECT max(id) FROM customers));
SELECT setval(pg_get_serial_sequence('products', 'id'),    (SELECT max(id) FROM products));
SELECT setval(pg_get_serial_sequence('orders', 'id'),      (SELECT max(id) FROM orders));
SELECT setval(pg_get_serial_sequence('order_items', 'id'), (SELECT max(id) FROM order_items));

-- 7. Statistics + visibility map (needed before any benchmark!) --------------
VACUUM (ANALYZE) customers;
VACUUM (ANALYZE) products;
VACUUM (ANALYZE) orders;
VACUUM (ANALYZE) order_items;

\echo 'Seed complete.'
SELECT 'customers' AS table_name, count(*) FROM customers
UNION ALL SELECT 'products', count(*) FROM products
UNION ALL SELECT 'orders', count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items;
