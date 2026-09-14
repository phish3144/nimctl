# shellcheck shell=bash
# status / start / restart / stop, proxy round-trips, Claude Code launch, exit codes, JSON.
check "status: key valid" "Key +✓ gültig" < <(timeout 20 "$N" status)
check "status: masked key shows last 4 chars" "nvapi-…tkey" < <(timeout 20 "$N" status)
check "status: slots probed with age" "code +deepseek-ai/deepseek-v4-pro-0813 +✓ antwortet ·.*ms · vor" < <(timeout 20 "$N" status)
check "status: proxy down" "Proxy +✗ aus" < <(timeout 20 "$N" status)
timeout 20 "$N" status >/dev/null 2>&1; assert "status exit code 2 while proxy is down" [ $? -eq 2 ]
check "status --json: structure" '"proxy": *\{ *"up": *false' < <(timeout 20 "$N" status --json | jq -c .)
check "status --json: slot detail" '"code":\{"model":"deepseek-ai/deepseek-v4-pro-0813","state":"ok".*"tools":"ok"' < <(timeout 20 "$N" status --json | jq -c .slots)
check "status without color uses distinct glyphs" "Werkzeuge +✓ litellm +✓ open-webui +✓ claude" < <(timeout 20 "$N" status | cat)
check "start: proxy" "Proxy läuft" < <(timeout 60 "$N" start)
check "start: proxy bound to loopback" "fake litellm on 127.0.0.1:14000" < "$TMP/home/logs/litellm.log"
check "start: idempotent" "läuft bereits" < <(timeout 60 "$N" start)
grep -q "model: custom_openai/deepseek-ai/deepseek-v4-pro-0813" "$TMP/home/litellm.yaml" && grep -q 'additional_drop_params: \["prompt_cache_key"' "$TMP/home/litellm.yaml" && pass "litellm.yaml" || fail "litellm.yaml"
grep -q "model_name: nim-review" "$TMP/home/litellm.yaml" && pass "litellm.yaml: review slot" || fail "litellm.yaml: review slot"
grep -q "model_name: zai-org/glm-5.3" "$TMP/home/litellm.yaml" && pass "litellm.yaml: probed models pass through" || fail "litellm.yaml: probed models pass through"
grep -q "master_key: sk-nimctl-" "$TMP/home/litellm.yaml" && pass "litellm.yaml: random master key" || fail "litellm.yaml: random master key"
[[ $(stat -c %a "$TMP/home/litellm.yaml") == 600 ]] && pass "litellm.yaml perms 600" || fail "litellm.yaml perms"
check "status: services up (nimctl, pid)" "Proxy +✓ läuft +:14000 +nimctl · pid [0-9]+" < <(timeout 20 "$N" status)
timeout 20 "$N" status >/dev/null 2>&1; assert "status exit code 0 when everything is up" [ $? -eq 0 ]
mkdir -p "$TMP/proj"
check "code: proxy round-trip before launch" "Proxy-Roundtrip.*nim-code \(plain\) → [0-9]+ ms" < <(cd "$TMP/proj" && timeout 30 "$N" code --version)
check "code: env passed to claude" "MODEL=nim-code FAST=nim-fast THINK=0 MAXOUT=8192 TOKEN=sk-nimctl-[0-9a-f]+ args=--version" < <(cd "$TMP/proj" && timeout 30 "$N" code --version)
check "code: --model slot" "MODEL=nim-review" < <(cd "$TMP/proj" && timeout 30 "$N" code --model review --version)
check "code: --model id already in proxy" "MODEL=zai-org/glm-5.3" < <(cd "$TMP/proj" && timeout 30 "$N" code --model zai-org/glm-5.3 --version)
check "code: --think" "THINK=16000" < <(cd "$TMP/proj" && timeout 30 "$N" code --think --version)
printf 'MODEL=fast\nMAX_OUTPUT_TOKENS=4096\n' >"$TMP/proj/.nimctl"
check "code: .nimctl project profile" "MODEL=nim-fast .*MAXOUT=4096" < <(cd "$TMP/proj" && timeout 30 "$N" code --version); rm -f "$TMP/proj/.nimctl"
check "code: refuses to run in \$HOME" "Home" < <(cd "$TMP" && printf 'j\n' | timeout 30 "$N" code --version)
check "proxy: all slots" "nim-review \(plain\) → [0-9]+ ms" < <(timeout 60 "$N" proxy)
check "proxy: tools request" "nim-code \(tools\) → [0-9]+ ms" < <(timeout 60 "$N" proxy)
check "env: export lines" "export ANTHROPIC_AUTH_TOKEN=sk-nimctl-" < <(timeout 10 "$N" env)
check "test: reply rendered" "Moin from nvidia/nemotron-3-super-120b" < <(printf '\n' | timeout 60 "$N" test nvidia/nemotron-3-super-120b)
check "test: slot name accepted" "Moin from deepseek-ai/deepseek-v4-flash-0731" < <(timeout 60 "$N" test fast "hallo")
check "test: bad model" "not found" < <(printf '\n' | timeout 60 "$N" test foo/bar)
nocheck "test: failure does not store 'ok …' as an error" $'foo/bar\tok [0-9]' < "$TMP/home/probes"
check "find: laguna overloaded" "laguna-xs-2.1 +überlastet" < <(timeout 30 "$N" find laguna)
check "find: dead model flagged" "kimi-k2.6 +kein Endpoint" < <(timeout 30 "$N" find kimi)
check "find: tool calling shown" "keine Tool-Calls" < <(timeout 30 "$N" find notools)
awk -F'\t' '$1=="mistralai/mistral-medium-3-notools" && $2=="ok" && $5=="no"' "$TMP/home/probes" | grep -q . && pass "probes: model without tool calls flagged" || fail "probes: model without tool calls flagged"
check "find: literal search (no regex error)" "keine Treffer" < <(timeout 30 "$N" find '[')
check "check: all slots" "nemotron-3-super-120b +antwortet" < <(timeout 30 "$N" check)
check "models: catalog" "^zai-org/glm-5.3$" < <(timeout 30 "$N" models)
# auto from the CLI must offer/announce the restart
check "auto (cli): restart hint when services run" "Neustart|neu starten" < <(printf 'n\n' | timeout 120 "$N" auto fast)
check "restart" "Proxy gestoppt" < <(timeout 60 "$N" restart)
check "stop" "Chat gestoppt" < <(timeout 30 "$N" stop)
check "status: down" "Proxy +✗ aus" < <(timeout 20 "$N" status)
# a foreign process on the proxy port is reported, never killed
python3 "$TMP/fake_server.py" 14000 & FOREIGN=$!; sleep 0.5
check "start: foreign process on port refused" "Port 14000 ist belegt" < <(timeout 30 "$N" start)
check "status: foreign listener shown" "Proxy +! fremd" < <(timeout 20 "$N" status)
check "stop: foreign process not touched" "belegt" < <(timeout 30 "$N" stop)
kill -0 $FOREIGN 2>/dev/null && pass "foreign process still alive" || fail "foreign process killed"
kill $FOREIGN 2>/dev/null; wait $FOREIGN 2>/dev/null; sleep 0.3
# a stale pid file pointing at an unrelated process is discarded
sleep 300 & SLEEPER=$!; echo $SLEEPER >"$TMP/home/run/proxy.pid"
check "stale pid file ignored" "Proxy +✗ aus" < <(timeout 20 "$N" status)
kill -0 $SLEEPER 2>/dev/null && pass "unrelated process with recycled pid not killed" || fail "unrelated process killed"
kill $SLEEPER 2>/dev/null
[[ -f "$TMP/home/run/proxy.pid" ]] && fail "stale pid file removed" || pass "stale pid file removed"
