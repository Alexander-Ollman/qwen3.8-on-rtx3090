#!/usr/bin/env bash
# Pre-flight checks. Run after every boot, before up.sh.
#
# The power cap is not optional: on 2026-08-22 GPU 0 hit Xid 79 ("GPU has fallen
# off the bus") under uncapped 350 W transients from a Triton autotuner, and only
# a reboot recovered it. 250 W cuts peak 12 V current ~29% and has been stable
# since, at a measured ~14% cost to unassisted decode (invisible on the vLLM path).
set -uo pipefail
CAP=${CAP_W:-250}
fail=0

say() { printf '%s %s\n' "$1" "$2"; }

echo "== GPU =="
if ! command -v nvidia-smi >/dev/null; then
  say "FAIL" "nvidia-smi not found"; exit 1
fi
if ! nvidia-smi -L >/dev/null 2>&1; then
  say "FAIL" "nvidia-smi cannot enumerate GPUs — check for Xid errors: dmesg | grep -i xid"
  exit 1
fi
nvidia-smi --query-gpu=index,name,memory.used,memory.total,power.limit,persistence_mode \
  --format=csv,noheader | sed 's/^/  /'

need_cap=0
while IFS=, read -r idx lim pm; do
  lim=${lim// /}; lim=${lim%%.*}; pm=${pm// /}
  [ "$lim" -gt "$CAP" ] && { say "WARN" "GPU $idx power limit ${lim}W > ${CAP}W"; need_cap=1; }
  [ "$pm" != "Enabled" ] && { say "WARN" "GPU $idx persistence mode $pm"; need_cap=1; }
done < <(nvidia-smi --query-gpu=index,power.limit,persistence_mode --format=csv,noheader,nounits)

if [ "$need_cap" = 1 ]; then
  echo
  say "ACTION" "power cap / persistence not set. This needs root:"
  echo "    sudo nvidia-smi -pl $CAP && sudo nvidia-smi -pm 1"
  if [ "${AUTO_SUDO:-0}" = 1 ]; then
    echo "  AUTO_SUDO=1 — prompting for sudo now:"
    sudo nvidia-smi -pl "$CAP" && sudo nvidia-smi -pm 1 || fail=1
  else
    fail=1
  fi
else
  say "OK" "both GPUs capped at <=${CAP}W with persistence on"
fi

echo "== Xid history (this boot) =="
if dmesg 2>/dev/null | grep -qi xid; then
  say "WARN" "Xid entries present:"; dmesg | grep -i xid | tail -5 | sed 's/^/  /'
else
  say "OK" "no Xid errors (or dmesg not readable without root)"
fi

echo "== Docker =="
docker info >/dev/null 2>&1 && say "OK" "docker reachable" || { say "FAIL" "docker unreachable"; fail=1; }
docker image inspect qwen38-27b-3090:latest >/dev/null 2>&1 \
  && say "OK" "image qwen38-27b-3090:latest present" \
  || { say "FAIL" "image missing — build it: cd \$REPO_DIR && docker build -t qwen38-27b-3090:latest ."; fail=1; }
docker volume inspect qwen38-rtx3090_qwen-cache >/dev/null 2>&1 \
  && say "OK" "JIT cache volume present (fast cold start)" \
  || say "WARN" "cache volume qwen38-rtx3090_qwen-cache missing — first start will be slow (~15 min)"
docker image inspect nginx:1.27-alpine >/dev/null 2>&1 \
  && say "OK" "nginx image present" \
  || say "WARN" "nginx:1.27-alpine not pulled — up.sh will pull it (needs network)"

echo "== Ports =="
for p in 18000 18020 18021; do
  owner=$(ss -tlnp 2>/dev/null | grep -E ":$p " | head -1)
  if [ -n "$owner" ]; then
    if echo "$owner" | grep -q docker-proxy; then say "OK" "port $p held by this stack"
    else say "WARN" "port $p held by something else:"; echo "    $owner"; fi
  else
    say "OK" "port $p free"
  fi
done

echo "== Disk =="
df -h "$HOME" | tail -1 | sed 's/^/  /'

echo
[ "$fail" = 0 ] && say "READY" "preflight passed" || say "BLOCKED" "resolve the FAIL/ACTION items above"
exit $fail
