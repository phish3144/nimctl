#!/usr/bin/env bash
# nimctl test suite – runs the built ./nimctl against tests/mock_api.py and fake service binaries. No network needed.
# Test cases live in tests/cases/*.sh and are sourced in filename order; each uses check/pass/fail from here.
set -u
exec </dev/null                          # no test may block on the runner's stdin; tests pipe their own input
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(dirname "$HERE")
TMP=$(mktemp -d); trap 'kill $MOCK $UPD 2>/dev/null; pkill -f "[f]ake_server.py" 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home" "$TMP/update"
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
# Fake litellm / open-webui: keep the wrapper alive (its command line is what nimctl identifies) and forward TERM.
for b in litellm open-webui; do cat >"$TMP/bin/$b" <<X
#!/usr/bin/env bash
[[ "\$1" == serve ]] && shift; H=""; while [[ \$# -gt 0 ]]; do case \$1 in --port) P=\$2; shift;; --host) H=\$2; shift;; esac; shift; done
echo "fake $b on \$H:\$P key=\${NVIDIA_API_KEY:-\${OPENAI_API_KEY:-}} default=\${DEFAULT_MODELS:-} base=\${OPENAI_API_BASE_URL:-}"
python3 "$TMP/fake_server.py" "\$P" & C=\$!; trap 'kill \$C 2>/dev/null; exit 0' TERM INT; wait \$C
X
done
printf '#!/usr/bin/env bash\necho "fake claude BASE=$ANTHROPIC_BASE_URL MODEL=$ANTHROPIC_MODEL FAST=$ANTHROPIC_SMALL_FAST_MODEL THINK=$MAX_THINKING_TOKENS MAXOUT=$CLAUDE_CODE_MAX_OUTPUT_TOKENS TOKEN=$ANTHROPIC_AUTH_TOKEN args=$*"\n' >"$TMP/bin/claude"
printf '#!/usr/bin/env bash\necho "fake uv $*"\n' >"$TMP/bin/uv"
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" NIMCTL_HOME="$TMP/home" NIMCTL_API_BASE=http://127.0.0.1:9999/v1 NIMCTL_PROXY_PORT=14000 NIMCTL_CHAT_PORT=13000
export TERM=dumb NIMCTL_PROBE_TIMEOUT=3 NIMCTL_LANG=de HOME="$TMP" NIMCTL_INTERACTIVE=1 LC_ALL=C.UTF-8 NIMCTL_UPDATE_URL=http://127.0.0.1:9998
unset NVIDIA_API_KEY NIMCTL_API_KEY NIMCTL_YES NO_COLOR DISPLAY WAYLAND_DISPLAY
python3 "$HERE/mock_api.py" 9999 & MOCK=$!
( cd "$TMP/update" && exec python3 -m http.server 9998 --bind 127.0.0.1 >/dev/null 2>&1 ) & UPD=$!
sleep 1
N="$ROOT/nimctl"; PASS=0; FAIL=0
strip() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }
check() { # check <name> <pattern> <<< output
  local out; out=$(cat); if echo "$out" | strip | grep -qE -- "$2"; then pass "$1"; else echo "$out" | strip | sed 's/^/       | /' | tail -n 25; fail "$1 (expected /$2/)"; fi; }
nocheck() { # nocheck <name> <pattern> – passes when the pattern is absent
  local out; out=$(cat); if echo "$out" | strip | grep -qE -- "$2"; then echo "$out" | strip | sed 's/^/       | /' | tail -n 15; fail "$1 (unexpected /$2/)"; else pass "$1"; fi; }
pass() { echo "  ok   $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }
assert() { if "${@:2}"; then pass "$1"; else fail "$1"; fi; }   # assert <name> <command…>

echo "== nimctl tests =="
bash -n "$N" && pass "syntax" || { fail "syntax"; exit 1; }
for case in "$HERE"/cases/*.sh; do
  echo "-- ${case##*/}"
  # shellcheck disable=SC1090
  source "$case"
done
echo; echo "passed: $PASS  failed: $FAIL"; ((FAIL == 0))
