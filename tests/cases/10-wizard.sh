# shellcheck shell=bash
# First run → wizard: key (wrong, then right), tools present, union probing, tool-calling check, services declined.
check "version" "^nimctl [0-9]" < <(timeout 10 "$N" version)
check "help lists commands" "^  doctor +.*--fix" < <(timeout 10 "$N" help)
check "help per command" "nimctl code" < <(timeout 10 "$N" help code)
check "unknown command exits 2" "unbekannt" < <(timeout 10 "$N" frobnicate; echo "rc=$?")
timeout 10 "$N" frobnicate >/dev/null 2>&1; assert "unknown command rc=64 (usage error)" [ $? -eq 64 ]
# headless wizard without a key must stop, not spin
NIMCTL_INTERACTIVE='' timeout 10 "$N" setup </dev/null >"$TMP/eof.txt" 2>&1; rc=$?
assert "setup without stdin exits (no busy loop) rc=$rc" [ "$rc" -eq 1 ]
check "setup without stdin explains --yes" "NIMCTL_API_KEY=nvapi" < "$TMP/eof.txt"
# invalid key from the environment is reported, not silently accepted
check "setup: bad env key reported" "ungültig" < <(NIMCTL_INTERACTIVE='' NIMCTL_API_KEY=nvapi-wrong timeout 20 "$N" setup --yes </dev/null 2>&1)
# the interactive wizard
printf 'nvapi-wrong\nnvapi-testkey\nn\nj\nj\nj\nn\n' | timeout 180 "$N" >"$TMP/wiz.txt" 2>&1
check "wizard: rejects wrong key" "nicht akzeptiert" < "$TMP/wiz.txt"
check "wizard: accepts key" "gültig – gespeichert" < "$TMP/wiz.txt"
check "wizard: pool offered after the key" "Anbieter mit kostenlosen Kontingenten hinzufügen" < "$TMP/wiz.txt"
check "wizard: cold model times out first" "deepseek-v4-pro-0813 +Timeout nach 3s" < "$TMP/wiz.txt"
check "wizard: retries top candidate with 2x timeout" "Zweiter Versuch für deepseek-ai/deepseek-v4-pro-0813 mit 6s" < "$TMP/wiz.txt"
check "wizard: auto code = deepseek-v4-pro (after retry)" "code → deepseek-ai/deepseek-v4-pro-0813 \(" < "$TMP/wiz.txt"
check "wizard: tool calling probed for code" "prüfe Tool-Calling" < "$TMP/wiz.txt"
check "wizard: overloaded model mapped" "laguna-xs-2.1 +überlastet" < "$TMP/wiz.txt"
check "wizard: auto fast = deepseek-v4-flash" "fast → deepseek-ai/deepseek-v4-flash-0731 \(" < "$TMP/wiz.txt"
check "wizard: auto chat = nemotron-3-super" "chat → nvidia/nemotron-3-super-120b \(" < "$TMP/wiz.txt"
check "wizard: auto review = deepseek-v4-pro (kimi-k3 times out, gemini has no key)" "review → deepseek-ai/deepseek-v4-pro-0813 \(" < "$TMP/wiz.txt"
check "wizard: code chain lists the fallback ranks in ranking order" "Ausweich in dieser Reihenfolge: zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b" < "$TMP/wiz.txt"
grep -q '^CHAIN_CODE=deepseek-ai/deepseek-v4-pro-0813 zai-org/glm-5.3 nvidia/nemotron-3-ultra-550b-a55b nvidia/nemotron-3-super-120b$' "$TMP/home/config" && pass "config: code chain saved" || fail "config: code chain saved"
check "summary: +n fallback ranks per slot" "code +deepseek-ai/deepseek-v4-pro-0813 .*\+3 Ausweich" < "$TMP/wiz.txt"
check "wizard: a rank must take a request of the slot's size" "prüfe 32k-Anfrage bei deepseek-ai/deepseek-v4-pro-0813 … ✓ [0-9]+ ms" < "$TMP/wiz.txt"
check "wizard: a model with a small context window is left out of fast" "nemotron-3-nano-30b-a3b nimmt keine 12k-Anfrage – für Slot fast ungeeignet" < "$TMP/wiz.txt"
check "wizard: the provider's reason is shown" "maximum context length is 8192 tokens" < "$TMP/wiz.txt"
awk -F'\t' '$1=="nvidia/nemotron-3-nano-30b-a3b" && $2=="12000" && $3 ~ /8192/ && $4 ~ /^[0-9]+$/' "$TMP/home/sizes" | grep -q . && pass "sizes: rejection cached with the reason" || fail "sizes: rejection cached with the reason"
awk -F'\t' '$1=="deepseek-ai/deepseek-v4-pro-0813" && $2=="32000" && $3=="ok"' "$TMP/home/sizes" | grep -q . && pass "sizes: acceptance cached" || fail "sizes: acceptance cached"
check "find: request sizes shown next to the probe" "deepseek-v4-pro-0813 +antwortet [0-9]+ ms .*32k ✓" < <(timeout 30 "$N" find deepseek-v4-pro)
check "wizard: slow model timeout" "kimi-k3 .*Timeout nach 3s" < "$TMP/wiz.txt"
check "wizard: progress per slot" "Slot 4/4" < "$TMP/wiz.txt"
check "wizard: services declined stay down" "Fertig" < "$TMP/wiz.txt"
check "wizard: chat admin hint" "nimctl chat passwd" < "$TMP/wiz.txt"
check "wizard: IDE offered and Continue installed" "IDE aktiviert" < "$TMP/wiz.txt"
grep -q "fake code-server install Continue.continue" "$TMP/home/logs/code-server-install.log" && pass "wizard: Continue extension installed" || fail "wizard: Continue extension installed"
check "wizard: IDE url in the summary" "IDE: http://localhost:$IPT" < "$TMP/wiz.txt"
check "wizard: web search offered and installed" "Websuche aktiviert" < "$TMP/wiz.txt"
grep -q '^SEARCH_ENABLED=1$' "$TMP/home/config" && pass "wizard: search enabled in the config" || fail "wizard: search enabled in the config"
check "wizard: web UI offered and enabled" "Web-UI aktiviert" < "$TMP/wiz.txt"
grep -q '^WEB_ENABLED=1$' "$TMP/home/config" && pass "wizard: web UI enabled in the config" || fail "wizard: web UI enabled in the config"
grep -q '^MODEL_CODE=deepseek-ai/deepseek-v4-pro-0813$' "$TMP/home/config" && pass "config written (unquoted KEY=VALUE)" || fail "config written"
grep -q '^MASTER_KEY=sk-nimctl-[0-9a-f]\{48\}$' "$TMP/home/config" && pass "master key generated per install" || fail "master key generated"
[[ $(stat -c %a "$TMP/home/config") == 600 ]] && pass "config perms 600" || fail "config perms"
[[ $(stat -c %a "$TMP/home") == 700 ]] && pass "data dir perms 700" || fail "data dir perms 700"
grep -q 'KEY_SET_AT=[0-9]' "$TMP/home/state" && pass "key date recorded" || fail "key date recorded"
awk -F'\t' '$1=="deepseek-ai/deepseek-v4-pro-0813" && $2=="ok" && $4 ~ /^[0-9]+$/ && $5=="ok"' "$TMP/home/probes" | grep -q . && pass "probes: epoch + tools column" || fail "probes: epoch + tools column"
