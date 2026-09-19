# shellcheck shell=bash
# install.sh in local-clone mode: copies the script, PATH lines for bash and zsh, idempotent, no wizard without a terminal.
IH="$TMP/ihome"; mkdir -p "$IH"; touch "$IH/.zshrc"
check "install: copies nimctl and reports" "nimctl installed" < <(HOME="$IH" NIMCTL_INTERACTIVE='' timeout 30 bash "$ROOT/install.sh" </dev/null 2>&1)
[[ -x "$IH/.local/bin/nimctl" ]] && pass "install: ~/.local/bin/nimctl executable" || fail "install: ~/.local/bin/nimctl executable"
grep -q '.local/bin' "$IH/.bashrc" && grep -q '.local/bin' "$IH/.zshrc" && pass "install: PATH line in .bashrc and .zshrc" || fail "install: PATH lines"
HOME="$IH" NIMCTL_INTERACTIVE='' timeout 30 bash "$ROOT/install.sh" </dev/null >/dev/null 2>&1
[[ $(grep -c '.local/bin' "$IH/.bashrc") -eq 1 ]] && pass "install: idempotent PATH line" || fail "install: idempotent PATH line"
# install alias: ~/.local/bin/nimctl must survive every way of running nimctl (a symlinked home once produced a self-referencing link)
IL="$TMP/ihome-link"; ln -sfn "$IH" "$IL"
check "install alias: same file through a symlinked home – left alone" "Befehle verfügbar" < <(HOME="$IL" NIMCTL_INTERACTIVE=0 timeout 20 "$IH/.local/bin/nimctl" install alias 2>&1)
[[ -f "$IH/.local/bin/nimctl" && ! -L "$IH/.local/bin/nimctl" && -x "$IH/.local/bin/nimctl" ]] && pass "install alias: the copy is still a plain executable file" || fail "install alias: the copy is still a plain executable file"
check "install alias: run from a download elsewhere – copied, the download may go away" "Befehle verfügbar" < <(cp "$N" "$TMP/nimctl-download"; HOME="$IH" NIMCTL_INTERACTIVE=0 timeout 20 bash "$TMP/nimctl-download" install alias 2>&1)
[[ ! -L "$IH/.local/bin/nimctl" ]] && cmp -s "$N" "$IH/.local/bin/nimctl" && [[ -x "$IH/.local/bin/nimctl" ]] && pass "install alias: ~/.local/bin/nimctl is a copy of the download, executable" || fail "install alias: copy of the download"
rm -f "$TMP/nimctl-download"; HOME="$IH" NIMCTL_INTERACTIVE=0 timeout 20 "$IH/.local/bin/nimctl" --version >/dev/null 2>&1 && pass "install alias: still runs after the download is gone" || fail "install alias: still runs after the download is gone"
check "install alias: run from the clone – a symlink, so edits count" "Befehle verfügbar" < <(HOME="$IH" NIMCTL_INTERACTIVE=0 timeout 20 "$N" install alias 2>&1)
[[ -L "$IH/.local/bin/nimctl" && "$(readlink -f "$IH/.local/bin/nimctl")" == "$(readlink -f "$N")" ]] && pass "install alias: symlink into the clone" || fail "install alias: symlink into the clone"
check "install alias: the shell that started it has no ~/.local/bin yet – says so" "noch nicht im PATH – neues Terminal öffnen oder:  export PATH" < <(PATH="/usr/bin:/bin" HOME="$IH" NIMCTL_INTERACTIVE=1 timeout 20 "$N" install alias 2>&1)
nocheck "install alias: no hint when the shell already finds nimctl" "noch nicht im PATH" < <(PATH="$IH/.local/bin:/usr/bin:/bin" HOME="$IH" NIMCTL_INTERACTIVE=1 timeout 20 "$N" install alias 2>&1)
check "install.sh from the clone over a symlink: replaces it with a copy" "nimctl installed" < <(HOME="$IH" NIMCTL_INTERACTIVE='' timeout 30 bash "$ROOT/install.sh" </dev/null 2>&1)
[[ -f "$IH/.local/bin/nimctl" && ! -L "$IH/.local/bin/nimctl" ]] && pass "install.sh: plain file again" || fail "install.sh: plain file again"
