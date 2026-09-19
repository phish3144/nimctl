# shellcheck shell=bash
# Web UI: files written, the real stdlib server up, token and Host checks, state/stats/candidates endpoints, settings
# and candidates written and honoured by nimctl, a command streamed as SSE, secrets through stdin, an exact pick,
# finds outside the rankings (discover) and their take-over (discovered), log tail and stream, dashboard/status rows, disable.
timeout 30 "$N" stop >/dev/null 2>&1
check "web start: server up on its port" "Web-UI läuft +http://localhost:$WP" < <(timeout 60 "$N" web start 2>&1)
TOKEN=$(cat "$TMP/home/web/token"); H="X-Nimctl-Token: $TOKEN"; U="http://127.0.0.1:$WP"
[[ $(stat -c %a "$TMP/home/web/token") == 600 ]] && pass "web: token file 600" || fail "web: token file 600"
python3 -m py_compile "$TMP/home/web/server.py" 2>/dev/null && pass "web: server.py written and compiles" || fail "web: server.py written and compiles"
assert "web: API refuses a request without the token (403)" [ "$(curl -s -o /dev/null -w '%{http_code}' "$U/api/state")" = 403 ]
assert "web: API refuses a foreign Host header (403)" [ "$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: evil.example' -H "$H" "$U/api/state")" = 403 ]
assert "web: page served with the token, placeholder replaced" [ "$(curl -s "$U/" | grep -c __TOKEN__)" = 0 ]
check "web: page carries the language" '<html lang="de">' < <(curl -s "$U/")
check "web: state has version and slots" '"version":"[0-9.]+","code":"deepseek-ai/deepseek-v4-pro-0813"' < <(curl -s -H "$H" "$U/api/state" | jq -c '{version, code: .slots.code.model}')
check "web: state lists the settings nimctl reads and masks the key" '"NIMCTL_RPM".*"nvapi-…tkey"' < <(curl -s -H "$H" "$U/api/state" | jq -c '{k: .settings_keys, key: .config.nvidia_key}')
check "web: stats endpoint" '"data":false|"requests"' < <(curl -s -H "$H" "$U/api/stats" | jq -c .)
check "web: candidates endpoint shows the ranking" '"code":"deepseek-v4-pro kimi-k2 gemini:gemini' < <(curl -s -H "$H" "$U/api/candidates" | jq -c .)
check "web: settings saved" '"NIMCTL_STALL_TIMEOUT": "120"' < <(curl -s -H "$H" -d '{"settings":{"NIMCTL_STALL_TIMEOUT":"120"}}' "$U/api/settings")
grep -qx 'NIMCTL_STALL_TIMEOUT=120' "$TMP/home/settings" && [[ $(stat -c %a "$TMP/home/settings") == 600 ]] && pass "web: settings file written, 600" || fail "web: settings file written, 600"
check "web: a setting value with shell characters is refused" '"error": "bad setting' < <(curl -s -H "$H" -d '{"settings":{"NIMCTL_RPM":"40; rm -rf /"}}' "$U/api/settings")
check "settings file: nimctl reads it (stall timeout in the pool hint)" "für 120s" < <(timeout 20 "$N" pool 2>&1)
check "settings file: an environment variable wins" "für 7s" < <(NIMCTL_STALL_TIMEOUT=7 timeout 20 "$N" pool 2>&1)
check "web: run streams the output and an exit event" 'data: " ?nimctl · NVIDIA NIM.*event: exit.*"rc": [0-9]' < <(curl -s -N -H "$H" -d '{"args":["status"]}' "$U/api/run" | tr '\n' ' ')
check "web: interactive commands are refused" '"command not allowed"' < <(curl -s -H "$H" -d '{"args":["code"]}' "$U/api/run")
check "web: the key goes in through stdin, never argv" "gleicher Key|gültig – gespeichert" < <(curl -s -N -H "$H" -d '{"args":["key"],"stdin":"nvapi-testkey"}' "$U/api/run")
check "web: pick with an exact id sets the slot without a list" "fast → nvidia/nemotron-3.5-lightning-30b-a3b" < <(curl -s -N -H "$H" -d '{"args":["pick","fast","nvidia/nemotron-3.5-lightning-30b-a3b"]}' "$U/api/run")
grep -q '^MODEL_FAST=nvidia/nemotron-3.5-lightning-30b-a3b$' "$TMP/home/config" && pass "web: exact pick saved" || fail "web: exact pick saved"
check "web: candidates written to the file" '"code": "glm-5 deepseek-v4-pro"' < <(curl -s -H "$H" -d '{"candidates":{"code":"glm-5 deepseek-v4-pro"}}' "$U/api/candidates")
grep -qx 'code: glm-5 deepseek-v4-pro' "$TMP/home/candidates" && pass "web: candidates file" || fail "web: candidates file"
check "candidates file: nimctl uses it" '"code":"glm-5 deepseek-v4-pro"' < <(curl -s -H "$H" "$U/api/candidates" | jq -c .)
# finds outside the rankings (scan results from 23-scan: deepseek-v4-flash answers with tools and sits in no code pattern)
check "web discover: finds per slot plus the filters the page mirrors" '^\{"flash":true,"slots":\["code","fast","chat","review"\],"nc":"embed\|","small":"\('  < <(timeout 60 "$N" web discover | jq -c '{flash: (.found.code | index("deepseek-ai/deepseek-v4-flash-0731") != null), slots: (.found | keys_unsorted), nc: .not_chat[0:6], small: .small[0:2]}')
check "web: discover endpoint" '^true$' < <(curl -s -H "$H" "$U/api/discover" | jq -c '.found.code | index("deepseek-ai/deepseek-v4-flash-0731") != null')
check "web: discovered saved" '"code": \["deepseek-ai/deepseek-v4-flash-0731"\]' < <(curl -s -H "$H" -d '{"discovered":{"code":["deepseek-ai/deepseek-v4-flash-0731"]}}' "$U/api/discovered")
grep -qx 'code: deepseek-ai/deepseek-v4-flash-0731' "$TMP/home/discovered" && pass "web: discovered file" || fail "web: discovered file"
check "discovered file: nimctl appends it to the ranking" '"code":"glm-5 deepseek-v4-pro deepseek-ai/deepseek-v4-flash-0731"' < <(curl -s -H "$H" "$U/api/candidates" | jq -c .)
check "web: state carries the taken-over models" '"discovered":\{"code":\["deepseek-ai/deepseek-v4-flash-0731"\]\}' < <(curl -s -H "$H" "$U/api/state" | jq -c '{discovered}')
check "web: a taken-over model leaves the finds" '^false$' < <(curl -s -H "$H" "$U/api/discover" | jq -c '.found.code | index("deepseek-ai/deepseek-v4-flash-0731") != null')
check "web: a bad model id is refused" '"error": "bad discovered code"' < <(curl -s -H "$H" -d '{"discovered":{"code":["x; rm -rf /"]}}' "$U/api/discovered")
check "web: an unknown slot is refused" '"error": "bad discovered foo"' < <(curl -s -H "$H" -d '{"discovered":{"foo":["a/b"]}}' "$U/api/discovered")
curl -s -H "$H" -d '{"discovered":{"code":[]}}' "$U/api/discovered" >/dev/null
[[ -s "$TMP/home/discovered" ]] && fail "web: an empty list removes the line" || pass "web: an empty list removes the line"
check "web: log tail" '"name": "web"' < <(curl -s -H "$H" "$U/api/log?name=web&n=5")
check "web: log stream takes the token in the query (EventSource has no headers)" 'nimctl web UI on' < <(timeout 3 curl -s -N "$U/api/log/stream?name=web&token=$TOKEN")
check "status: web row" "Web-UI +✓ läuft +:$WP" < <(timeout 20 "$N" status)
check "status --json: web block" '"web":\{"enabled":true,"up":true' < <(timeout 20 "$N" status --json | jq -c .)
check "logs: web log" "nimctl web UI on" < <(timeout 10 "$N" logs web)
check "web disable" "Web-UI deaktiviert" < <(timeout 30 "$N" web disable 2>&1)
grep -q '^WEB_ENABLED=0$' "$TMP/home/config" && pass "web: disabled in the config" || fail "web: disabled in the config"
assert "web: server stopped" [ "$(curl -s -o /dev/null -w '%{http_code}' -m 2 "$U/health")" != 200 ]
rm -f "$TMP/home/settings" "$TMP/home/candidates" "$TMP/home/discovered"; timeout 60 "$N" pick fast deepseek-ai/deepseek-v4-flash-0731 >/dev/null 2>&1
