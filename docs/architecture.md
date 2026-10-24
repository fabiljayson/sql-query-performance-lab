# Architecture — one container, reproducible SQL, no magic

```
┌───────────────────────────────────────────────────────────────┐
│ sql-query-performance-lab/                                    │
│                                                               │
│  docker-compose.yml                                           │
│    postgres:18-alpine (digest-pinned)                          │
│    port 127.0.0.1:5434  · healthcheck pg_isready               │
│    named volume perf_lab_pgdata → /var/lib/postgresql          │
│                                                               │
│  sql/                     experiments/                         │
│   schema.sql   (tables+constraints, PKs via identity)          │
│   seed.sql     (deterministic, guardrails, skew)               │
│   indexes.sql   ──┐        01 filter_queries                   │
│   advanced_indexes │        02 customer_lookup                 │
│   cleanup.sql   ──┘        03 join_queries                     │
│                            04 partial_indexes                  │
│  scripts/                  05 write_overhead                   │
│   setup.sh · run_benchmarks.sh · reset_database.sh             │
│                                                               │
│  tests/ (pytest + psycopg3)   results/ (committed plan logs)   │
└───────────────────────────────────────────────────────────────┘
```

## Data flow (standard dataset)

`setup.sh`
→ `docker compose up -d --wait` (health-checked)
→ `schema.sql`: 4 tables, constraints only — **no non-PK index exists yet** (that's the lab).
→ `seed.sql`: `setseed(0.42)` + 730-day fixed window + skew `pow(random(),2)`
   · customers 100 000 · products 5 000 · orders 1 000 000 (≈3.2k for the hot customer)
   · order_items ≈ 2.5M (1–4/order) · `VACUUM ANALYZE`.
→ Invariants tested by pytest (11 tests).

`run_benchmarks.sh`
→ phase 0: `cleanup.sql` (all experiment indexes gone ⇒ honest baseline)
→ experiments 01→05 run sequentially; every output is `tee`'d into
  `results/run-<utc stamp>/0N_*.log`, the run you then read with `docs/findings.md`.

`reset_database.sh --yes`
→ `docker compose down -v` (wipes the volume), then full `setup.sh` again —
  the only intentionally destructive path, double-gated (`--yes` + PGDATABASE check).

## Roles of the two "tooling" SQL files

- `sql/indexes.sql` — recreated *retained* set (identical DDL text as the experiments use),
  safe to apply to any copy of the schema.
- `sql/advanced_indexes.sql` — the two *transient demo* indexes (single-column, covering),
  documented for manual exploration; the suite drops both on purpose.
- `sql/cleanup.sql` — drops the six experiment-owned index names only; never touches data.

## What is deliberately NOT here

- No ORM, no n-tier app skeleton: the query behavior *is* the payload.
- No CI runner matryoshka: Postgres in Docker is the single moving part.
- No silent benchmark averaging: everything is `EXPLAIN ANALYZE` + `tee`.
