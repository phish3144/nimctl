# shellcheck shell=bash
# watch: auto-replaces a dead slot model and logs the result; completion: bash/zsh scripts.
# Make sure all 4 slots are configured (an earlier file's config-injection test can blank some of them).
sed -i -e 's#^MODEL_CODE=.*#MODEL_CODE=deepseek-ai/deepseek-v4-pro-0813#' -e 's#^MODEL_CHAT=.*#MODEL_CHAT=nvidia/nemotron-3-super-120b#' \
       -e 's#^MODEL_REVIEW=.*#MODEL_REVIEW=nvidia/nemotron-3-ultra-550b-a55b#' -e 's#^MODEL_FAST=.*#MODEL_FAST=moonshotai/kimi-k2.6#' "$TMP/home/config"
timeout 60 "$N" watch >"$TMP/watch1.txt" 2>&1; rc1=$?
check "watch: reports the replacement" "replaced fast: moonshotai/kimi-k2.6" < "$TMP/watch1.txt"
assert "watch: exit 0 after replacing a dead slot" [ "$rc1" -eq 0 ]
grep -q '^MODEL_FAST=deepseek-ai/deepseek-v4-flash-0731$' "$TMP/home/config" && pass "watch: config has a live fast model" || fail "watch: config has a live fast model"
[[ -s "$TMP/home/logs/watch.log" ]] && pass "watch: log line written" || fail "watch: log line written"
tail -n1 "$TMP/home/logs/watch.log" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} replaced fast: moonshotai/kimi-k2.6 → deepseek-ai/deepseek-v4-flash-0731$' \
  && pass "watch: log line format" || fail "watch: log line format"

timeout 60 "$N" watch >"$TMP/watch2.txt" 2>&1; rc2=$?
nocheck "watch: second run replaces nothing" "replaced" < "$TMP/watch2.txt"
assert "watch: exit 0 when everything is healthy" [ "$rc2" -eq 0 ]
tail -n1 "$TMP/home/logs/watch.log" | grep -qE ' ok code fast chat review$' && pass "watch: second run logs an ok line" || fail "watch: second run logs an ok line"

NIMCTL_API_KEY=nvapi-wrong timeout 20 "$N" watch >"$TMP/watch3.txt" 2>&1; rc3=$?
check "watch: reports the bad key" "kein gültiger API-Key" < "$TMP/watch3.txt"
assert "watch: exit 1 with an invalid key" [ "$rc3" -eq 1 ]
tail -n1 "$TMP/home/logs/watch.log" | grep -q 'kein gültiger API-Key' && pass "watch: bad key logged" || fail "watch: bad key logged"

# completion
check "completion: lists known commands" "doctor" < <(timeout 10 "$N" completion bash)
check "completion: defines _nimctl" "_nimctl" < <(timeout 10 "$N" completion bash)
bash -c "eval \"\$('$N' completion bash)\"" >/dev/null 2>&1
assert "completion: bash script evaluates cleanly" [ $? -eq 0 ]
timeout 10 "$N" completion >/dev/null 2>&1
assert "completion: no argument exits 2" [ $? -eq 2 ]
rm -f "$TMP/.bashrc"; : >"$TMP/.zshrc"
timeout 10 "$N" install completion >/dev/null 2>&1
grep -qF 'nimctl completion bash' "$TMP/.bashrc" && pass "completion install: bashrc line added" || fail "completion install: bashrc line added"
grep -qF 'nimctl completion zsh' "$TMP/.zshrc" && pass "completion install: zshrc line added" || fail "completion install: zshrc line added"
timeout 10 "$N" install completion >/dev/null 2>&1
[[ $(grep -c 'nimctl completion bash' "$TMP/.bashrc") -eq 1 ]] && pass "completion install: idempotent" || fail "completion install: idempotent"

# restore config for any later test files
sed -i 's#^MODEL_FAST=.*#MODEL_FAST=deepseek-ai/deepseek-v4-flash-0731#' "$TMP/home/config"
