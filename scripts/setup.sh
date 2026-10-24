#!/usr/bin/env bash
# scripts/setup.sh — start the lab and load a deterministic dataset.
#
# Usage:
#   ./scripts/setup.sh              # standard dataset  (1M orders, ~5 min)
#   ./scripts/setup.sh --small      # small dataset     (10k orders, ~10 s)
#
# Stop conditions: a container that is already healthy, a dataset flag
# handled once, ON_ERROR_STOP on any SQL failure. Credentials come
# from .env (never committed; .env.example documents the layout).

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example and set POSTGRES_PASSWORD:" >&2
  exit 1
fi

DATASET="standard"
DJANGO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --small) DATASET="small"; shift ;;
    --standard) DATASET="standard"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "==> Starting PostgreSQL 18 container..."
docker compose up -d --wait > /dev/null

echo "==> Schema clean start (drops script_* if re-run)."
until docker compose exec -T postgres pg_isready -U lab -d perf_lab -q; do
  sleep 2
done

set -a; source .env; set +a
export PGPASSWORD="$POSTGRES_PASSWORD"

PSQL=(psql -h 127.0.0.1 -p "${POSTGRES_PORT:-5434}" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -X -v ON_ERROR_STOP=1)

echo "==> Loading schema (sql/schema.sql)..."
"${PSQL[@]}" -f sql/schema.sql > /dev/null

echo "==> Loading deterministic seed ($DATASET)…"
if [[ "$DATASET" == "small" ]]; then
  psql -h 127.0.0.1 -p "${POSTGRES_PORT:-5434}" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -X \
      -v ON_ERROR_STOP=1 -v dataset=small -f sql/seed.sql > /dev/null
else
  "${PSQL[@]}" -f sql/seed.sql > /dev/null
fi

echo "==> Verification."
"${PSQL[@]}" -c "SELECT (SELECT count(*) FROM customers) AS customers,
                        (SELECT count(*) FROM orders)    AS orders,
                        (SELECT count(*) FROM order_items) AS order_items;"

echo "==> Setup complete. Run ./scripts/run_benchmarks.sh next."
