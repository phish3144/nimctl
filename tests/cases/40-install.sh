# shellcheck shell=bash
# install.sh in local-clone mode: copies the script, PATH lines for bash and zsh, idempotent, no wizard without a terminal.
IH="$TMP/ihome"; mkdir -p "$IH"; touch "$IH/.zshrc"
check "install: copies nimctl and reports" "nimctl installed" < <(HOME="$IH" NIMCTL_INTERACTIVE='' timeout 30 bash "$ROOT/install.sh" </dev/null 2>&1)
[[ -x "$IH/.local/bin/nimctl" ]] && pass "install: ~/.local/bin/nimctl executable" || fail "install: ~/.local/bin/nimctl executable"
grep -q '.local/bin' "$IH/.bashrc" && grep -q '.local/bin' "$IH/.zshrc" && pass "install: PATH line in .bashrc and .zshrc" || fail "install: PATH lines"
HOME="$IH" NIMCTL_INTERACTIVE='' timeout 30 bash "$ROOT/install.sh" </dev/null >/dev/null 2>&1
[[ $(grep -c '.local/bin' "$IH/.bashrc") -eq 1 ]] && pass "install: idempotent PATH line" || fail "install: idempotent PATH line"
