# shellcheck shell=bash
# Scan: whole catalogs at a pace (NIMCTL_SCAN_RPM=600 here: one block, no pauses), tool calling for the responders, a
# table per provider, models outside the rankings that qualify for a slot, --use appends them (~/.nimctl/discovered),
# --clear removes them. The per-provider cap gives a provider its ranks before NVIDIA's third model.
timeout 180 "$N" pool add mistral mstr_testkey_0123456789 >"$TMP/mistral.txt" 2>&1
check "pool add mistral: the per-provider cap gives Mistral rank 3 for code, ahead of NVIDIA's third model" "Ausweich in dieser Reihenfolge: zai-org/glm-5.3 mistral:devstral-medium-2507 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b" < "$TMP/mistral.txt"
check "config: chat chain – Mistral's medium model takes rank 3 after NVIDIA's two" '^CHAIN_CHAT=nvidia/nemotron-3-super-120b deepseek-ai/deepseek-v4-flash-0731 mistral:mistral-medium-latest nvidia/nemotron-3-ultra-550b-a55b meta/llama-4-maverick-17b-128e-instruct$' < "$TMP/home/config"
check "config: fast chain – Mistral small in, NVIDIA fills up behind" '^CHAIN_FAST=deepseek-ai/deepseek-v4-flash-0731 nvidia/nemotron-3.5-lightning-30b-a3b mistral:mistral-small-latest nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
check "pool overview: Mistral holds one rank per slot" "Mistral +code #3 devstral-medium-2507 +fast #3 mistral-small-latest +chat #3 mistral-medium-latest +review #3 magistral-medium-latest" < <(NIMCTL_INTERACTIVE=0 timeout 20 "$N" pool 2>&1)
NIMCTL_INTERACTIVE=0 timeout 300 "$N" scan mistral >"$TMP/scan.txt" 2>&1
check "scan: catalog counted, non-chat entries left out" "Mistral: 8 Modelle im Katalog, 6 davon Chat-Modelle" < "$TMP/scan.txt"
check "scan: pace line" "600 Anfragen/min in Blöcken von 100" < "$TMP/scan.txt"
check "scan: rows with latency, tool calling" "mistral:mistral-large-latest +antwortet [0-9]+ ms +Tools ✓" < "$TMP/scan.txt"
nocheck "scan: embeddings and moderation not probed" "mistral-embed|mistral-moderation" < "$TMP/scan.txt"
check "scan: summary row" "Mistral +6 von +6 antworten, +6 mit Tool-Calls" < "$TMP/scan.txt"
check "scan: models outside the rankings that qualify for code" "Zusätzlich geeignet für code \(in keiner Rangliste\): .*mistral:mistral-large-latest" < "$TMP/scan.txt"
nocheck "scan: a model already in the slot's ranking is not listed again" "geeignet für code .*mistral:devstral-medium-2507" < "$TMP/scan.txt"
check "scan: hint how to take them over" "nimctl scan mistral --use" < "$TMP/scan.txt"
[[ -f "$TMP/home/discovered" ]] && fail "scan: nothing written without --use" || pass "scan: nothing written without --use"
NIMCTL_INTERACTIVE=0 timeout 300 "$N" scan mistral --use >"$TMP/scan-use.txt" 2>&1
check "scan --use: taken over and chains rebuilt" "übernommen – die Ketten werden neu gebaut" < "$TMP/scan-use.txt"
check "discovered: code line holds the large model" "^code: .*mistral:mistral-large-latest" < "$TMP/home/discovered"
check "config: code chain – Mistral's cap is two, then NVIDIA and the rest fill up to eight" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 mistral:devstral-medium-2507 mistral:[a-z0-9.-]+ nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b mistral:[a-z0-9.-]+ mistral:[a-z0-9.-]+$' < "$TMP/home/config"
check "web candidates: the effective ranking shows the discovered models" '"code":".* mistral:mistral-large-latest' < <(timeout 20 "$N" web candidates | jq -c .)
check "scan --clear: discovered models removed, chains rebuilt" "zusätzliche Modelle aus den Ranglisten entfernt" < <(timeout 300 "$N" scan --clear 2>&1)
[[ -f "$TMP/home/discovered" ]] && fail "scan --clear: file removed" || pass "scan --clear: file removed"
check "config: code chain back to the ranking" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 mistral:devstral-medium-2507 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
NIMCTL_INTERACTIVE=0 timeout 300 "$N" scan nvidia >"$TMP/scan-nv.txt" 2>&1
check "scan nvidia: catalog counted, the embedding model left out" "NVIDIA: 14 Modelle im Katalog, 13 davon Chat-Modelle" < "$TMP/scan-nv.txt"
nocheck "scan nvidia: embedding model not probed" "nv-embedqa" < "$TMP/scan-nv.txt"
check "scan nvidia: dead and overloaded models in the rows" "kimi-k2.6 +kein Endpoint" < "$TMP/scan-nv.txt"
check "scan nvidia: summary" "NVIDIA +[0-9]+ von +13 antworten" < "$TMP/scan-nv.txt"
check "scan: unknown provider" "unbekannter Anbieter: foo" < <(timeout 20 "$N" scan foo 2>&1)
timeout 20 "$N" scan foo >/dev/null 2>&1; assert "scan: unknown provider rc=64" [ $? -eq 64 ]
check "help: scan listed" "^  scan +.*--use" < <(NIMCTL_LANG=en timeout 10 "$N" help)
timeout 180 "$N" pool remove mistral >/dev/null 2>&1
check "pool remove mistral: back to NVIDIA-only chains" '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' < "$TMP/home/config"
