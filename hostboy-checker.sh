#!/bin/sh
set -eu
: "${HOSTBOY_CHECKER_KEY:?Configure HOSTBOY_CHECKER_KEY}"
endpoint=${HOSTBOY_REPORT_URL:-}
case "$endpoint" in
  *\#*) echo 'Report URL must not include a fragment' >&2; exit 1 ;;
esac
case "$endpoint" in
  https://*)
    authority=${endpoint#https://}
    authority=${authority%%/*}
    case "$authority" in *@*) echo 'Report URL must not include user information' >&2; exit 1 ;; esac
    ;;
  http://*)
    authority=${endpoint#http://}
    authority=${authority%%/*}
    case "$authority" in
      127.0.0.1) ;;
      127.0.0.1:*)
        port=${authority#127.0.0.1:}
        case "$port" in ''|*[!0-9]*) echo 'Configure an HTTPS report URL' >&2; exit 1 ;; esac
        ;;
      *) echo 'Configure an HTTPS report URL' >&2; exit 1 ;;
    esac
    ;;
  *) echo 'Configure an HTTPS report URL' >&2; exit 1 ;;
esac
command -v curl >/dev/null 2>&1 || { echo 'curl is required' >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo 'sha256sum is required' >&2; exit 1; }
command -v awk >/dev/null 2>&1 || { echo 'awk is required' >&2; exit 1; }
command -v dd >/dev/null 2>&1 || { echo 'dd is required' >&2; exit 1; }
command -v date >/dev/null 2>&1 || { echo 'date is required' >&2; exit 1; }
command -v mktemp >/dev/null 2>&1 || { echo 'mktemp is required' >&2; exit 1; }
command -v od >/dev/null 2>&1 || { echo 'od is required' >&2; exit 1; }
command -v tr >/dev/null 2>&1 || { echo 'tr is required' >&2; exit 1; }
block=$(mktemp) || { echo 'Could not create a temporary benchmark file' >&2; exit 1; }
trap 'rm -f "$block"' EXIT HUP INT TERM
timestamp_ns() {
  value=$(date +%s%N 2>/dev/null || true)
  case "$value" in *N*|'') value=$(date +%s)000000000 ;; esac
  case "$value" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s' "$value"
}
elapsed_ms() {
  awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end-start)/1000000 }'
}
dd if=/dev/zero of="$block" bs=1048576 count=1 2>/dev/null || { echo 'Could not prepare the benchmark sample' >&2; exit 1; }
start=$(timestamp_ns)
i=0
while [ "$i" -lt 32 ]; do
  sha256sum "$block" >/dev/null
  i=$((i + 1))
done
end=$(timestamp_ns)
hash_ms=$(elapsed_ms "$start" "$end")
disk_ms=null
disk_start=$(timestamp_ns)
disk_ok=true
i=0
while [ "$i" -lt 8 ]; do
  if ! dd if=/dev/zero of="$block" bs=1048576 count=1 2>/dev/null ||
     ! dd if="$block" of=/dev/null bs=1048576 count=1 2>/dev/null; then
    disk_ok=false
    break
  fi
  i=$((i + 1))
done
disk_end=$(timestamp_ns)
if [ "$disk_ok" = true ]; then disk_ms=$(elapsed_ms "$disk_start" "$disk_end"); fi
request_id=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
payload=$(printf '{"runtime":"shell","schemaVersion":1,"version":"1.0.0","suite":"hostboy-v1","requestId":"%s","hashMs":%s,"diskMs":%s,"memoryLimitBytes":null,"availableParallelism":null}' "$request_id" "$hash_ms" "$disk_ms")
attempt=0
while :; do
  status=$(curl --silent --show-error --max-time 10 -o /dev/null -w '%{http_code}' -X POST "$HOSTBOY_REPORT_URL" \
    -H "Authorization: Bearer $HOSTBOY_CHECKER_KEY" -H 'Content-Type: application/json' \
    --data "$payload") && curl_status=0 || curl_status=$?
  case "$status" in
    2??) break ;;
    4??) echo "TheHostBoy report rejected (HTTP $status)" >&2; exit 1 ;;
  esac
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 3 ]; then
    [ "$curl_status" -eq 0 ] && echo "TheHostBoy report failed (HTTP $status)" >&2 || echo 'TheHostBoy report failed after retries' >&2
    exit 1
  fi
  sleep "$attempt"
done
printf '%s\n' 'TheHostBoy report accepted'
