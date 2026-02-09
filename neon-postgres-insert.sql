-- ============================================================
-- Postgres practice dataset: 3 dimensions (200+ rows each)
-- and 1 fact table (~10,000 rows)
-- ============================================================
-- Run this whole script in psql / VS Code / any SQL client.
-- It is self-contained and deterministic-ish (seeded).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS new_dw;
-- Optional: put everything in a dedicated schema
CREATE SCHEMA IF NOT EXISTS demo_dw;
SET search_path = demo_dw;

-- Clean up (drop fact first because of FKs)
DROP TABLE IF EXISTS demo_dw.fact_sales CASCADE;
DROP TABLE IF EXISTS demo_dw.dim_date CASCADE;
DROP TABLE IF EXISTS demo_dw.dim_product CASCADE;
DROP TABLE IF EXISTS demo_dw.dim_customer CASCADE;

-- -------------------------
-- Dimension: Customer
-- 300 rows (>= 200)
-- -------------------------
DROP TABLE IF EXISTS demo_dw.dim_customer CASCADE;
CREATE TABLE demo_dw.dim_customer (
  customer_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_nk   TEXT NOT NULL UNIQUE,               -- natural/business key
  first_name    TEXT NOT NULL,
  last_name     TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  state         TEXT NOT NULL,
  segment       TEXT NOT NULL,                      -- e.g., Consumer/SMB/Enterprise
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------
-- Dimension: Product
-- 250 rows (>= 200)
-- -------------------------
CREATE TABLE demo_dw.dim_product (
  product_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_nk    TEXT NOT NULL UNIQUE,               -- natural/business key
  product_name  TEXT NOT NULL,
  category      TEXT NOT NULL,
  brand         TEXT NOT NULL,
  base_price    NUMERIC(10,2) NOT NULL CHECK (base_price > 0),
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------
-- Dimension: Date
-- 366 rows (>= 200) : a leap year range example (2024)
-- -------------------------
CREATE TABLE demo_dw.dim_date (
  date_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_date     DATE NOT NULL UNIQUE,
  day_of_week   INT  NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- ISO DOW (Mon=1..Sun=7)
  day_name      TEXT NOT NULL,
  month_num     INT  NOT NULL CHECK (month_num BETWEEN 1 AND 12),
  month_name    TEXT NOT NULL,
  quarter_num   INT  NOT NULL CHECK (quarter_num BETWEEN 1 AND 4),
  year_num      INT  NOT NULL,
  is_weekend    BOOLEAN NOT NULL
);

-- -------------------------
-- Fact: Sales (10,000 rows)
-- -------------------------
DROP TABLE IF EXISTS demo_dw.fact_sales CASCADE;
CREATE TABLE demo_dw.fact_sales (
  sales_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  date_id       INT NOT NULL REFERENCES demo_dw.dim_date(date_id),
  customer_id   INT NOT NULL REFERENCES demo_dw.dim_customer(customer_id),
  product_id    INT NOT NULL REFERENCES demo_dw.dim_product(product_id),
  order_id      TEXT NOT NULL,                      -- degenerate dimension
  quantity      INT NOT NULL CHECK (quantity > 0),
  unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
  discount_pct  NUMERIC(5,2) NOT NULL CHECK (discount_pct BETWEEN 0 AND 80),
  gross_amount  NUMERIC(12,2) NOT NULL CHECK (gross_amount >= 0),
  net_amount    NUMERIC(12,2) NOT NULL CHECK (net_amount >= 0),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ
);

-- Helpful indexes for typical star-schema queries
CREATE INDEX IF NOT EXISTS ix_fact_sales_date ON demo_dw.fact_sales(date_id);
CREATE INDEX IF NOT EXISTS ix_fact_sales_customer ON demo_dw.fact_sales(customer_id);
CREATE INDEX IF NOT EXISTS ix_fact_sales_product ON demo_dw.fact_sales(product_id);

-- ============================================================
-- Seed randomness (repeatable-ish per session)
-- ============================================================
SELECT setseed(0.4242);

-- ============================================================
-- Populate dim_date: 2024-01-01 .. 2024-12-31 (366 rows)
-- ============================================================
INSERT INTO demo_dw.dim_date (full_date, day_of_week, day_name, month_num, month_name, quarter_num, year_num, is_weekend)
SELECT
  d::date AS full_date,
  EXTRACT(ISODOW FROM d)::int AS day_of_week,
  TO_CHAR(d, 'FMDay') AS day_name,
  EXTRACT(MONTH FROM d)::int AS month_num,
  TO_CHAR(d, 'FMMonth') AS month_name,
  EXTRACT(QUARTER FROM d)::int AS quarter_num,
  EXTRACT(YEAR FROM d)::int AS year_num,
  (EXTRACT(ISODOW FROM d) IN (6,7)) AS is_weekend
FROM generate_series('2020-01-01'::date, '2027-12-31'::date, interval '1 day') AS d;

-- ============================================================
-- Populate dim_product: 250 rows
-- ============================================================
WITH
categories AS (
  SELECT ARRAY['Electronics','Home','Sports','Apparel','Beauty','Books','Toys','Grocery'] AS a
),
brands AS (
  SELECT ARRAY['Acme','Zenith','Nimbus','Atlas','Nova','Summit','Pioneer','Aurora'] AS a
),
base AS (
  SELECT
    gs,
    (('x' || substr(md5('cat-' || gs::text), 1, 8))::bit(32)::int) AS h_cat,
    (('x' || substr(md5('br-'  || gs::text), 1, 8))::bit(32)::int) AS h_br,
    (('x' || substr(md5('pr-'  || gs::text), 1, 8))::bit(32)::int) AS h_price,
    (('x' || substr(md5('ac-'  || gs::text), 1, 8))::bit(32)::int) AS h_active
  FROM generate_series(1, 2500) gs
),
picked AS (
  SELECT
    gs,
    -- pick a deterministic category/brand index
    1 + (abs(h_cat) % array_length(c.a, 1)) AS cat_i,
    1 + (abs(h_br)  % array_length(b.a, 1)) AS br_i,
    -- deterministic base price:
    -- map h_price into [5.00, 500.00] with 2 decimals
    round(
      (
        5::numeric +
        (
          (abs(h_price)::numeric % 49501::numeric) / 100::numeric
        )
      ),
      2
    ) AS base_price,
    -- deterministic is_active: ~97% active (inactive when mod 100 is 0,1,2)
    ((abs(h_active) % 100) >= 3) AS is_active
  FROM base
  CROSS JOIN categories c
  CROSS JOIN brands b
)
-- select * from picked;
INSERT INTO demo_dw.dim_product
  (product_nk, product_name, category, brand, base_price, is_active)
SELECT
  'PROD-' || LPAD(gs::text, 5, '0') AS product_nk,
  (br.a[br_i] || ' ' || cat.a[cat_i] || ' Item ' || gs::text) AS product_name,
  cat.a[cat_i] AS category,
  br.a[br_i]   AS brand,
  base_price,
  is_active
FROM picked
CROSS JOIN categories cat
CROSS JOIN brands br;


-- ============================================================
-- Populate fact_sales: 10,000 rows
-- Uses:
--  - random date/customer/product keys within existing ranges
--  - unit_price derived from product base_price with +-10% noise
--  - discount 0..30%
-- ============================================================
-- Get dimension counts to keep things robust if you tweak sizes

-- Replace the whole DO $$ ... $$ block with this:

INSERT INTO demo_dw.fact_sales (
  date_id, customer_id, product_id,
  order_id, quantity, unit_price, discount_pct, gross_amount, net_amount
)
WITH params AS (
  SELECT
    (SELECT COUNT(*) FROM demo_dw.dim_date)     AS v_dates,
    (SELECT COUNT(*) FROM demo_dw.dim_customer) AS v_custs,
    (SELECT COUNT(*) FROM demo_dw.dim_product)  AS v_prods
),
rows AS (
  SELECT
    1 + floor(random() * p.v_dates)::int AS date_id,
    1 + floor(random() * p.v_custs)::int AS customer_id,
    1 + floor(random() * p.v_prods)::int AS product_id,
    'ORD-' || LPAD((1 + floor(random() * 2500))::int::text, 6, '0') AS order_id,
    (1 + floor(random() * 5))::int AS quantity,
    (0.90::numeric + (random()::numeric * 0.20::numeric)) AS price_multiplier,
    (random()::numeric * 30::numeric) AS discount_pct_raw
  FROM generate_series(1, 200000) gs
  CROSS JOIN params p
),
priced AS (
  SELECT
    r.*,
    dp.base_price
  FROM rows r
  JOIN demo_dw.dim_product dp ON dp.product_id = r.product_id
),
calc AS (
  SELECT
    date_id, customer_id, product_id, order_id, quantity,
    round((base_price * price_multiplier)::numeric, 2) AS unit_price,
    round(discount_pct_raw, 2)                         AS discount_pct,
    round((quantity * (base_price * price_multiplier))::numeric, 2) AS gross_amount,
    round(
      (quantity * (base_price * price_multiplier) * (1 - (discount_pct_raw/100)))::numeric,
      2
    ) AS net_amount
  FROM priced
)
SELECT * FROM calc;

-- ============================================================
-- Populate dim_customer: 300 rows
-- ============================================================
-- Better dim_customer generator (300 rows, varied names)
DO $$
declare
    max_cust_id int;
    no_of_cust int = 20000;
BEGIN
    select COALESCE(max(customer_id),0)+1 into max_cust_id from demo_dw.dim_customer;

    WITH
    first_names AS (
      SELECT ARRAY[
        'Ava','Noah','Mia','Liam','Olivia','Ethan','Sophia','Lucas','Amelia','Mason',
        'Isla','Logan','Ella','James','Grace','Henry','Chloe','Jack','Zoe','Leo'
      ] AS a
    ),
    last_names AS (
      SELECT ARRAY[
        'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis','Rodriguez','Martinez',
        'Hernandez','Lopez','Gonzalez','Wilson','Anderson','Thomas','Taylor','Moore','Jackson','Martin'
      ] AS a
    ),
    states AS (
      SELECT ARRAY['CA','NY','TX','FL','WA','IL','MA','CO','AZ','GA'] AS a
    ),
    segments AS (
      SELECT ARRAY['Consumer','SMB','Mid-Market','Enterprise'] AS a
    ),
    base AS (
      SELECT
        gs,
        -- turn md5 hashes into integers, then mod by array lengths for stable indices
        (('x' || substr(md5('fn-' || gs::text), 1, 8))::bit(32)::int) AS h_fn,
        (('x' || substr(md5('ln-' || gs::text), 1, 8))::bit(32)::int) AS h_ln,
        (('x' || substr(md5('st-' || gs::text), 1, 8))::bit(32)::int) AS h_st,
        (('x' || substr(md5('sg-' || gs::text), 1, 8))::bit(32)::int) AS h_sg
      FROM generate_series(max_cust_id , max_cust_id + no_of_cust) gs
    )
    INSERT INTO demo_dw.dim_customer (customer_nk, first_name, last_name, email, state, segment)
    SELECT
      'CUST-' || LPAD(gs::text, 5, '0') AS customer_nk,
      f.a[1 + (abs(h_fn) % array_length(f.a, 1))] AS first_name,
      l.a[1 + (abs(h_ln) % array_length(l.a, 1))] AS last_name,
      LOWER(
        f.a[1 + (abs(h_fn) % array_length(f.a, 1))] || '.' ||
        l.a[1 + (abs(h_ln) % array_length(l.a, 1))] || '+' || gs::text || '@example.com'
      ) AS email,
      s.a[1 + (abs(h_st) % array_length(s.a, 1))] AS state,
      se.a[1 + (abs(h_sg) % array_length(se.a, 1))] AS segment
    FROM base
    CROSS JOIN first_names f
    CROSS JOIN last_names l
    CROSS JOIN states s
    CROSS JOIN segments se;
    -- RAISE NOTICE 'Max Cust ID is %', max_cust_id;
END
$$;