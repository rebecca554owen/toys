#!/usr/bin/env bash
set -euo pipefail

# ppp-macos-bench.sh - PPP link bench test
# Usage: bash ppp-macos-bench.sh --rounds N --size N --proxy URL --host URL

ROUNDS="${PP_ROUNDS:-1000}"
SIZE="${PP_SIZE:-10}"
PROXY="${PPP_HTTP_PROXY:-http://127.0.0.1:7899}"
HOST="${SPEED_HOST:-http://192.168.100.10:8081}"
TIMEOUT="${PP_TIMEOUT:-30}"
INTERVAL="${PP_INTERVAL:-100}"
JSON="${PP_JSON:-}"
NO_PROGRESS="${PP_NO_PROGRESS:-no}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rounds) ROUNDS="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        --proxy) PROXY="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --json) JSON="$2"; shift 2 ;;
        --no-progress) NO_PROGRESS="yes"; shift ;;
        -h|--help) head -20 "$0" | sed 's/^#//'; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if ! curl -s -o /dev/null -m 3 -x "${PROXY}" "${HOST}/backend/garbage.php?ckSize=1" 2>/dev/null; then
    echo "ERROR: proxy ${PROXY} unreachable" >&2; exit 1
fi

echo ""
echo "PPP Link Bench"
echo "rounds=${ROUNDS} size=${SIZE}MB proxy=${PROXY} host=${HOST}"
echo ""

start=$(date +%s)
ok=0
fail=0
total_bytes=0
expected_bytes=$((SIZE * 1048576))

for ((i=1; i<=ROUNDS; i++)); do
    output=$(curl -s --show-error -m "${TIMEOUT}" -x "${PROXY}" -o /dev/null -w '%{http_code} %{size_download}' "${HOST}/backend/garbage.php?ckSize=${SIZE}" 2>/dev/null) || true
    rc=$?
    code=$(echo "${output}" | grep -o '^[0-9]*' || echo "000")
    bytes=$(echo "${output}" | grep -o '[0-9]*$' | tail -1 || echo "0")
    if [[ "${rc}" -eq 0 && "${code}" == "200" && "${bytes}" -ge "${expected_bytes}" ]]; then
        ok=$((ok+1)); total_bytes=$((total_bytes+bytes))
    else
        fail=$((fail+1)); echo "FAIL round=$i rc=$rc code=$code bytes=$bytes" >&2
    fi
    if [[ "${NO_PROGRESS}" != "yes" ]] && (( i % INTERVAL == 0 )); then
        echo "PROGRESS round=$i ok=$ok fail=$fail elapsed=$(( $(date +%s) - start ))s"
    fi
done

elapsed=$(( $(date +%s) - start ))
echo ""
echo "RESULT ok=$ok fail=$fail bytes=$total_bytes time=${elapsed}s"

if [[ -n "${JSON}" ]]; then
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf '{\n  "rounds": %d,\n  "size_mb": %d,\n  "proxy": "%s",\n  "host": "%s",\n  "ok": %d,\n  "fail": %d,\n  "total_bytes": %d,\n  "elapsed_s": %d,\n  "timestamp": "%s"\n}\n' \
        "${ROUNDS}" "${SIZE}" "${PROXY}" "${HOST}" "${ok}" "${fail}" "${total_bytes}" "${elapsed}" "${ts}" > "${JSON}"
    echo "Saved: ${JSON}"
fi

[[ "${fail}" -eq 0 ]] && exit 0 || exit 1
