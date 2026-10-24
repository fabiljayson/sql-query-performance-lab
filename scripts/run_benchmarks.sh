#!/usr/bin/env bash
# scripts/run_benchmarks.sh — run all 5 experiments end-to-end.
#
# Usage:
#   ./scripts/run_benchmarks.sh            # log everything into results/run-<ts>/
#
# For a clean baseline, phase 0 drops every experimental index
# (sql/cleanup.sql) before experiment 01 re-creates them one by one.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then echo "Missing .env (see .env.example)" >&2; exit 1; fi
set -a; source .env; set +a
export PGPASSWORD="$POSTGRES_PASSWORD"

STAMP=$(date -u '+%Y%m%d-%H%M%S')
OUT="results/run-$STAMP"
mkdir -p "$OUT"

PSQL=(psql -h 127.0.0.1 -p "${POSTGRES_PORT:-5434}" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -X -q -v ON_ERROR_STOP=1)

echo "==> Phase 0 — baseline cleanup (drops experimental indexes)."
"${PSQL[@]}" -f sql/cleanup.sql

for exp in 01_filter_queries 02_customer_lookup 03_join_queries 04_partial_indexes 05_write_overhead; do
  echo "==> $exp → $OUT/$exp.log"
  "${PSQL[@]}" -f "experiments/$exp.sql" 2>&1 | tee "$OUT/$exp.log"
done

echo ""
echo "All experiments done. Outputs in: $OUT/"
echo "Read docs/findings.md for the interpretation grid (medians, speeds, plan nodes)."
