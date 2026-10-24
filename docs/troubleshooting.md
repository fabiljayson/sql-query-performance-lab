# Troubleshooting — everything that bit during the build, and the fix

Each item below actually happened once. The lab scripts already contain the fix;
entries exist so a reader who trips on the same wire recognizes it.

## Container / image

**"the database files are incompatible with this server"** or healthcheck never goes green.
PG 18 images mount the data dir at `/var/lib/postgresql` (this was different in 16/17).
Wrong mount point = server boots an empty datadir. Fix: volume → `/var/lib/postgresql`
in `docker-compose.yml`; if it happened, `docker compose down -v` and start again.

**Port already in use.** The lab listens only on `127.0.0.1:5434`. Change
`POSTGRES_PORT` in `.env` and `docker-compose.yml` together; both scripts read the same var.

**Version mismatch symptoms** (e.g. a stale volume from an older postgres image).
`docker compose down -v` — the lab dataset is meant to be disposable.

## psql scripting

**`\if` prints "Boolean expected \if 'standard' == 'standard'"** — psql cannot compare strings.
Use a temp table + `\gexec` (that is what `sql/seed.sql` uses to branch dataset sizes).

**Variables are NOT interpolated inside dollar-quoted blocks** (`DO $$…$$`).
Because single-quoted psql vars remain literal there, guards pass values through
temp tables rather than string-building DDL.

**Volatile functions in join filters behave per statement, not per row**:
`SELECT … WHERE floor(random()) = o.fk` computed `random()` once for the whole statement
(PG 18.6). Per-row randomness belongs in a target list inside a materialized subselect
(`SELECT random() AS r FROM generate_series(…)`), then a non-volatile `WHERE` on `r` —
exactly the shape `seed.sql` and exp. 05 use.

**`GENERATED ALWAYS AS IDENTITY` rejects explicit ids** — navigation inserts need
`OVERRIDING SYSTEM VALUE`. As a rule the lab never inserts explicit ids anywhere.

**psql has no `\exit`** (that's SQLite) — send `\q`. Comments in query labels use `--`,
never `#` (psql treats `#` as… nothing you want mid-query).

## Benchmark hygiene, seen in the field

**Timings vary ±20 % between identical trials on a laptop.** Use the 3-trial median,
prefer `Buffers` over wall-clock for stable claims, and close the CPU-hungry browser
before a measured run.

**Rolled-back inserts still bump sequences** — Postgres sequences are not transactional.
After exp. 05 you'll see `orders_id_seq` ahead of `max(id)`: that is correct and it is why
`test_sequences_are_ahead_of_max_ids` asserts `>=`, not `>`.

**Query instantly fast because the connection is warm.** A first cold-cache trial
dominates naive timing; that's why a phase repeats the same query 3× and reports medians.

**Numbers are hardware-shaped.** Absolute milliseconds differ per machine — the *plan
nodes* and ratios (results committed in `results/`) are the reproducible claims.
