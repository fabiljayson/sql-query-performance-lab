#!/usr/bin/env bash
# scripts/reset_database.sh — destructive reset (volume wipe + re-seed).
#
# Safety:
#   * requires the explicit flag  --yes;
#   * refuses to run when PGDATABASE is not the lab database.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${PGDATABASE:-}" != "perf_lab" ]]; then
  echo "Refusing to run: PGDATABASE must be 'perf_lab' (offense = accidental blank)." >&2
  exit 1
fi
if [[ "${1:-}" != "--yes" ]]; then
  cat >&2 <<EOF
DESTRUCTIVE: this wipes the perf_lab volume (all data will be lost).
Re-run as:  ./scripts/reset_database.sh --yes [--small]
EOF
  exit 1
fi

shift || true
echo "==> docker compose down -v (removes the volume)." 
docker compose down -v

echo "==> Restarting the container and re-seeding…" 
./scripts/setup.sh "$@"
