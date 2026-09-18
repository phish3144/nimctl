# shellcheck shell=bash
# Web search: SearXNG installed by the wizard (fake repo + fake venv python, see run.sh). Services are down here.
CONT="$TMP/.continue/config.yaml"
check "search install: idempotent (pull instead of clone)" "Websuche aktiviert" < <(timeout 60 "$N" search install)
[[ -d "$TMP/home/searxng/src/.git" ]] && pass "search install: repository cloned" || fail "search install: repository cloned"
check "search start: starts SearXNG" "Suche läuft +http://localhost:$SP" < <(timeout 60 "$N" search start)
check "search start: url and admin-panel note" "Open WebUI merkt sich" < <(timeout 30 "$N" search start)
check "search: settings bind loopback and port" "bind_address: \"127.0.0.1\", port: $SP" < "$TMP/home/searxng/settings.yml"
check "search: json format enabled, limiter off" "formats: \[html, json\]" < "$TMP/home/searxng/settings.yml"
grep -q 'limiter: false' "$TMP/home/searxng/settings.yml" && grep -q 'url: false' "$TMP/home/searxng/settings.yml" && pass "search: no limiter, no valkey" || fail "search: no limiter, no valkey"
grep -qE 'secret_key: "[0-9a-f]{48}"' "$TMP/home/searxng/settings.yml" && [[ $(stat -c %a "$TMP/home/searxng/settings.yml") == 600 ]] && pass "search: secret key, perms 600" || fail "search: secret key, perms 600"
check "search: fake SearXNG serves the configured port" "fake searxng on $SP" < "$TMP/home/logs/searxng.log"
check "search \"query\": lists results" "Result 1 for nvidia nim" < <(timeout 30 "$N" search "nvidia nim")
check "search query: url per result" "https://example.org/2" < <(timeout 30 "$N" search nvidia nim)
check "search test" "Result 3 for nvidia nim" < <(timeout 30 "$N" search test)
check "status: search row" "Suche +✓ läuft +:$SP" < <(timeout 20 "$N" status)
check "status --json: search block" '"search":\{"enabled":true,"up":true' < <(timeout 20 "$N" status --json | jq -c .)
check "dashboard: footer lists o Suche" "Nutzen .*o Suche" < <(printf 'q\n' | timeout 30 "$N")
check "chat: Open WebUI gets the SearXNG query url" "search=http://127.0.0.1:$SP/search\?q=<query>&format=json" < <(timeout 90 "$N" start; cat "$TMP/home/logs/open-webui.log")
timeout 10 "$N" ide config --force >/dev/null
grep -q "NIMCTL_SEARCH_URL: \"http://127.0.0.1:$SP\"" "$CONT" && grep -q 'web_search' "$CONT" && pass "ide: Continue gets the search url and the rule" || fail "ide: Continue gets the search url and the rule"
grep -q 'def web_search' "$TMP/home/mcp/shell.py" && python3 -m py_compile "$TMP/home/mcp/shell.py" 2>/dev/null && pass "ide: web_search tool in the MCP server" || fail "ide: web_search tool in the MCP server"
check "stop: stops the search too" "Suche gestoppt" < <(timeout 30 "$N" stop)
check "search disable" "Websuche deaktiviert" < <(timeout 30 "$N" search disable)
grep -q '^SEARCH_ENABLED=0$' "$TMP/home/config" && pass "search disable: config" || fail "search disable: config"
nocheck "start: leaves a disabled search out" "Suche läuft" < <(timeout 90 "$N" start)
check "search start: enables again" "Websuche aktiviert" < <(timeout 60 "$N" search start)
timeout 30 "$N" stop >/dev/null
check "help: search listed" "^  search +.*SearXNG" < <(NIMCTL_LANG=en timeout 10 "$N" help)
