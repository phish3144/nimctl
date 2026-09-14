#!/usr/bin/env bash
# nimctl test suite – runs against tests/mock_api.py and fake service binaries. No network needed.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(dirname "$HERE")
TMP=$(mktemp -d); trap 'kill $MOCK 2>/dev/null; pkill -f "fake_server.py" 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
cat >"$TMP/fake_server.py" <<'X'
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self): self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(json.dumps({"content": [{"type": "text", "text": "hi from " + body.get("model", "?")}]}).encode())
ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
X
for b in litellm open-webui; do cat >"$TMP/bin/$b" <<X
#!/usr/bin/env bash
[[ "\$1" == serve ]] && shift; while [[ \$# -gt 0 ]]; do case \$1 in --port) P=\$2; shift;; esac; shift; done
echo "fake $b on \$P key=\${NVIDIA_API_KEY:-\${OPENAI_API_KEY:-}} default=\${DEFAULT_MODELS:-}"
exec python3 "$TMP/fake_server.py" "\$P"
X
done
printf '#!/usr/bin/env bash\necho "fake claude BASE=$ANTHROPIC_BASE_URL MODEL=$ANTHROPIC_MODEL FAST=$ANTHROPIC_SMALL_FAST_MODEL THINK=$MAX_THINKING_TOKENS MAXOUT=$CLAUDE_CODE_MAX_OUTPUT_TOKENS args=$*"\n' >"$TMP/bin/claude"
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" NIMCTL_HOME="$TMP/home" NIMCTL_API_BASE=http://127.0.0.1:9999/v1 NIMCTL_PROXY_PORT=14000 NIMCTL_CHAT_PORT=13000 TERM=dumb NIMCTL_PROBE_TIMEOUT=3 NIMCTL_LANG=de HOME="$TMP"
python3 "$HERE/mock_api.py" 9999 & MOCK=$!; sleep 1
N="$ROOT/nimctl"; PASS=0; FAIL=0
strip() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }
check() { # check <name> <pattern> <<< output
  local out; out=$(cat); if echo "$out" | strip | grep -qE -- "$2"; then echo "  ok   $1"; ((PASS++)); else echo "  FAIL $1 (expected /$2/)"; echo "$out" | strip | sed 's/^/       | /' | tail -n 25; ((FAIL++)); fi; }

echo "== nimctl tests =="
bash -n "$N" && echo "  ok   syntax" || { echo "  FAIL syntax"; exit 1; }
check "version" "^nimctl [0-9]" < <(timeout 10 "$N" version)
check "help" "Nutzung" < <(timeout 10 "$N" help)
# 1. first run → wizard: key (wrong then right), tools present, auto models, start services
printf 'nvapi-wrong\nnvapi-testkey\nn\n' | timeout 120 "$N" > "$TMP/wiz.txt" 2>&1
check "wizard: rejects wrong key" "nicht akzeptiert" < "$TMP/wiz.txt"
check "wizard: accepts key" "gültig – gespeichert" < "$TMP/wiz.txt"
check "wizard: cold model times out first" "deepseek-v4-pro-0813 +Timeout nach 3s" < "$TMP/wiz.txt"
check "wizard: retries top candidate with 2x timeout" "Zweiter Versuch für deepseek-ai/deepseek-v4-pro-0813 mit 6s" < "$TMP/wiz.txt"
check "wizard: auto code = deepseek-v4-pro (after retry)" "→ deepseek-ai/deepseek-v4-pro-0813 gewählt" < "$TMP/wiz.txt"
check "wizard: overloaded model mapped" "laguna-xs-2.1 +überlastet" < "$TMP/wiz.txt"
check "wizard: cached result reused across slots" "nemotron-3-super-120b +antwortet [0-9]+ ms \(bereits geprüft\)" < "$TMP/wiz.txt"
check "wizard: auto fast = deepseek-v4-flash" "→ deepseek-ai/deepseek-v4-flash-0731 gewählt" < "$TMP/wiz.txt"
check "wizard: auto chat = nemotron-3-super" "→ nvidia/nemotron-3-super-120b gewählt" < "$TMP/wiz.txt"
check "wizard: slow model timeout" "kimi-k3.*Timeout nach 3s" < "$TMP/wiz.txt"
check "wizard: services declined stay down" "Fertig" < "$TMP/wiz.txt"
grep -q 'MODEL_CODE="deepseek-ai/deepseek-v4-pro-0813"' "$TMP/home/config" && { echo "  ok   config written"; ((PASS++)); } || { echo "  FAIL config"; ((FAIL++)); }
[[ $(stat -c %a "$TMP/home/config") == 600 ]] && { echo "  ok   config perms 600"; ((PASS++)); } || { echo "  FAIL config perms"; ((FAIL++)); }
# 2. status / start / status / restart / stop
check "status: key valid" "API-Key +● gültig" < <(timeout 20 "$N" status)
check "status: slots probed" "code +deepseek-ai/deepseek-v4-pro-0813 +● antwortet" < <(timeout 20 "$N" status)
check "start: proxy" "Proxy läuft" < <(timeout 60 "$N" start)
check "start: idempotent" "läuft bereits" < <(timeout 60 "$N" start)
grep -q "model: custom_openai/deepseek-ai/deepseek-v4-pro-0813" "$TMP/home/litellm.yaml" && grep -q 'additional_drop_params: \["prompt_cache_key"' "$TMP/home/litellm.yaml" && { echo "  ok   litellm.yaml"; ((PASS++)); } || { echo "  FAIL litellm.yaml"; ((FAIL++)); }
check "status: services up" "Proxy +● läuft" < <(timeout 20 "$N" status)
check "code: proxy round-trip before launch" "Proxy-Roundtrip.*nim-code \(plain\) → [0-9]+ ms" < <(timeout 30 "$N" code --version)
check "code: env passed to claude" "MODEL=nim-code FAST=nim-fast THINK=0 MAXOUT=8192 args=--version" < <(timeout 30 "$N" code --version)
check "proxy: all three slots" "nim-chat \(plain\) → [0-9]+ ms" < <(timeout 60 "$N" proxy)
check "proxy: tools request" "nim-code \(tools\) → [0-9]+ ms" < <(timeout 60 "$N" proxy)
check "code: thinking disabled for open models" "THINK=0 MAXOUT=8192" < <(timeout 30 "$N" code --version)
check "test: reply rendered" "Moin from nvidia/nemotron-3-super-120b" < <(printf '\n' | timeout 60 "$N" test nvidia/nemotron-3-super-120b)
check "test: bad model" "not found" < <(printf '\n' | timeout 60 "$N" test foo/bar)
check "find: laguna overloaded" "laguna-xs-2.1 +überlastet" < <(timeout 30 "$N" find laguna)
check "find: dead model flagged" "kimi-k2.6 +kein Endpoint" < <(timeout 30 "$N" find kimi)
check "check: all slots" "nemotron-3-super-120b +antwortet" < <(timeout 30 "$N" check)
check "restart" "proxy gestoppt" < <(timeout 60 "$N" restart)
check "stop" "chat gestoppt" < <(timeout 30 "$N" stop)
check "status: down" "Proxy +● aus" < <(timeout 20 "$N" status)
# 3. dashboard interactions
check "pick: manual slot code → glm" "code → zai-org/glm-5.3" < <(printf '1\nglm\n1\n\nq\n' | timeout 60 "$N")
check "pick: dead model refused" "nicht geändert" < <(printf '1\nkimi-k2\n1\n\n\nq\n' | timeout 60 "$N")
grep -q 'MODEL_CODE="zai-org/glm-5.3"' "$TMP/home/config" && { echo "  ok   pick persisted"; ((PASS++)); } || { echo "  FAIL pick persisted"; ((FAIL++)); }
check "dashboard: auto-select" "→ deepseek-ai/deepseek-v4-pro-0813 gewählt" < <(printf 'a\n\nq\n' | timeout 120 "$N")
check "key: wrong key keeps old" "alter Key bleibt" < <(printf 'k\nnvapi-wrong\n\nq\n' | timeout 30 "$N")
check "dashboard: unknown key" "unbekannte Taste" < <(printf 'zz\n\nq\n' | timeout 30 "$N")
timeout 20 "$N" </dev/null >/dev/null; [[ $? == 0 ]] && { echo "  ok   EOF exits cleanly"; ((PASS++)); } || { echo "  FAIL EOF exit"; ((FAIL++)); }
check "doctor: all green" "● OK" < <(printf 'n\n' | timeout 60 "$N" doctor)
sed -i 's#^MODEL_CODE=.*#MODEL_CODE="moonshotai/kimi-k2.6"#' "$TMP/home/config"
printf 'j\n' | timeout 120 "$N" doctor > "$TMP/doc.txt" 2>&1
check "doctor: detects dead slot" "kimi-k2.6 +kein Endpoint" < "$TMP/doc.txt"
check "doctor: repairs via auto-select" "→ deepseek-ai/deepseek-v4-pro-0813 gewählt" < "$TMP/doc.txt"
check "i18n: english" "API key +● valid" < <(NIMCTL_LANG=en timeout 20 "$N" status)
echo; echo "passed: $PASS  failed: $FAIL"; ((FAIL == 0))
