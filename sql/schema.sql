-- sql/schema.sql — SQL Query Performance Lab schema
--
-- Rolling e-commerce sample schema. Deliberate choices (documented):
--   * bigint keys: 1 M+ rows per table make int-tight tables slow to evolve.
--   * Foreign keys are intentionally NOT indexed at baseline; creating and
--     measuring them is part of the experiments (03). Only constraints
--     that enforce integrity live in this file.
--   * created_at uses timestamptz so plan comparisons are timezone-proof.
--   * No value depends on clock time at seed time.

CREATE TABLE customers (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   text        NOT NULL,
    email       text        NOT NULL UNIQUE,
    city        text        NOT NULL,
    created_at  timestamptz NOT NULL
);

CREATE TABLE products (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        text        NOT NULL,
    category    text        NOT NULL,
    price       numeric(10, 2) NOT NULL CHECK (price >= 0),
    is_active   boolean     NOT NULL DEFAULT true
);

CREATE TABLE orders (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   bigint       NOT NULL REFERENCES customers (id),
    status        text         NOT NULL CHECK (
        status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled', 'refunded')),
    total_amount  numeric(12, 2) NOT NULL CHECK (total_amount >= 0),
    created_at    timestamptz  NOT NULL
);

CREATE TABLE order_items (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id    bigint    NOT NULL REFERENCES orders (id),
    product_id  bigint    NOT NULL REFERENCES products (id),
    quantity    integer   NOT NULL CHECK (quantity >= 1),
    unit_price  numeric(10, 2) NOT NULL CHECK (unit_price >= 0)
);
