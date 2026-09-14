# shellcheck shell=bash
# bench: streaming throughput/TTFT, tool-calling check, sequential run continues past an error, --last from storage.
timeout 60 "$N" auto >/dev/null 2>&1   # deterministic slots regardless of state left by earlier suites

timeout 60 "$N" bench fast moonshotai/kimi-k2.6 >"$TMP/bench1.txt" 2>&1
check "bench: row for slot arg, nonzero tok/s, tokens, tools ok" \
  "deepseek-ai/deepseek-v4-flash-0731 +[0-9]+ +[1-9][0-9.]* +12 +✓" < "$TMP/bench1.txt"
check "bench: error row for dead model, run continues" "kimi-k2.6 +kein Endpoint" < "$TMP/bench1.txt"
check "bench: fastest model named" "Am schnellsten: deepseek-ai/deepseek-v4-flash-0731" < "$TMP/bench1.txt"
awk -F'\t' '$1=="deepseek-ai/deepseek-v4-flash-0731" && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9.]+$/ && $4=="12" && $5=="ok" && $6 ~ /^[0-9]+$/' "$TMP/home/bench" | grep -q . \
  && pass "bench: file has a row" || fail "bench: file has a row"

check "dashboard: footer lists bench key" "Modelle.*b Bench" < <(printf 'q\n' | timeout 30 "$N")
check "dashboard: b key runs bench (not 'unbekannte Taste')" "Am schnellsten" < <(printf 'b\n\nq\n' | timeout 90 "$N")

# prove --last needs no request: point this one call at a dead endpoint (never kill the shared mock – later cases need it)
check "bench --last: stored row without any request" \
  "deepseek-ai/deepseek-v4-flash-0731 +[0-9]+ +[1-9][0-9.]*" < <(NIMCTL_API_BASE=http://127.0.0.1:1/v1 timeout 10 "$N" bench --last fast)
