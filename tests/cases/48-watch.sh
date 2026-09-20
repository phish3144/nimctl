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
assert "completion: no argument exits 64 (usage error)" [ $? -eq 64 ]
rm -f "$TMP/.bashrc"; : >"$TMP/.zshrc"
timeout 10 "$N" install completion >/dev/null 2>&1
grep -qF 'nimctl completion bash' "$TMP/.bashrc" && pass "completion install: bashrc line added" || fail "completion install: bashrc line added"
grep -qF 'nimctl completion zsh' "$TMP/.zshrc" && pass "completion install: zshrc line added" || fail "completion install: zshrc line added"
timeout 10 "$N" install completion >/dev/null 2>&1
[[ $(grep -c 'nimctl completion bash' "$TMP/.bashrc") -eq 1 ]] && pass "completion install: idempotent" || fail "completion install: idempotent"

# restore config for any later test files
sed -i 's#^MODEL_FAST=.*#MODEL_FAST=deepseek-ai/deepseek-v4-flash-0731#' "$TMP/home/config"
# autopilot: the nightly run by hand (no self-update here: the mock update server carries a fake 99.0.0)
check "autopilot: scans, takes finds over, rebuilds the chains, reports" "Autopilot fertig in [0-9]+ s" < <(NIMCTL_AUTOPILOT_UPDATE=0 NIMCTL_INTERACTIVE=0 timeout 600 "$N" autopilot 2>&1)
check "autopilot.json: report with providers, summary and time" '"providers":\["nim".*"summary":"' < <(jq -c '{providers, summary, at, seconds, errors}' "$TMP/home/autopilot.json")
check "autopilot: log line" "^[0-9-]+ [0-9:]+ " < "$TMP/home/logs/autopilot.log"
check "autopilot: dashboard line" "Autopilot [0-9.]+ [0-9:]+ · .* · nächster Lauf gegen 3 Uhr" < <(NIMCTL_AUTOPILOT=1 timeout 20 "$N" status 2>&1)
check "autopilot: off in the dashboard line when disabled" "Autopilot .* · aus \(NIMCTL_AUTOPILOT=0\), nur von Hand" < <(NIMCTL_AUTOPILOT=0 timeout 20 "$N" status 2>&1)
n0=$(wc -l <"$TMP/home/logs/autopilot.log")
NIMCTL_AUTOPILOT=1 NIMCTL_AUTOPILOT_HOUR=$(date +%H) NIMCTL_AUTOPILOT_UPDATE=0 timeout 600 "$N" watch --quiet >/dev/null 2>&1
[[ $(wc -l <"$TMP/home/logs/autopilot.log") -eq "$n0" ]] && pass "watch: no autopilot run within 20 h of the last one" || fail "watch: no autopilot run within 20 h of the last one"
rm -f "$TMP/home/autopilot.json"; NIMCTL_AUTOPILOT=1 NIMCTL_AUTOPILOT_HOUR=$(date +%H) NIMCTL_AUTOPILOT_UPDATE=0 timeout 600 "$N" watch --quiet >"$TMP/watch-ap.txt" 2>&1
[[ $(wc -l <"$TMP/home/logs/autopilot.log") -eq $((n0 + 1)) && -s "$TMP/home/autopilot.json" ]] && pass "watch: starts the autopilot in its hour when it has not run today" || fail "watch: starts the autopilot in its hour"
rm -f "$TMP/home/autopilot.json"; NIMCTL_AUTOPILOT=1 NIMCTL_AUTOPILOT_HOUR=$(( ($(date +%H | sed 's/^0//') + 5) % 24 )) NIMCTL_AUTOPILOT_UPDATE=0 timeout 600 "$N" watch --quiet >/dev/null 2>&1
[[ -f "$TMP/home/autopilot.json" ]] && fail "watch: no autopilot outside its hours" || pass "watch: no autopilot outside its hours"
rm -f "$TMP/home/autopilot.json"; NIMCTL_AUTOPILOT=0 NIMCTL_AUTOPILOT_HOUR=$(date +%H) timeout 600 "$N" watch --quiet >/dev/null 2>&1
[[ -f "$TMP/home/autopilot.json" ]] && fail "watch: no autopilot when switched off" || pass "watch: no autopilot when switched off"
timeout 300 "$N" scan --clear >/dev/null 2>&1   # the finds the autopilot took over would otherwise show up in the web tests' rankings
[[ -f "$TMP/home/discovered" ]] && fail "autopilot: taken-over models cleared again" || pass "autopilot: taken-over models cleared again"
# launchd: the watchdog timer on a Mac (fake launchctl, no systemctl on PATH)
mkdir -p "$TMP/launchbin"; printf '#!/usr/bin/env bash\necho "launchctl $*" >>"%s/launchctl.log"\n' "$TMP" >"$TMP/launchbin/launchctl"; chmod +x "$TMP/launchbin/launchctl"
check "install watch_timer: launchd agent when there is no systemd" "Watchdog aktiv \(launchd" < <(NIMCTL_TIMER=launchd PATH="$TMP/launchbin:$PATH" timeout 30 "$N" install watch_timer 2>&1)
grep -q '<string>watch</string><string>--quiet</string>' "$TMP/Library/LaunchAgents/nimctl.watch.plist" && grep -q "load -w $TMP/Library/LaunchAgents/nimctl.watch.plist" "$TMP/launchctl.log" && pass "launchd: plist written and loaded" || fail "launchd: plist written and loaded"
