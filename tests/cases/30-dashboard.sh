# shellcheck shell=bash
# Dashboard interactions (piped input = one command per line), doctor, key handling, i18n, update.
check "pick: manual slot code → glm" "code → zai-org/glm-5.3" < <(printf '1\nglm\n1\n\nq\n' | timeout 60 "$N")
check "pick: dead model refused" "nicht geändert" < <(printf '1\nkimi-k2\n1\n\n\nq\n' | timeout 60 "$N")
check "pick: invalid number reported" "ungültige Eingabe: 99" < <(printf '1\nglm\n99\n\nq\n' | timeout 60 "$N")
grep -q '^MODEL_CODE=zai-org/glm-5.3$' "$TMP/home/config" && pass "pick persisted" || fail "pick persisted"
check "dashboard: auto-select" "code → deepseek-ai/deepseek-v4-pro-0813" < <(printf 'a\n\nq\n' | timeout 180 "$N")
check "dashboard: last action panel" "Letzte Aktion" < <(printf 'p\nq\n' | timeout 60 "$N")
check "dashboard: help key" "Tasten" < <(printf '?\n\nq\n' | timeout 30 "$N")
check "dashboard: footer groups" "Dienste +s Start +x Stop +r Neustart" < <(printf 'q\n' | timeout 30 "$N")
check "dashboard: unknown key" "unbekannte Taste: y" < <(printf 'y\nq\n' | timeout 30 "$N")
check "dashboard: 4 slots shown" "4 +review +nvidia/nemotron-3-ultra" < <(printf 'q\n' | COLUMNS=120 timeout 30 "$N")
check "key: wrong key keeps old" "alter Key bleibt" < <(printf 'k\nnvapi-wrong\n\nq\n' | timeout 30 "$N")
check "key: same key changes nothing" "gleicher Key" < <(printf 'k\nnvapi-testkey\n\nq\n' | timeout 30 "$N")
awk -F'\t' '$2=="ok"' "$TMP/home/probes" | grep -q . && pass "key: re-entering same key keeps probes" || fail "key: re-entering same key keeps probes"
check "key: cli set" "gleicher Key" < <(timeout 30 "$N" key nvapi-testkey)
check "key: cli bad prefix" "muss mit nvapi-" < <(timeout 30 "$N" key abc)
timeout 20 "$N" </dev/null >/dev/null; assert "EOF exits cleanly" [ $? -eq 0 ]
check "doctor: all green" "Alles in Ordnung" < <(printf 'n\n' | timeout 60 "$N" doctor)
sed -i 's#^MODEL_CODE=.*#MODEL_CODE=moonshotai/kimi-k2.6#' "$TMP/home/config"
printf 'j\n' | timeout 180 "$N" doctor >"$TMP/doc.txt" 2>&1
check "doctor: detects dead slot" "kimi-k2.6 – kein Endpoint" < "$TMP/doc.txt"
check "doctor: summarises before asking" "1 Problem\(e\): model:code" < "$TMP/doc.txt"
check "doctor: repairs via auto-select" "code → deepseek-ai/deepseek-v4-pro-0813" < "$TMP/doc.txt"
sed -i 's#^MODEL_CODE=.*#MODEL_CODE=moonshotai/kimi-k2.6#' "$TMP/home/config"
check "doctor --fix: non-interactive repair" "code → deepseek-ai/deepseek-v4-pro-0813" < <(timeout 180 "$N" doctor --fix </dev/null)
check "doctor: empty stdin never answers yes" "1 Problem" < <(sed -i 's#^MODEL_CODE=.*#MODEL_CODE=moonshotai/kimi-k2.6#' "$TMP/home/config"; NIMCTL_INTERACTIVE=0 timeout 120 "$N" doctor </dev/null; sed -i 's#^MODEL_CODE=.*#MODEL_CODE=deepseek-ai/deepseek-v4-pro-0813#' "$TMP/home/config")
check "i18n: english" "Key +✓ valid" < <(NIMCTL_LANG=en timeout 20 "$N" status)
check "i18n: default is english for C locale" "^Usage:" < <(NIMCTL_LANG='' LANG=C timeout 10 "$N" help)
check "i18n: default is english for fr_FR" "^Usage:" < <(NIMCTL_LANG='' LANG=fr_FR.UTF-8 timeout 10 "$N" help)
check "i18n: german locale" "^Nutzung:" < <(NIMCTL_LANG='' LANG=de_DE.UTF-8 timeout 10 "$N" help)
check "i18n: --lang flag" "^Usage:" < <(timeout 10 "$N" --lang=en help)
check "no-color: ascii glyphs without UTF-8" "Key +\+ gültig" < <(LC_ALL=C LANG=C timeout 20 "$N" status)
# config injection: a crafted model id must never be executed or written
printf 'NVIDIA_API_KEY=nvapi-testkey\nMODEL_CODE="x"; touch %s/PWNED; :\nMODEL_CHAT=nvidia/nemotron-3-super-120b\n' "$TMP" >"$TMP/home/config"
timeout 20 "$N" status >/dev/null 2>&1
[[ -e "$TMP/PWNED" ]] && fail "config is not executed" || pass "config is not executed"
check "config: invalid model id dropped" "code +– +· nicht gewählt" < <(timeout 20 "$N" status)
sed -i 's#^MODEL_CODE=.*#MODEL_CODE=deepseek-ai/deepseek-v4-pro-0813#' "$TMP/home/config"
# self-update against the local mock server
cp "$N" "$TMP/update/nimctl"; cp "$ROOT/SHA256SUMS" "$TMP/update/SHA256SUMS"; cp "$ROOT/CHANGELOG.md" "$TMP/update/CHANGELOG.md"
check "update: already current" "ist aktuell" < <(timeout 30 "$N" update)
sed "s/^VERSION=\"[0-9.]*\"/VERSION=\"99.0.0\"/" "$N" >"$TMP/update/nimctl"; (cd "$TMP/update" && sha256sum nimctl >SHA256SUMS)
printf '# Changelog\n\n## [99.0.0] – 2099-01-01\n\n### Added\n- Flux capacitor\n\n## [%s] – 2026-09-14\n\n- current\n' "$(grep -m1 '^VERSION=' "$N" | cut -d'"' -f2)" >"$TMP/update/CHANGELOG.md"
check "update --check: shows changelog" "Flux capacitor" < <(timeout 30 "$N" update --check)
cp "$N" "$TMP/bin/nimctl-copy"; chmod +x "$TMP/bin/nimctl-copy"
check "update: checksum verified and installed" "Prüfsumme stimmt.*|aktualisiert: .* → 99.0.0" < <(printf 'j\n' | timeout 30 "$TMP/bin/nimctl-copy" update)
grep -q 'VERSION="99.0.0"' "$TMP/bin/nimctl-copy" && pass "update: file replaced" || fail "update: file replaced"
[[ -f "$TMP/bin/nimctl-copy.bak" ]] && pass "update: backup kept" || fail "update: backup kept"
echo "deadbeef  nimctl" >"$TMP/update/SHA256SUMS"; cp "$N" "$TMP/bin/nimctl-copy"
check "update: checksum mismatch refused" "Prüfsumme stimmt nicht" < <(printf 'j\n' | timeout 30 "$TMP/bin/nimctl-copy" update)
