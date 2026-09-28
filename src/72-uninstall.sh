# ── Uninstall: take nimctl off the machine again ────────────────────────────────────────────────────────────
# `nimctl uninstall` stops every service, removes autostart and the watchdog timer (systemd or launchd), the command
# in ~/.local/bin and the completion lines the installer added to ~/.bashrc/~/.zshrc (a shell would otherwise complain
# on every start). The rest is asked for, or chosen with flags: --data removes ~/.nimctl (keys, config, logs, chats and
# uploads, the search engine, IDE data), --tools the programs the wizard installed (litellm, open-webui, code-server and
# the Continue config nimctl wrote), --claude Claude Code (npm); --all is all three, --keep-data keeps ~/.nimctl.
# --yes skips the questions and takes the defaults (keep), so `--yes` alone removes only nimctl itself; without a terminal
# the command needs --yes (or NIMCTL_YES=1). The PATH line in the rc files stays – other tools use it.
T_de+=(
  [h_uninstall]="nimctl entfernen: Dienste, Autostart, Befehl, Completion; dazu --data (~/.nimctl), --tools (litellm, open-webui, code-server), --claude oder --all; --yes = keine Fragen"
  [un_title]="nimctl entfernen" [un_plan]="Entfernt wird:" [un_base]="Dienste stoppen, Autostart und Watchdog-Timer, %s, Completion-Zeilen in ~/.bashrc/~/.zshrc"
  [un_data]="Daten: %s (Keys, Konfiguration, Logs, Chats und Uploads, Suchmaschine, IDE-Daten)" [un_tools]="Werkzeuge: litellm, open-webui, code-server (~/.local/lib), Continue-Konfiguration von nimctl"
  [un_claude]="Claude Code (npm uninstall -g @anthropic-ai/claude-code)" [un_keep]="bleibt: %s" [un_q_data]="Daten in %s löschen (Keys, Chats, Logs)?" [un_q_tools]="Werkzeuge deinstallieren (litellm, open-webui, code-server, Continue-Konfiguration)?"
  [un_q_claude]="Claude Code deinstallieren (npm)?" [un_confirm]="Wirklich entfernen?" [un_noninteractive]="kein Terminal – nimctl uninstall --yes [--all|--data|--tools|--claude|--keep-data]"
  [un_aborted]="nichts geändert" [un_removed]="entfernt: %s" [un_done]="nimctl ist entfernt. Neues Terminal öffnen – die Shell hat den Befehl noch im Cache." [un_path_note]="PATH-Zeile in %s bleibt (andere Werkzeuge nutzen ~/.local/bin)"
  [un_rc]="Completion-Zeile aus %s entfernt" [un_tool_fail]="%s nicht deinstalliert – von Hand: %s"
)
T_en+=(
  [h_uninstall]="remove nimctl: services, autostart, the command, completion; plus --data (~/.nimctl), --tools (litellm, open-webui, code-server), --claude or --all; --yes = no questions"
  [un_title]="Remove nimctl" [un_plan]="This removes:" [un_base]="stop the services, autostart and the watchdog timer, %s, completion lines in ~/.bashrc/~/.zshrc"
  [un_data]="data: %s (keys, config, logs, chats and uploads, the search engine, IDE data)" [un_tools]="tools: litellm, open-webui, code-server (~/.local/lib), the Continue config nimctl wrote"
  [un_claude]="Claude Code (npm uninstall -g @anthropic-ai/claude-code)" [un_keep]="stays: %s" [un_q_data]="Delete the data in %s (keys, chats, logs)?" [un_q_tools]="Uninstall the tools (litellm, open-webui, code-server, Continue config)?"
  [un_q_claude]="Uninstall Claude Code (npm)?" [un_confirm]="Really remove?" [un_noninteractive]="no terminal – nimctl uninstall --yes [--all|--data|--tools|--claude|--keep-data]"
  [un_aborted]="nothing changed" [un_removed]="removed: %s" [un_done]="nimctl is removed. Open a new terminal – the shell still has the command cached." [un_path_note]="the PATH line in %s stays (other tools use ~/.local/bin)"
  [un_rc]="completion line removed from %s" [un_tool_fail]="%s not uninstalled – by hand: %s"
)
tildify() { printf '%s' "${1/#"$HOME"/\~}"; }   # $HOME/x → ~/x for messages (the tilde must be escaped: a bare ~ in the replacement expands)
un_group() { # un_group <flag value> <question> → 0 = remove: the flag decides, --yes/no terminal keeps, else the person is asked (default no)
  case "$1" in 1) return 0;; 0) return 1;; esac; (( YES )) && return 1; (( INTERACTIVE )) || return 1; ask "$2" n; }
un_rc_lines() { # drop the completion lines the installer added; the PATH line stays
  local rc tmp; for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do [[ -f "$rc" ]] || continue
    grep -qF 'nimctl completion' "$rc" || continue
    tmp="$rc.nimctl.tmp"; grep -vF 'nimctl completion' "$rc" >"$tmp" && cat "$tmp" >"$rc" && rm -f "$tmp" && info "$(tf un_rc "$(tildify "$rc")")"; done; return 0
}
un_tools() { # the programs the wizard installs; failures are reported with the command to run by hand
  local removed=()
  if has uv; then local tl; for tl in litellm open-webui; do uv tool uninstall "$tl" >/dev/null 2>&1 && removed+=("$tl") || { uv tool list 2>/dev/null | grep -q "^$tl " && warn "$(tf un_tool_fail "$tl" "uv tool uninstall $tl")"; }; done; fi
  if ls -d "$HOME/.local/lib"/code-server-* >/dev/null 2>&1 || [[ -e "$HOME/.local/bin/code-server" ]]; then rm -rf "$HOME/.local/lib"/code-server-* "$HOME/.local/bin/code-server"; removed+=(code-server); fi
  local cfg; cfg="$(ide_continue_dir 2>/dev/null || printf '%s/.continue' "$HOME")/config.yaml"
  if [[ -f "$cfg" ]] && head -n1 "$cfg" | grep -qF "${IDE_MARK:-# generated by nimctl}"; then rm -f "$cfg"; removed+=("$(tildify "$cfg")"); fi
  ((${#removed[@]})) && ok "$(tf un_removed "${removed[*]}")"; return 0
}
un_claude() { has npm || return 0; if npm uninstall -g @anthropic-ai/claude-code >/dev/null 2>&1; then ok "$(tf un_removed claude)"; else warn "$(tf un_tool_fail claude "npm uninstall -g @anthropic-ai/claude-code")"; fi; return 0; }
cmd_uninstall() { # cmd_uninstall [--all] [--data|--keep-data] [--tools] [--claude] [--yes]
  local data="" tools="" claude="" a link="$HOME/.local/bin/nimctl"
  for a in "$@"; do case "$a" in --all) data=1; tools=1; claude=1;; --data) data=1;; --keep-data) data=0;; --tools) tools=1;; --claude) claude=1;; --yes|-y) YES=1;; *) bad "$(t invalid): $a"; return 64;; esac; done
  sect "$(t un_title)"
  if (( ! INTERACTIVE )) && (( ! YES )); then bad "$(t un_noninteractive)"; return 64; fi
  un_group "$data" "$(tf un_q_data "$NIM_DIR")" && data=1 || data=0
  un_group "$tools" "$(t un_q_tools)" && tools=1 || tools=0
  if has claude; then un_group "$claude" "$(t un_q_claude)" && claude=1 || claude=0; else claude=0; fi
  printf '\n'; info "$(t un_plan)"; out "    • $(tf un_base "$link")"
  (( data )) && out "    • $(tf un_data "$NIM_DIR")" || out "    • $(tf un_keep "$NIM_DIR")"
  (( tools )) && out "    • $(t un_tools)"; (( claude )) && out "    • $(t un_claude)"; printf '\n'
  ask "$(t un_confirm)" n || { info "$(t un_aborted)"; return 1; }
  stop_all >/dev/null 2>&1 || true
  declare -F uninst_systemd >/dev/null && uninst_systemd >/dev/null 2>&1
  (( tools )) && un_tools; (( claude )) && un_claude
  un_rc_lines; local rc; for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do [[ -f "$rc" ]] && grep -qF '.local/bin' "$rc" && { info "$(tf un_path_note "$(tildify "$rc")")"; break; }; done
  if (( data )); then rm -rf "$NIM_DIR"; ok "$(tf un_removed "$NIM_DIR")"; fi
  rm -f "$link" "$link.bak"; ok "$(tf un_removed "$link")"
  ok "$(t un_done)"
}
