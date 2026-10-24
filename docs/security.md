# Security — the posture of this lab

## Credentials

- Real credentials live **only in `.env`**, which is `.gitignore`d (checked before every
  commit). `.env.example` documents the shape with `change_me`.
- The container user is `lab` — owner of one database (`perf_lab`) on an instance with
  zero other data. Compromising `.env` compromises a lab, not a product.
- `PGPASSWORD` is set per-shell (`export PGPASSWORD=$POSTGRES_PASSWORD`), never baked into
  scripts, shell history is avoided (`-X` for psql, no password CLI flags).

## Network exposure

- `docker-compose.yml` binds `127.0.0.1:5434`, so the lab DB is unreachable from any
  other machine. Exposing Postgres to LAN/WAN is out of scope for the lab and the
  compose file will not do it by itself.
- The image is **pinned by digest** (`postgres:18-alpine@sha256:…`), not by mutable tag:
  supply-chain surprise (a poisoned `18-alpine` push) cannot silently land here.
- `healthcheck` uses `pg_isready` — no shell-injection surface, no network attacker.

## Destructive paths

- `reset_database.sh` is the only data-wipe path; it requires `--yes` AND
  refuses to run unless `PGDATABASE=perf_lab` is in the environment.
- `cleanup.sql` only drops the six experiment index names; the destructive corner
  (tables/schema) is never in a SQL file the suite runs.

## Scope & caveats (honesty section)

- This is a teaching lab, not a hardened Postgres deployment: no TLS (loopback only),
  no host-level authentication beyond one DB user, no audit logging. Any of those needs
  a real ops pass before reuse in a shared environment.
- The seed data contains generated fake names/emails — no PII anywhere by construction.
