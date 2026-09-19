# shellcheck shell=bash
# Web search: SearXNG installed by the wizard (fake repo + fake venv python, see run.sh). Services are down here.
CONT="$TMP/.continue/config.yaml"
check "search install: idempotent (pull instead of clone)" "Websuche aktiviert" < <(timeout 60 "$N" search install)
[[ -d "$TMP/home/searxng/src/.git" ]] && pass "search install: repository cloned" || fail "search install: repository cloned"
check "search start: starts SearXNG" "Suche läuft +http://localhost:$SP" < <(timeout 60 "$N" search start)
check "search start: url and db-sync note" "lokale SearXNG-URL" < <(timeout 30 "$N" search start)
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
# Persisted Open WebUI config (DB wins over env): a wrong public URL must be rewritten to the local instance.
mkdir -p "$TMP/home/webui-data"
python3 - "$TMP/home/webui-data/webui.db" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE config (key TEXT PRIMARY KEY, value JSON NOT NULL, updated_at INTEGER)")
con.execute("INSERT INTO config(key,value,updated_at) VALUES(?,?,?)",
            ("web.search.searxng_query_url", '"https://searx.thefloatinglab.world/"', 1))
con.execute("INSERT INTO config(key,value,updated_at) VALUES(?,?,?)",
            ("web.search.engine", '"bing"', 1))
con.execute("INSERT INTO config(key,value,updated_at) VALUES(?,?,?)",
            ("web.search.enable", "false", 1))
con.commit()
PY
check "search start: syncs SearXNG URL into webui.db" "127.0.0.1:$SP/search" < <(
  timeout 60 "$N" search start >/dev/null
  python3 - "$TMP/home/webui-data/webui.db" <<'PY'
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1])
for k in ("web.search.searxng_query_url", "web.search.engine", "web.search.enable"):
    v = con.execute("SELECT value FROM config WHERE key=?", (k,)).fetchone()[0]
    print(k, v if isinstance(v, str) else json.dumps(v))
PY
)
check "chat: Open WebUI gets the SearXNG query url" "search=http://127.0.0.1:$SP/search\?q=<query>&format=json" < <(timeout 90 "$N" start; cat "$TMP/home/logs/open-webui.log")
# Open WebUI keeps connection, default model and search in its database once it has started; the environment only seeds them.
# nimctl aligns what it owns before every chat start – both storage schemas – and leaves everything else alone.
timeout 30 "$N" stop >/dev/null
DB="$TMP/home/webui-data/webui.db"; mkdir -p "$(dirname "$DB")"
python3 - "$DB" <<'PY'
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1]); con.execute("DROP TABLE IF EXISTS config")
con.execute("CREATE TABLE config (id INTEGER PRIMARY KEY, data JSON, version INTEGER, created_at DATETIME, updated_at DATETIME)")
data = {"version": 0, "ui": {"default_models": "nvidia/nemotron-3-super-120b", "enable_signup": False},
        "openai": {"enable": True, "api_base_urls": ["https://integrate.api.nvidia.com/v1"], "api_keys": ["nvapi-old"], "api_configs": {"0": {}}},
        "rag": {"web": {"search": {"enable": True, "engine": "searxng", "searxng_query_url": "https://searx.example.org/search?q=<query>&format=json"}}}}
con.execute("INSERT INTO config (id, data, version) VALUES (1, ?, 0)", (json.dumps(data),)); con.commit()
PY
check "chat start: stored Open WebUI settings aligned (json blob schema)" "Open-WebUI-Einstellungen angeglichen: connection → http://127.0.0.1:$PP/v1, search → searxng http://127.0.0.1:$SP/search\?q=<query>&format=json, default model → nim-chat" < <(timeout 90 "$N" start)
python3 - "$DB" "$PP" "$SP" <<'PY'
import json, sqlite3, sys
d = json.loads(sqlite3.connect(sys.argv[1]).execute("SELECT data FROM config").fetchone()[0])
ok = (d["openai"]["api_base_urls"] == [f"http://127.0.0.1:{sys.argv[2]}/v1"] and d["openai"]["api_keys"][0].startswith("sk-nimctl-")
      and d["rag"]["web"]["search"]["searxng_query_url"] == f"http://127.0.0.1:{sys.argv[3]}/search?q=<query>&format=json" and d["rag"]["web"]["search"]["enable"] is True
      and d["ui"]["default_models"] == "nim-chat" and d["ui"]["enable_signup"] is False and d["openai"]["api_configs"] == {"0": {}})
sys.exit(0 if ok else 1)
PY
assert "chat start: connection, key, search url and default model written, other settings untouched" [ $? -eq 0 ]
timeout 30 "$N" stop >/dev/null
nocheck "chat start: nothing to align the second time" "angeglichen" < <(timeout 90 "$N" start)
timeout 30 "$N" stop >/dev/null
python3 - "$DB" <<'PY'
import json, sqlite3, sys, time
con = sqlite3.connect(sys.argv[1]); con.execute("DROP TABLE IF EXISTS config")
con.execute("CREATE TABLE config (key TEXT PRIMARY KEY, value JSON NOT NULL, updated_at BIGINT)")
rows = {"openai.api_base_urls": ["https://api.example.org/v1", "https://integrate.api.nvidia.com/v1"], "openai.api_keys": ["sk-other", "nvapi-old"], "openai.enable": False,
        "web.search.enable": True, "web.search.engine": "searxng", "web.search.searxng_query_url": "https://searx.example.org/search?q=<query>&format=json", "ui.default_models": "nvidia/nemotron-3-super-120b"}
for k, v in rows.items(): con.execute("INSERT INTO config (key, value, updated_at) VALUES (?, ?, ?)", (k, json.dumps(v), int(time.time())))
con.commit()
PY
check "chat start: stored settings aligned (one row per key schema)" "angeglichen: connection → http://127.0.0.1:$PP/v1, connection on, search → searxng http://127.0.0.1:$SP/search.*default model → nim-chat" < <(timeout 90 "$N" start)
python3 - "$DB" "$PP" <<'PY'
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1]); g = lambda k: json.loads(con.execute("SELECT value FROM config WHERE key=?", (k,)).fetchone()[0])
ok = (g("openai.api_base_urls") == ["https://api.example.org/v1", f"http://127.0.0.1:{sys.argv[2]}/v1"] and g("openai.api_keys")[0] == "sk-other"
      and g("openai.api_keys")[1].startswith("sk-nimctl-") and g("openai.enable") is True and g("ui.default_models") == "nim-chat" and g("web.search.engine") == "searxng")
sys.exit(0 if ok else 1)
PY
assert "chat start: only nimctl's connection replaced, the other one kept" [ $? -eq 0 ]
python3 - "$DB" <<'PY'
import json, sqlite3, sys
con = sqlite3.connect(sys.argv[1]); con.execute("UPDATE config SET value=? WHERE key='openai.api_base_urls'", (json.dumps(["https://integrate.api.nvidia.com/v1"]),)); con.commit()
PY
check "doctor: reports a chat that still talks to NVIDIA directly" "Chat spricht mit https://integrate.api.nvidia.com/v1 statt http://127.0.0.1:$PP/v1" < <(timeout 180 "$N" doctor 2>&1)
check "doctor --fix: restarts the chat, which aligns the connection" "angeglichen: connection → http://127.0.0.1:$PP/v1" < <(timeout 180 "$N" doctor --fix 2>&1)
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
