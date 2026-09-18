# shellcheck shell=bash
# Provider pool: keys checked at the provider, one model per slot from its catalog (namespaced probes), LiteLLM
# config with pool-<slot> deployments in provider order and fallbacks to them, keys in the proxy environment,
# dashboard/status/doctor rows, pool ids usable with code/test, removal, keys from the environment.
check "pool: overview lists providers without keys" "Groq +kein Key" < <(NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
check "pool: unknown provider named with the known ones" "unbekannter Anbieter: foo \(bekannt: groq gemini" < <(timeout 20 "$N" pool add foo abcdefghijklmnopqrstuvwxyz 2>&1)
timeout 20 "$N" pool add foo abcdefghijklmnopqrstuvwxyz >/dev/null 2>&1; assert "pool: unknown provider rc=64" [ $? -eq 64 ]
check "pool: malformed key refused before any request" "sieht falsch aus" < <(timeout 20 "$N" pool add groq short 2>&1)
check "pool: wrong key rejected by the provider" "Groq lehnt den Key ab \(HTTP 401\)" < <(timeout 30 "$N" pool add groq gsk_wrongkey_0123456789 2>&1)
nocheck "pool: rejected key not saved" "GROQ_API_KEY=gsk" < "$TMP/home/config"
timeout 120 "$N" pool add groq gsk_testkey_0123456789 >"$TMP/pool.txt" 2>&1
check "pool add: key accepted" "prüfe Key bei Groq .* gültig" < "$TMP/pool.txt"
check "pool add: code needs tool calls → gpt-oss-120b (first pattern)" "Groq code +→ openai/gpt-oss-120b \(" < "$TMP/pool.txt"
check "pool add: fast model" "Groq fast +→ llama-3.1-8b-instant \(" < "$TMP/pool.txt"
check "pool add: chat model" "Groq chat +→ llama-3.3-70b-versatile \(" < "$TMP/pool.txt"
check "pool add: done" "Groq im Pool" < "$TMP/pool.txt"
grep -q '^GROQ_API_KEY=gsk_testkey_0123456789$' "$TMP/home/config" && pass "config: groq key saved" || fail "config: groq key saved"
check "config: groq models per slot" '^POOL_GROQ=code=openai/gpt-oss-120b fast=llama-3.1-8b-instant chat=llama-3.3-70b-versatile review=openai/gpt-oss-120b$' < "$TMP/home/config"
awk -F'\t' '$1=="groq:openai/gpt-oss-120b" && $2=="ok" && $5=="ok"' "$TMP/home/probes" | grep -q . && pass "probes: namespaced pool id with tools column" || fail "probes: namespaced pool id with tools column"
Y="$TMP/home/litellm.yaml"
grep -A1 'model_name: pool-code$' "$Y" | grep -q "model: custom_openai/openai/gpt-oss-120b, api_base: http://127.0.0.1:$GP/v1, api_key: os.environ/GROQ_API_KEY, max_tokens: 16384, order: 1," && pass "litellm.yaml: pool-code deployment at the provider with its key, order 1" || { fail "litellm.yaml: pool-code deployment"; grep -A1 'pool-code$' "$Y"; }
grep -A1 'model_name: pool-fast$' "$Y" | grep -q "max_tokens: 8192, order: 1," && pass "litellm.yaml: pool-fast capped like nim-fast" || fail "litellm.yaml: pool-fast capped like nim-fast"
check "litellm.yaml: fallbacks go to the pool first, then the fast/code model" 'fallbacks: \[ \{ nim-code: \["pool-code", "nim-fast"\] \}, \{ nim-fast: \["pool-fast"\] \}, \{ nim-chat: \["pool-chat", "nim-fast"\] \}, \{ nim-review: \["pool-review", "nim-code"\] \} \]$' < "$Y"
check "litellm.yaml: a stall is handed over, not retried" "retry_policy: \{ TimeoutErrorRetries: 0, DefaultRetries: 0, RateLimitErrorRetries: 0" < "$Y"
[[ $(grep -c "timeout: 90, additional_drop_params" "$Y") -eq $(grep -c "^  - model_name:" "$Y") ]] && pass "litellm.yaml: stall timeout on every deployment" || fail "litellm.yaml: stall timeout on every deployment"
nocheck "litellm.yaml: cooldowns on once a pool exists" "disable_cooldowns" < "$Y"
check "litellm.yaml: pool model reachable by its namespaced id" "model_name: groq:openai/gpt-oss-120b$" < "$Y"
nocheck "litellm.yaml: pool ids never become NVIDIA entries" "custom_openai/groq:" < "$Y"
NIMCTL_STALL_TIMEOUT=45 timeout 60 "$N" pool auto groq >/dev/null 2>&1
check "NIMCTL_STALL_TIMEOUT sets the deployment timeout" "timeout: 45, additional_drop_params" < "$Y"
timeout 60 "$N" start >/dev/null 2>&1
check "proxy: pool key in its environment" "pool=groq" < "$TMP/home/logs/litellm.log"
check "status --json: pool models" '"pool":\{"groq":\{"models":\{"code":"openai/gpt-oss-120b","fast":"llama-3.1-8b-instant"' < <(timeout 20 "$N" status --json | jq -c .)
check "dashboard: pool row" "Pool +. Groq \(4\)" < <(timeout 20 "$N" status)
check "pool test: round trips through the proxy" "pool-code \(tools\) →" < <(timeout 60 "$N" pool test 2>&1)
check "code --model groq:…: pool id handed to claude" "MODEL=groq:openai/gpt-oss-120b" < <(cd "$TMP/home" && timeout 60 "$N" code --model groq:openai/gpt-oss-120b 2>&1)
check "test: a pool id is sent to its provider" "Moin from openai/gpt-oss-120b" < <(timeout 30 "$N" test groq:openai/gpt-oss-120b "hi" 2>&1)
check "doctor: pool key checked" "Pool Groq: gültig" < <(timeout 120 "$N" doctor 2>&1)
timeout 30 "$N" stop >/dev/null 2>&1
timeout 120 "$N" pool add cerebras csk-testkey-0123456789 >/dev/null 2>&1
grep -A1 'model_name: pool-code$' "$Y" | grep -q "model: custom_openai/gpt-oss-120b, api_base: http://127.0.0.1:$CB/v1, api_key: os.environ/CEREBRAS_API_KEY, max_tokens: 16384, order: 2," && pass "litellm.yaml: second provider joins pool-code with order 2" || { fail "litellm.yaml: second provider order 2"; grep -A1 'pool-code$' "$Y"; }
check "pool overview: both providers with their models" "Cerebras +code=gpt-oss-120b +fast=llama3.1-8b" < <(NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
check "pool models: provider catalog" "^qwen-3-235b-a22b-instruct-2507$" < <(timeout 20 "$N" pool models cerebras)
check "pool remove" "Groq aus dem Pool entfernt" < <(timeout 20 "$N" pool remove groq 2>&1)
grep -q '^GROQ_API_KEY=$' "$TMP/home/config" && grep -q '^POOL_GROQ=$' "$TMP/home/config" && pass "config: removed provider cleared" || fail "config: removed provider cleared"
nocheck "litellm.yaml: removed provider gone" "GROQ_API_KEY" < "$Y"
check "litellm.yaml: remaining provider keeps the pool" "model_name: pool-code$" < "$Y"
check "pool remove twice" "Groq ist nicht im Pool" < <(timeout 20 "$N" pool remove groq 2>&1)
check "env key: GROQ_API_KEY from the environment counts as configured" "Groq +code=" < <(GROQ_API_KEY=gsk_testkey_0123456789 NIMCTL_INTERACTIVE=0 timeout 60 "$N" pool auto groq >/dev/null 2>&1; GROQ_API_KEY=gsk_testkey_0123456789 NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
grep -q '^GROQ_API_KEY=gsk_testkey_0123456789$' "$TMP/home/config" && pass "env key: persisted by pool auto" || fail "env key: persisted by pool auto"
timeout 20 "$N" pool remove groq >/dev/null 2>&1; timeout 20 "$N" pool remove cerebras >/dev/null 2>&1
nocheck "pool: back to NVIDIA-only config" "pool-" < "$Y"
check "pool: NVIDIA-only router keeps cooldowns off" "disable_cooldowns: true" < "$Y"
