# Experiment protocol — how the suite is built and why

## Structure of an experiment file

Every `experiments/0N_*.sql` is **self-contained and re-runnable**:

1. `\set ON_ERROR_STOP on` — a failed phase stops the file, never half-experiments.
2. `\timing on` + `\pset pager off` — wall clock printed, no pager eating output in scripts.
3. **Phase 1 — baseline**: the query is run **3×** under `EXPLAIN (ANALYZE, BUFFERS)`
   *before* any index exists (or after explicitly dropping one).
4. **Phase 2 — change**: `CREATE INDEX …` + `ANALYZE`, then the exact same query again ×3.
5. **Size report**: `pg_relation_size` for every index created in the file, so the
   "speed × footprint" trade is visible, not vibe.

Rerunning an experiment is always safe: every experiment starts with
`DROP INDEX IF EXISTS` for the indexes it owns, so trial 1 is a clean baseline again.

## The 3-trials rule

A single `EXPLAIN ANALYZE` run is noisy (cold cache, CPU jitter). Three trials give you
a cheap median that is stable enough to compare plan shapes; where a phase shows a
documented plan *switch* (e.g. broad query in exp. 04), the switch itself is a result.

## What EXPLAIN tells you — reading order

1. **Plan nodes top-down**: sort, join type, scan type. The scan node answers
   "index or seq?" — the join node answers "loop or hash?".
2. **`Execution Time`** (bottom line): the only number under `ANALYZE` that includes
   everything the plan did.
3. **`Buffers: shared hit/read`**: pages touched. On a shared laptop this is the most
   stable metric — hit count is reproducible, wall clock is not.
4. **`rows=` est. vs actual**: drift means stats drift; big drift is why `ANALYZE` exists.
5. **`loops=`**: in Nested Loops the per-iteration cost hides here; multiply mentally.

## Anchors used in the seed

- Customer ids are skewed: `1 + floor(pow(random(), 2)*n)` — ~0.5 % of customers hold
  2–3× the average orders. Without skew, "hot row" lessons stay invisible.
- Dates are a **fixed** window (`2024-01-01` + 730 d), never `now()` — a rerun next month
  must produce the same numbers, and month-bounded queries must not silently
  fall out of the data.
- `random()` is pinned with `setseed()` per phase in the deterministic parts; trial
  inserts in exp. 05 use their own pinned seeds per trial number.
- `orders.total_amount` is recomputed from `order_items` so money never diverges —
  tested (`test_total_amount_matches_items`).

## Deviations & their reasons (recorded around the lessons)

- Every experiment executes its own query text; `sql/baseline_queries.sql` documents the
  canonical text as a **reference only**, so phase labels and IF-resets stay coherent
  inside a single file.
- The covering index in exp. 03 is created → benchmarked → **dropped in the same file**;
  its final size was therefore measured ad hoc after the run (40 MB — see findings).
- Experiment 05 uses `BEGIN; … EXPLAIN ANALYZE INSERT …; ROLLBACK;`: `EXPLAIN ANALYZE`
  *executes* inserts inside the plan, so rollback is what keeps the lab dataset frozen.

## Pitfalls that shaped the lab (live lessons, not theory)

- psql `\if` only tests booleans — string guards must flow through temp-tables in `\gexec` SQL.
- `$DOLLAR_QUOTED$ DO blocks do not interpolate psql variables` — guards pass values via
  temp tables instead.
- A volatile `random()` in a join filter is evaluated **once per statement** (PG 18.6);
  per-row randomness lives in target lists of a materialized subselect.
- PG 18 docker images expect the data dir mounted at `/var/lib/postgresql`
  (not the older `/data`) — mount wrongly and the container's healthcheck lies.

All of these are defeated by the current scripts — that's why `troubleshooting.md`
references them as solved, and the suite reruns green end-to-end.
