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
check "pool add: code stays NVIDIA-only – Groq's free tier takes no 32k request" "Ausweich in dieser Reihenfolge: zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b" < "$TMP/pool.txt"
check "pool add: Groq's kimi-k2 takes rank 1 for chat – the ranking decides, not the provider" "chat → groq:moonshotai/kimi-k2-instruct-0905 \(" < "$TMP/pool.txt"
check "pool add: the chat chain mixes providers by rank" "chat → groq:moonshotai/kimi-k2-instruct-0905 \(.*Ausweich in dieser Reihenfolge: groq:llama-3.3-70b-versatile nvidia/nemotron-3-super-120b deepseek-ai/deepseek-v4-flash-0731" < <(tr '\n' ' ' < "$TMP/pool.txt")
check "pool add: a Groq model whose per-minute token limit is below the slot's request is left out" "groq:openai/gpt-oss-120b nimmt keine 8k-Anfrage – für Slot chat ungeeignet" < "$TMP/pool.txt"
check "pool add: the provider's reason is shown" "Request too large for model .openai/gpt-oss-120b. .*Limit 8000, Requested [0-9]+" < "$TMP/pool.txt"
check "pool add: done" "Groq ist dabei – die Ketten wurden neu gebaut" < "$TMP/pool.txt"
grep -q '^GROQ_API_KEY=gsk_testkey_0123456789$' "$TMP/home/config" && pass "config: groq key saved" || fail "config: groq key saved"
check "config: code chain without Groq" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
check "config: chat chain with Groq ranks" '^CHAIN_CHAT=groq:moonshotai/kimi-k2-instruct-0905 groq:llama-3.3-70b-versatile nvidia/nemotron-3-super-120b deepseek-ai/deepseek-v4-flash-0731 nvidia/nemotron-3-ultra-550b-a55b meta/llama-4-maverick-17b-128e-instruct$' < "$TMP/home/config"
awk -F'\t' '$1=="groq:moonshotai/kimi-k2-instruct-0905" && $2=="ok"' "$TMP/home/probes" | grep -q . && pass "probes: namespaced pool id" || fail "probes: namespaced pool id"
awk -F'\t' '$1=="groq:openai/gpt-oss-120b" && $2=="8000" && $3 ~ /too large/' "$TMP/home/sizes" | grep -q . && pass "sizes: Groq's rejection cached with the reason" || fail "sizes: Groq's rejection cached with the reason"
awk -F'\t' '$1=="groq:moonshotai/kimi-k2-instruct-0905" && $2=="8000" && $3=="ok"' "$TMP/home/sizes" | grep -q . && pass "sizes: Groq's kimi-k2 takes an 8k request" || fail "sizes: Groq's kimi-k2 takes an 8k request"
Y="$TMP/home/litellm.yaml"
grep -A1 'model_name: nim-chat$' "$Y" | grep -q "model: custom_openai/moonshotai/kimi-k2-instruct-0905, api_base: http://127.0.0.1:$GP/v1, api_key: os.environ/GROQ_API_KEY, timeout: 60," && pass "litellm.yaml: rank 1 of chat is its own group at Groq with Groq's key" || { fail "litellm.yaml: rank 1 of chat"; grep -A1 'nim-chat$' "$Y"; }
check "litellm.yaml: rank 1 falls down the chain, then to the fast model" 'fallbacks: \[ \{ nim-code: \["nim-code-r2", "nim-code-r3", "nim-code-r4", "nim-fast"\] \}' < "$Y"
check "litellm.yaml: the last rank falls to the fast model only" '\{ nim-code-r4: \["nim-fast"\] \}' < "$Y"
check "litellm.yaml: the review chain ends at the code model" '\{ nim-review-r[0-9]: \["nim-code"\] \}' < "$Y"
check "litellm.yaml: cooldowns are the hook's job" "disable_cooldowns: true" < "$Y"
check "litellm.yaml: a stall is not retried on the same rank" "TimeoutErrorRetries: 0, DefaultRetries: 0, RateLimitErrorRetries: 1" < "$Y"
check "litellm.yaml: pool model reachable by its namespaced id" "model_name: groq:moonshotai/kimi-k2-instruct-0905$" < "$Y"
nocheck "litellm.yaml: pool ids never become NVIDIA entries" "custom_openai/groq:" < "$Y"
check "chains.json: groups → models for the hook" '"nim-chat":"groq:moonshotai/kimi-k2-instruct-0905"' < <(jq -c .models "$TMP/home/chains.json")
check "chains.json: NVIDIA groups listed for the budget" '"nim-code","nim-code-r2","nim-code-r3","nim-code-r4"' < <(jq -c .nim "$TMP/home/chains.json")
nocheck "chains.json: Groq's chat ranks are not NVIDIA's budget" '"nim-chat"[,\]]|"nim-chat-r2"' < <(jq -c .nim "$TMP/home/chains.json")
NIMCTL_STALL_TIMEOUT=45 timeout 120 "$N" pool auto >/dev/null 2>&1
check "NIMCTL_STALL_TIMEOUT sets the deployment timeout" "timeout: 45, additional_drop_params" < "$Y"
timeout 60 "$N" start >/dev/null 2>&1
check "proxy: pool key in its environment" "pool=groq" < "$TMP/home/logs/litellm.log"
check "status --json: chain per slot" '"chain":\["groq:moonshotai/kimi-k2-instruct-0905","groq:llama-3.3-70b-versatile"' < <(timeout 20 "$N" status --json | jq -c .slots.chat)
check "status --json: pool ranks" '"groq":\{"ranks":\[\{"slot":"chat","rank":1,"model":"moonshotai/kimi-k2-instruct-0905"\},\{"slot":"chat","rank":2,"model":"llama-3.3-70b-versatile"\}' < <(timeout 20 "$N" status --json | jq -c .pool)
check "dashboard: pool row counts the ranks held" "Pool +. Groq \(2\)" < <(timeout 20 "$N" status)
check "dashboard: slots show their fallback ranks" "code +deepseek-ai/deepseek-v4-pro-0813 .*\+3 Ausweich" < <(timeout 20 "$N" status)
check "pool test: round trips through the proxy" "nim-code \(tools\) →" < <(timeout 60 "$N" pool test 2>&1)
check "code --model groq:…: pool id handed to claude" "MODEL=groq:moonshotai/kimi-k2-instruct-0905" < <(cd "$TMP/home" && timeout 60 "$N" code --model groq:moonshotai/kimi-k2-instruct-0905 2>&1)
check "test: a pool id is sent to its provider" "Moin from openai/gpt-oss-120b" < <(timeout 30 "$N" test groq:openai/gpt-oss-120b "hi" 2>&1)
check "doctor: pool key checked" "Pool Groq: gültig" < <(timeout 120 "$N" doctor 2>&1)
timeout 30 "$N" stop >/dev/null 2>&1
timeout 180 "$N" pool add cerebras csk-testkey-0123456789 >/dev/null 2>&1
check "config: a second provider takes its ranks in the chains" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 cerebras:gpt-oss-120b nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
check "pool overview: ranks per provider" "Cerebras +code #3 gpt-oss-120b +fast #2 llama3.1-8b" < <(NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
check "pool models: provider catalog" "^qwen-3-235b-a22b-instruct-2507$" < <(timeout 20 "$N" pool models cerebras)
timeout 60 "$N" pick fast groq:llama-3.1-8b-instant >"$TMP/pick.txt" 2>&1
check "pick: an exact id becomes rank 1, the chain moves down" "fast → groq:llama-3.1-8b-instant" < "$TMP/pick.txt"
check "pick: warns when the model takes no request of the slot's size, sets it anyway" "groq:llama-3.1-8b-instant nimmt keine 12k-Anfrage \(Request too large .*trotzdem gesetzt" < "$TMP/pick.txt"
check "config: pick moved the model to the head of the chain" '^CHAIN_FAST=groq:llama-3.1-8b-instant deepseek-ai/deepseek-v4-flash-0731 cerebras:llama3.1-8b' < "$TMP/home/config"
check "pool remove" "Groq entfernt – die Ketten wurden neu gebaut" < <(timeout 180 "$N" pool remove groq 2>&1)
grep -q '^GROQ_API_KEY=$' "$TMP/home/config" && pass "config: removed provider's key cleared" || fail "config: removed provider's key cleared"
nocheck "config: removed provider's ranks gone from the chains" "groq:" < "$TMP/home/config"
nocheck "litellm.yaml: removed provider gone" "GROQ_API_KEY" < "$Y"
check "pool remove twice" "Groq ist nicht im Pool" < <(timeout 20 "$N" pool remove groq 2>&1)
check "env key: GROQ_API_KEY from the environment counts as configured" "Groq +chat #1" < <(GROQ_API_KEY=gsk_testkey_0123456789 NIMCTL_INTERACTIVE=0 timeout 180 "$N" pool auto >/dev/null 2>&1; GROQ_API_KEY=gsk_testkey_0123456789 NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
grep -q '^GROQ_API_KEY=gsk_testkey_0123456789$' "$TMP/home/config" && pass "env key: persisted by pool auto" || fail "env key: persisted by pool auto"
timeout 180 "$N" pool remove groq >/dev/null 2>&1; timeout 180 "$N" pool remove cerebras >/dev/null 2>&1
check "pool: back to NVIDIA-only chains" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
