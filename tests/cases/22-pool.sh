# shellcheck shell=bash
# Provider pool as part of the ranking: keys checked at the provider, every provider with a key joins the chains
# (rank by the candidate list, not by being NVIDIA), one chain per slot with rank 1 as the slot's model, per-rank
# model groups falling down the chain in the proxy config, chains.json for the hook, keys in the proxy
# environment, dashboard/status/doctor rows, pool ids usable with code/test, exact pick, removal, keys from the environment.
check "pool: overview lists providers without keys" "Groq +kein Key" < <(NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
check "pool: unknown provider named with the known ones" "unbekannter Anbieter: foo \(bekannt: groq gemini" < <(timeout 20 "$N" pool add foo abcdefghijklmnopqrstuvwxyz 2>&1)
timeout 20 "$N" pool add foo abcdefghijklmnopqrstuvwxyz >/dev/null 2>&1; assert "pool: unknown provider rc=64" [ $? -eq 64 ]
check "pool: malformed key refused before any request" "sieht falsch aus" < <(timeout 20 "$N" pool add groq short 2>&1)
check "pool: wrong key rejected by the provider" "Groq lehnt den Key ab \(HTTP 401\)" < <(timeout 30 "$N" pool add groq gsk_wrongkey_0123456789 2>&1)
nocheck "pool: rejected key not saved" "GROQ_API_KEY=gsk" < "$TMP/home/config"
timeout 180 "$N" pool add groq gsk_testkey_0123456789 >"$TMP/pool.txt" 2>&1
check "pool add: key accepted" "prüfe Key bei Groq .* gültig" < "$TMP/pool.txt"
check "pool add: the chains are rebuilt – rank 1 of code stays the best responder" "code → deepseek-ai/deepseek-v4-pro-0813 \(" < "$TMP/pool.txt"
check "pool add: Groq's gpt-oss-120b takes rank 2 for code – the ranking decides, not the provider" "Ausweich in dieser Reihenfolge: groq:openai/gpt-oss-120b zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b groq:llama-3.3-70b-versatile" < "$TMP/pool.txt"
check "pool add: the fast chain mixes providers by rank" "fast → deepseek-ai/deepseek-v4-flash-0731 \(.*Ausweich in dieser Reihenfolge: groq:llama-3.1-8b-instant groq:openai/gpt-oss-20b nvidia/nemotron-3.5-lightning-30b-a3b" < <(tr '\n' ' ' < "$TMP/pool.txt")
check "pool add: done" "Groq ist dabei – die Ketten wurden neu gebaut" < "$TMP/pool.txt"
grep -q '^GROQ_API_KEY=gsk_testkey_0123456789$' "$TMP/home/config" && pass "config: groq key saved" || fail "config: groq key saved"
check "config: code chain with Groq ranks" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 groq:openai/gpt-oss-120b zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b groq:llama-3.3-70b-versatile nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
awk -F'\t' '$1=="groq:openai/gpt-oss-120b" && $2=="ok" && $5=="ok"' "$TMP/home/probes" | grep -q . && pass "probes: namespaced pool id with tools column" || fail "probes: namespaced pool id with tools column"
Y="$TMP/home/litellm.yaml"
grep -A1 'model_name: nim-code-r2$' "$Y" | grep -q "model: custom_openai/openai/gpt-oss-120b, api_base: http://127.0.0.1:$GP/v1, api_key: os.environ/GROQ_API_KEY, max_tokens: 16384, timeout: 120," && pass "litellm.yaml: rank 2 of code is its own group at Groq with Groq's key" || { fail "litellm.yaml: rank 2 of code"; grep -A1 'nim-code-r2$' "$Y"; }
check "litellm.yaml: rank 1 falls down the chain, then to the fast model" 'fallbacks: \[ \{ nim-code: \["nim-code-r2", "nim-code-r3", "nim-code-r4", "nim-code-r5", "nim-code-r6", "nim-fast"\] \}' < "$Y"
check "litellm.yaml: the last rank falls to the fast model only" '\{ nim-code-r6: \["nim-fast"\] \}' < "$Y"
check "litellm.yaml: the review chain ends at the code model" '\{ nim-review-r[0-9]: \["nim-code"\] \}' < "$Y"
check "litellm.yaml: cooldowns are the hook's job" "disable_cooldowns: true" < "$Y"
check "litellm.yaml: a stall is not retried on the same rank" "TimeoutErrorRetries: 0, DefaultRetries: 0, RateLimitErrorRetries: 1" < "$Y"
check "litellm.yaml: pool model reachable by its namespaced id" "model_name: groq:openai/gpt-oss-120b$" < "$Y"
nocheck "litellm.yaml: pool ids never become NVIDIA entries" "custom_openai/groq:" < "$Y"
check "chains.json: groups → models for the hook" '"nim-code-r2":"groq:openai/gpt-oss-120b"' < <(jq -c .models "$TMP/home/chains.json")
check "chains.json: NVIDIA groups listed for the budget" '"nim-code","nim-code-r3"' < <(jq -c .nim "$TMP/home/chains.json")
NIMCTL_STALL_TIMEOUT=45 timeout 120 "$N" pool auto >/dev/null 2>&1
check "NIMCTL_STALL_TIMEOUT sets the deployment timeout" "timeout: 45, additional_drop_params" < "$Y"
timeout 60 "$N" start >/dev/null 2>&1
check "proxy: pool key in its environment" "pool=groq" < "$TMP/home/logs/litellm.log"
check "status --json: chain per slot" '"chain":\["deepseek-ai/deepseek-v4-pro-0813","groq:openai/gpt-oss-120b"' < <(timeout 20 "$N" status --json | jq -c .slots.code)
check "status --json: pool ranks" '"groq":\{"ranks":\[\{"slot":"code","rank":2,"model":"openai/gpt-oss-120b"\}' < <(timeout 20 "$N" status --json | jq -c .pool)
check "dashboard: pool row counts the ranks held" "Pool +. Groq \(7\)" < <(timeout 20 "$N" status)
check "dashboard: slots show their fallback ranks" "code +deepseek-ai/deepseek-v4-pro-0813 .*\+5 Ausweich" < <(timeout 20 "$N" status)
check "pool test: round trips through the proxy" "nim-code \(tools\) →" < <(timeout 60 "$N" pool test 2>&1)
check "code --model groq:…: pool id handed to claude" "MODEL=groq:openai/gpt-oss-120b" < <(cd "$TMP/home" && timeout 60 "$N" code --model groq:openai/gpt-oss-120b 2>&1)
check "test: a pool id is sent to its provider" "Moin from openai/gpt-oss-120b" < <(timeout 30 "$N" test groq:openai/gpt-oss-120b "hi" 2>&1)
check "doctor: pool key checked" "Pool Groq: gültig" < <(timeout 120 "$N" doctor 2>&1)
timeout 30 "$N" stop >/dev/null 2>&1
timeout 180 "$N" pool add cerebras csk-testkey-0123456789 >/dev/null 2>&1
check "config: a second provider takes its ranks in the chains" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 groq:openai/gpt-oss-120b zai-org/glm-5.3 cerebras:gpt-oss-120b nvidia/nemotron-3-ultra-550b-a55b groq:llama-3.3-70b-versatile$' < "$TMP/home/config"
check "pool overview: ranks per provider" "Cerebras +code #4 gpt-oss-120b +fast #3 llama3.1-8b" < <(NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
check "pool models: provider catalog" "^qwen-3-235b-a22b-instruct-2507$" < <(timeout 20 "$N" pool models cerebras)
check "pick: an exact id becomes rank 1, the chain moves down" "fast → groq:llama-3.1-8b-instant" < <(timeout 60 "$N" pick fast groq:llama-3.1-8b-instant 2>&1)
check "config: pick moved the model to the head of the chain" '^CHAIN_FAST=groq:llama-3.1-8b-instant deepseek-ai/deepseek-v4-flash-0731 cerebras:llama3.1-8b' < "$TMP/home/config"
check "pool remove" "Groq entfernt – die Ketten wurden neu gebaut" < <(timeout 180 "$N" pool remove groq 2>&1)
grep -q '^GROQ_API_KEY=$' "$TMP/home/config" && pass "config: removed provider's key cleared" || fail "config: removed provider's key cleared"
nocheck "config: removed provider's ranks gone from the chains" "groq:" < "$TMP/home/config"
nocheck "litellm.yaml: removed provider gone" "GROQ_API_KEY" < "$Y"
check "pool remove twice" "Groq ist nicht im Pool" < <(timeout 20 "$N" pool remove groq 2>&1)
check "env key: GROQ_API_KEY from the environment counts as configured" "Groq +code #2" < <(GROQ_API_KEY=gsk_testkey_0123456789 NIMCTL_INTERACTIVE=0 timeout 180 "$N" pool auto >/dev/null 2>&1; GROQ_API_KEY=gsk_testkey_0123456789 NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
grep -q '^GROQ_API_KEY=gsk_testkey_0123456789$' "$TMP/home/config" && pass "env key: persisted by pool auto" || fail "env key: persisted by pool auto"
timeout 180 "$N" pool remove groq >/dev/null 2>&1; timeout 180 "$N" pool remove cerebras >/dev/null 2>&1
check "pool: back to NVIDIA-only chains" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
