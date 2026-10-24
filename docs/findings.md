# Findings — what the lab actually measured

Everything below comes from the committed run in `results/run-20261024-171017/`
(standard dataset: 100 000 customers, 1 000 000 orders, 2 500 112 order_items;
PostgreSQL 18.6-alpine, `shared_buffers=512MB`, default `max_parallel_workers_per_gather=2`).
Each number is the **median of 3 trials** of `EXPLAIN (ANALYZE, BUFFERS)`.

## Headline table

| # | Workload | Baseline plan | Baseline | After plan | After | Speed-up | Index cost |
|---|----------|---------------|---------:|-----------:|------:|---------:|-----------:|
| 1 | Q1 filter (status + month) | Parallel Seq Scan + Sort | 78.1 ms | Bitmap Index → Heap Scan + Sort | 20.1 ms | **×3.9** | 35 MB |
| 2 | Q2 customer lookup (filter+sort) | Parallel Seq Scan + Sort | 79.8 ms | Bitmap Index Scan | **0.81 ms** (composite) | **×98** | 30 MB |
| 3a | Q3 join (customer → orders → items) | Seq Scan over 2.5M items, hash join | 365.6 ms | Nested Loop + Index Scan on FK | **2.6 ms** | **×139** | 39 MB |
| 3b | Q3-covering (customer + total only) | Seq Scan | 103.7 ms | **Index Only Scan** | 57.7 ms | **×1.8** | 40 MB* |
| 4 | Q4 operational pending+recent | Parallel Seq Scan | 108.2 ms | Bitmap on partial index | **34.1 ms** | **×3.2** | **336 kB** |
| 5 | INSERT of 5 000 rows | Heap only | 247.4 ms | Heap + 4 indexes | 315.7 ms | — | **+27.6 %** |

\* measured ad hoc (the covering index is created, benchmarked, then deliberately dropped inside experiment 03; the size block printed only the FK index).

## Index 01 — composite on (status, created_at)

- Baseline: parallel Seq Scan touching all 1M rows even though the month of Nov 2025
  holds only ~8 200 `paid` rows; then a Sort.
- After: `Bitmap Index Scan → Bitmap Heap Scan`; readers skip
  ~5 338 exact heap blocks instead of paging through a 134 MB table.
- Read as a ratio, not as an absolute: on this 1M-row dataset the whole scan was only
  78 ms — but the *plan shape* is the lesson: it stays Seq Scan (linear)
  vs Bitmap (hit ~0.8 % of rows).
- Planner estimate 8 117 vs actual 8 180 rows (0.8 % off): stats are fresh
  (`ANALYZE` in the experiment), so estimation noise is small — a deliberate
  teaching point for reading rows misestimates.

## Index 02 — single-column vs composite (customer_id)

- Single `(customer_id)`: **1.01 ms** (already ×79 vs baseline).
- Composite `(customer_id, created_at DESC)`: **0.81 ms** median — slightly faster on the
  filter+sort variant *and* replaces two different index shapes by one.
- The composite subsumes the single-column index, so the experiment **drops the single-column
  one on purpose**: never keep both (duplicated storage, duplicated write amplification).

## Index 03 — the missing-FK-index join (the systemic classic)

- Baseline: the planner had no index on `order_items.order_id` → hash join driven by a
  parallel Seq Scan over all 2.5M items — 365 ms even for one customer.
- After FK index: Nested Loop; `Index Scan on idx_order_items_order_id`, ~2.5 items/order
  over 248 orders of this customer — **139× faster and thousands of times less data touched**.
- The covering variant demonstrated an actual **Index Only Scan** (27.6 ms worth of pages
  vs 57.7 ms total for the customer's state) — but that benefit coexisted with an index
  duplicating `(customer_id, created_at)` from experiment 02 for +40 MB. So it is dropped
  with the lesson: *covering indexes pay only when the SELECT column list is very stable*.

## Index 04 — partial index (the 336 kB hero)

- `WHERE status='pending' AND created_at >= '2025-06-01'` benchmarks at **34 ms vs 108 ms**,
  holding only ~14.5k rows — the index is **336 kB**, i.e. **0.25 %** of the 134 MB orders table.
- Correctness demo (phase 3): widened query (one year back) **ignores** the partial index
  (Seq Scan, 128 ms) because its predicate no longer implies the partial predicate. This is
  the “drop silently missing” moment learners must see.
- Composite `(status, created_at)` (restored in phase 4) handles the broad query at 79 ms —
  complementing, not replacing, the specialized partial.

## Index 05 — the honest bill: writes

- Same 5 000-row INSERT, rolled-back transactions (so data volume never changes): bare
  median **247.4 ms** → **315.7 ms** with the retained index set: **+27.6 % per batch**
  (~+68 ms of pure index maintenance per 5 000 rows).
- Deliberate teaching point: the absolute tax looks small on a lab dataset — the meaningful
  rule is that every index added becomes a recurring, near-constant write tax that no
  one-shot read benchmark can retro-justify.
- For the retained set: per-index listing (35 MB + 30 MB + 39 MB + 336 kB) totals ~105 MB for
  1M orders — 4 % of the dataset is spent on indexing, traded for ×4–139 read wins.

## What to read in every plan in results/

- `Execution Time` — the whole truth under ANALYZE.
- `Buffers: shared hit/read` — what pages the query *actually touched*,
  regardless of timing noise (the stable metric on a shared laptop).
- `rows=... loops=...` — per-row loops multiply: for exp. 03a, 248 loops ×
  `rows=2.49` — the Nested Loop cost budget.
- Worker line (Parallel …) — scans were parallelized over 2 workers, spreading the
  baseline scan — but it still scanned *all* rows, hence still 8–10× slower.
- Rows est. vs actuals drifting wide is precisely what makes ANALYZE non-optional.

## Reproducing

```bash
./scripts/setup.sh            # 1M orders, deterministic
./scripts/run_benchmarks.sh   # → fresh results/run-<stamp>/
uv run --with-requirement requirements-dev.txt pytest   # or: .venv/bin/pytest
```

Then diff your JSON of Execution Times against the headline table above — small absolute
numbers will differ (CPU/I/O), the **plan-shape changes and ratios** will not.
