# SQL Query Performance Lab

**Day 07 of my 30-day build series** — a reproducible PostgreSQL 18 playground for one
specific skill: reading `EXPLAIN ANALYZE` plans and proving when (and when *not*) an
index pays off. 1M deterministic rows in a Docker container, 5 self-contained
experiments, committed plan logs, and a pytest suite guarding the invariants.

No ORM, no framework — just SQL you can rerun line by line.

## Headline results (standard dataset, 1M orders, medians of 3 trials)

| Workload | Baseline | With index | Speed-up |
|---|---:|---:|---:|
| filter (status + month) | 78.1 ms | 20.1 ms | **×3.9** |
| lookup (customer, filter+sort) | 79.8 ms | **0.81 ms** | **×98** |
| join (customer → orders → items) | 365.6 ms | **2.6 ms** | **×139** |
| covering read | 103.7 ms → Index **Only** Scan | 57.7 ms | ×1.8 (then dropped — redundant) |
| partial index (336 kB — tiny) | 108.2 ms | 34.1 ms | **×3.2** |
| cost of indexes on writes | 247.4 ms / 5k INSERT | 315.7 ms | **+27.6 %** |

Full story with plan nodes and index footprints: [`docs/findings.md`](docs/findings.md).

## Quick start

```bash
cp .env.example .env          # then set POSTGRES_PASSWORD
./scripts/setup.sh            # container + schema + 1M-row deterministic seed (~5 min)
./scripts/run_benchmarks.sh   # the 5 experiments → results/run-<stamp>/
.venv/bin/pytest              # or: uv pip install -r requirements-dev.txt && pytest
```

Small-dataset preview (~10 s instead of ~5 min): `./scripts/setup.sh --small`
(experiment ratios survive, absolute times shrink).

Full teardown: `./scripts/reset_database.sh --yes` (gated by `--yes`, refuses without it).

## Where to look

| Path | What it is |
|---|---|
| `experiments/0N_*.sql` | 5 self-contained, rerunnable experiments; each: baseline ×3 → index → after ×3 → size report |
| `results/run-…/` | Committed plan logs for one full run (the numbers above come from there) |
| `docs/findings.md` | The measured story — which plan node changed and why |
| `docs/experiments.md` | The protocol: 3-trials rule, reading order for EXPLAIN, seed anchors |
| `docs/architecture.md` | One container, data flow, roles of every SQL file |
| `docs/troubleshooting.md` | Real build pitfalls (PG 18 mount path, psql `\if`, volatile `random()`) |
| `docs/security.md` / `docs/legal.md` | Credential/network posture; MIT, fully generated data |

## The one-paragraph takeaway

Indexes made reads up to **139× faster** here, but only *plan-shape changes* prove a
production-grade lesson — and every index charged a **+27.6 % write tax** that the
experiments measure instead of hand-wave. Two of them were dropped on purpose
(single-column redundant with a composite; a covering index duplicating another);
the final set is 4 indexes ≈105 MB for 1M orders (≈4 % of the table budget).

## Language

For the repo, code and comments are English; interaction notes, discussions, and
`docs/troubleshooting.md` remain beginner-friendly.

## License

MIT — see [LICENSE](LICENSE). All data generated; no personal information.
