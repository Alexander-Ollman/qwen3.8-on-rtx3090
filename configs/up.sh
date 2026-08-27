#!/usr/bin/env bash
# Bring up the full stack: both replicas + LB. Telemetry is separate (see README).
#   ./up.sh            start / reconcile with .env
#   ./up.sh --build    rebuild the image first
#   ./up.sh --wait     also block until both replicas answer /health
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
[ -f .env ] || { echo "no .env — cp .env.example .env and edit"; exit 1; }
# shellcheck disable=SC1091
set -a; . ./.env; set +a

[ "${1:-}" = "--build" ] && docker compose build && shift || true
mkdir -p logs data

echo "== bringing up (GPU0 spec='${GPU0_SPEC:-mtp}' ctx=${GPU0_CTX:-fast} | GPU1 spec='${GPU1_SPEC:-mtp}' ctx=${GPU1_CTX:-fast}) =="
docker compose up -d

if [ "${1:-}" = "--wait" ]; then
  for p in 18020 18021; do
    printf "waiting :%s " "$p"
    for _ in $(seq 1 150); do
      code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${VLLM_API_KEY}" \
             "http://127.0.0.1:$p/health" || true)
      [ "$code" = 200 ] && { echo "up"; break; }
      printf '.'; sleep 4
    done
    [ "${code:-}" = 200 ] || { echo " TIMEOUT — docker compose logs replica-gpu${p: -1}"; exit 1; }
  done
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${LB_PORT:-18000}/lb-health" || true)
  echo "LB :${LB_PORT:-18000} -> $code"
fi
echo "done. ./status.sh for detail."
