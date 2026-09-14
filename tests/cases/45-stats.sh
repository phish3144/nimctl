# shellcheck shell=bash
# nimctl stats: synthetic litellm.log, text + --json report, no-data message, dashboard summary line.
LOG="$TMP/home/logs/litellm.log"
mkdir -p "$TMP/home/logs" "$TMP/home/run"
STARTED=$(date +%s); echo "$STARTED" >"$TMP/home/run/proxy.started"
cat >"$LOG" <<'EOF'
INFO:     127.0.0.1:51234 - "POST /v1/messages HTTP/1.1" 200 OK
INFO:     127.0.0.1:51235 - "POST /v1/messages HTTP/1.1" 200 OK
INFO:     127.0.0.1:51236 - "POST /v1/messages HTTP/1.1" 200 OK
INFO:     127.0.0.1:51237 - "POST /v1/messages HTTP/1.1" 200 OK
INFO:     127.0.0.1:51238 - "POST /v1/messages HTTP/1.1" 200 OK
INFO:     127.0.0.1:51239 - "POST /v1/messages HTTP/1.1" 200 OK
INFO:     127.0.0.1:51240 - "POST /v1/messages HTTP/1.1" 429 Too Many Requests
INFO:     127.0.0.1:51241 - "POST /v1/messages HTTP/1.1" 429 Too Many Requests
INFO:     127.0.0.1:51242 - "GET /health HTTP/1.1" 200 OK
LiteLLM Router: fallback triggered from nim-code to nim-fast
LiteLLM Router: Fallback: retrying request with nim-fast
Traceback (most recent call last):
EOF

# text report (German – default test locale)
check "stats: total requests" "Anfragen gesamt: 9" < <(timeout 20 "$N" stats)
check "stats: status classes" "2xx: 7 .* 4xx: 0 .* 429: 2 .* 5xx: 0" < <(timeout 20 "$N" stats)
check "stats: fallbacks" "Fallbacks: 2" < <(timeout 20 "$N" stats)
check "stats: rate-limited" "Rate-Limits: 2" < <(timeout 20 "$N" stats)
check "stats: errors" "Fehler: 1" < <(timeout 20 "$N" stats)
check "stats: since time" "seit [0-2][0-9]:[0-5][0-9]" < <(timeout 20 "$N" stats)
check "stats: top path /v1/messages with count 8" "8 +/v1/messages" < <(timeout 20 "$N" stats)
check "stats: top path /health with count 1" "1 +/health" < <(timeout 20 "$N" stats)
timeout 20 "$N" stats >/dev/null 2>&1; assert "stats exit code 0" [ $? -eq 0 ]

# --json report
J=$(timeout 20 "$N" stats --json)
check "stats --json: total" '"total": *9' < <(echo "$J")
check "stats --json: by_status" '"2xx": *7.*"429": *2' < <(echo "$J" | jq -c .requests.by_status)
check "stats --json: fallbacks/rate_limited/errors" '"fallbacks": *2' < <(echo "$J")
echo "$J" | jq -e '.fallbacks==2 and .rate_limited==2 and .errors==1' >/dev/null && pass "stats --json: counters" || fail "stats --json: counters"
echo "$J" | jq -e '.paths | length == 2' >/dev/null && pass "stats --json: paths array has 2 entries" || fail "stats --json: paths array has 2 entries"
echo "$J" | jq -e '.paths[0].path=="/v1/messages" and .paths[0].count==8' >/dev/null && pass "stats --json: top path sorted first" || fail "stats --json: top path sorted first"
echo "$J" | jq -e '.since|type=="number"' >/dev/null && pass "stats --json: since is numeric" || fail "stats --json: since is numeric"

# no data yet
: >"$LOG"
check "stats: no data" "noch keine Daten" < <(timeout 20 "$N" stats)
timeout 20 "$N" stats >/dev/null 2>&1; assert "stats exit code 0 without data" [ $? -eq 0 ]
rm -f "$LOG"
check "stats: missing log file" "noch keine Daten" < <(timeout 20 "$N" stats)
J2=$(timeout 20 "$N" stats --json); echo "$J2" | jq -e '.data==false' >/dev/null && pass "stats --json: no data" || fail "stats --json: no data"
timeout 20 "$N" stats --json >/dev/null 2>&1; assert "stats --json exit code 0 without log file" [ $? -eq 0 ]

# path sanitization: an attacker-controlled path must not reach out()'s `printf '%b'` unescaped (it would
# otherwise interpret backslash sequences like a real ANSI escape or `\c`, which truncates the printf call).
# Checked directly on raw output – NOT via check/nocheck, since run.sh's `strip` scrubs ANSI color codes
# before grep and would hide exactly the bytes this test needs to see.
echo "$STARTED" >"$TMP/home/run/proxy.started"
cat >"$LOG" <<'EOF'
INFO:     127.0.0.1:51234 - "POST /v1/\033[31mINJECTED\033[0m HTTP/1.1" 200 OK
INFO:     127.0.0.1:51235 - "GET /v1/\ccut HTTP/1.1" 200 OK
INFO:     127.0.0.1:51236 - "GET /health HTTP/1.1" 200 OK
EOF
OUT=$(timeout 20 "$N" stats)
printf '%s' "$OUT" | grep -qF "$(printf '\x1b')" && fail "stats: crafted path does not inject a real ANSI escape" || pass "stats: crafted path does not inject a real ANSI escape"
printf '%s\n' "$OUT" | grep -qE '^ *1 +/health *$' && pass "stats: row after a \\c path is not swallowed/merged" || fail "stats: row after a \\c path is not swallowed/merged"

# i18n
echo "$STARTED" >"$TMP/home/run/proxy.started"; cat >"$LOG" <<'EOF'
INFO:     127.0.0.1:51234 - "POST /v1/messages HTTP/1.1" 200 OK
EOF
check "stats: english" "requests total: 1" < <(NIMCTL_LANG=en timeout 20 "$N" stats)

# dashboard summary line (services may be down – stats only reads the file)
check "dashboard: stats summary shown" "Heute .*seit .*1 Anfragen.*0. 429.*0 Fallbacks" < <(printf 'q\n' | timeout 30 "$N")

# help text: the module's h_stats must win over the stale placeholder src/90-main.sh still carries (it
# mentions a "latency"/"Latenz" metric cmd_stats never computes) – see CONTRIBUTING.md build order.
check "help stats: module text, not the stale placeholder" "Status-Codes, Fallbacks, Rate-Limits" < <(timeout 20 "$N" help stats)
nocheck "help stats: no stale 'Latenz' placeholder" "Latenz" < <(timeout 20 "$N" help stats)
check "help: stats line uses module text" "stats .*Status-Codes, Fallbacks, Rate-Limits" < <(timeout 20 "$N" help)
nocheck "help: no stale 'Anfragen, 429, Fallbacks, Latenz' placeholder" "Anfragen, 429, Fallbacks, Latenz" < <(timeout 20 "$N" help)
check "help stats: english module text" "status codes, fallbacks, rate limits" < <(NIMCTL_LANG=en timeout 20 "$N" help stats)
nocheck "help stats: no stale english 'latency' placeholder" "429s, fallbacks, latency" < <(NIMCTL_LANG=en timeout 20 "$N" help stats)

# leave the log empty so later cases (none currently run after this one) are unaffected
: >"$LOG"
