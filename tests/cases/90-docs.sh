# shellcheck shell=bash
# README.md stays in sync with the code: every command in `nimctl help`, every user-facing NIMCTL_* variable, every
# relative link, the bash requirement and the changelog entry for the current version.
README="$ROOT/README.md"
missing=(); for c in $(NIMCTL_LANG=en timeout 10 "$N" help | awk '/^  [a-z]/{print $1}'); do grep -q "\`nimctl $c" "$README" || missing+=("$c"); done
((${#missing[@]} == 0)) && pass "README documents every command from nimctl help" || fail "README misses commands: ${missing[*]}"
# internal variables (passed to helper processes or printed by `nimctl env`) are not configuration and need no README entry
INTERNAL=" NIMCTL_ NIMCTL_CAND_ NIMCTL_WEB_BIN NIMCTL_WEB_KEYS NIMCTL_WORKSPACE_FILE NIMCTL_RPM_STATE NIMCTL_SEARCH_URL NIMCTL_SEARXNG_REPO NIMCTL_ACCOUNTS_ADMIN NIMCTL_ACCOUNTS_DB NIMCTL_ACCOUNTS_EMAIL NIMCTL_ACCOUNTS_HASH NIMCTL_ACCOUNTS_PW NIMCTL_MODEL_CODE NIMCTL_MODEL_FAST NIMCTL_MODEL_CHAT NIMCTL_MODEL_REVIEW "
missing=(); for v in $(grep -oh 'NIMCTL_[A-Z_]*' "$ROOT"/src/*.sh "$ROOT/install.sh" | sort -u); do [[ "$INTERNAL" == *" $v "* ]] && continue; grep -q "$v" "$README" || missing+=("$v"); done
((${#missing[@]} == 0)) && pass "README documents every NIMCTL_* variable" || fail "README misses variables: ${missing[*]}"
missing=(); while read -r f; do [[ -e "$ROOT/$f" ]] || missing+=("$f"); done < <(grep -oE '\]\([A-Za-z0-9_./-]+\)' "$README" | sed 's/^](//;s/)$//' | grep -v '^http' | sort -u)
((${#missing[@]} == 0)) && pass "README relative links resolve" || fail "README links broken: ${missing[*]}"
grep -q 'bash ≥ 4.4' "$README" && grep -q 'bash-4.4' "$README" && pass "README states the bash 4.4 requirement" || fail "README bash requirement"
v=$(grep -m1 '^VERSION=' "$N" | cut -d'"' -f2); grep -q "^## \[$v\]" "$ROOT/CHANGELOG.md" && pass "CHANGELOG has an entry for $v" || fail "CHANGELOG entry for $v"
grep -q "NVIDIA NIM $v " "$README" && pass "README demo shows the current version $v" || fail "README demo version is stale (expected $v)"
check "--yes answers a destructive question in a terminal too" "gelöscht|deleted|Konten|accounts" < <(NIMCTL_LANG=de timeout 20 "$N" chat reset --yes 2>&1)
check "--lang with a space" "^Usage:" < <(timeout 10 "$N" --lang en help)
# the dashboard mock-up in the README lists the same footer keys as the real dashboard
real=$(printf 'q\n' | NIMCTL_LANG=en timeout 30 "$N" 2>/dev/null | strip | grep -E '^  (Services|Models|Use|System) ' | sed 's/  */ /g' | head -n 4)
doc=$(awk '/^\$ nimctl$/{p=1} p && /^```$/{exit} p' "$README" | grep -E '^  (Services|Models|Use|System) ' | sed 's/  */ /g' | head -n 4)
[[ "$real" == "$doc" ]] && pass "README dashboard footer matches the real one" || { fail "README dashboard footer differs"; printf '       | real: %s\n       | doc:  %s\n' "$real" "$doc"; }
