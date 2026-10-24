---
name: sql-perf-lab
description: SQL Query Performance Lab work (PostgreSQL 18 Docker playground for EXPLAIN ANALYZE / index experiments). Use for ANY task under /home/fabiljayson/Projects/sql-query-performance-lab — covers container anatomy, experiment protocol, psql pitfalls and results-committing rules.
---

# SQL Query Performance Lab (Day 07)

Reproducible PostgreSQL 18 playground: read `EXPLAIN ANALYZE` plans and prove when (and when NOT) an index pays off. 1M deterministic orders in Docker, 5 self-contained experiments, committed plan logs, pytest guarding invariants. No ORM, no framework — raw SQL, rerun line by line.

## Environment & commands

```bash
cd sql-query-performance-lab
cp .env.example .env              # set POSTGRES_PASSWORD
./scripts/setup.sh                # container + schema + deterministic seed (~5 min; --small ≈ 10 s)
./scripts/run_benchmarks.sh       # 5 experiments → results/run-<stamp>/
.venv/bin/pytest                  # 11 read-only tests, adaptive skip standard/small
./scripts/reset_database.sh --yes # full teardown (refuses without --yes)
```

Container: `postgres:18-alpine` pinned by digest at 127.0.0.1:**5434**, data mounted at `/var/lib/postgresql` (PG18, NOT `/var/lib/postgresql/data`), `shared_buffers=512MB`, creds in `.env`.

## Scripted protocol

- 3-trials-median rule (`EXPLAIN ANALYZE BUFFERS`), seed anchored `setseed(0.42)`, skew `pow(random(),2)`.
- Each experiment re-runs from scratch: it starts with `DROP INDEX IF EXISTS`. Keep experiments self-contained.
- `results/` is gitignored EXCEPT the canonical committed run + `latest_run.txt` — don't bulk-commit new runs.
- Code and comments in English; keep `docs/troubleshooting.md` beginner-friendly.

## Documented traps

- psql `\if` rejects a lone boolean (route strings via temp tables `\gexec`); no psql var interpolation inside `$` blocks.
- `random()` is volatile, evaluated once per statement (PG 18.6) → materialize base data in a sub-select.
- Sequences are **non-transactional**: a ROLLBACK after INSERT leaves gaps → tests assert `>=`, not `>`.
- All PKs are literally `id`; index names only exist in the `pg_indexes` view (`indexname` column), not in table queries.
- GitHub lesson: API payloads where `exclude` is required-but-empty must go through `--input` JSON (flat `-f exclude[]=""` gets ignored).
