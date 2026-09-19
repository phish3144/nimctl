# ── Setup wizard ──────────────────────────────────────────────────────────────
T_de+=(
  [wz_welcome]="Willkommen! Dieser Assistent richtet alles ein: Key, Werkzeuge, Modelle, Dienste." [wz_step]="Schritt %d/%d · %s"
  [wz_headless]="Ohne Terminal: NIMCTL_API_KEY=nvapi-… nimctl setup --yes"
  [wz_key]="API-Key" [wz_key_hint]="Falls du noch keinen hast: %s öffnen, 'Generate API Key', kopieren." [wz_key_in]="Key einfügen (Eingabe unsichtbar, Enter = abbrechen)"
  [wz_key_abort]="Kein Key eingegeben. Später: nimctl setup" [wz_key_env_bad]="Key aus der Umgebung ist ungültig"
  [wz_tools]="Werkzeuge" [wz_tools_ok]="alles vorhanden" [wz_tools_q]="Fehlende jetzt installieren (dauert 2–5 Min.)?"
  [wz_models]="Modelle" [wz_models_hint]="Ich teste alle Kandidaten parallel mit echten Anfragen (max. %ss je Modell) und prüfe, ob das Code-Modell Tool-Calls kann."
  [wz_start]="Dienste" [wz_start_q]="Proxy und Chat jetzt starten?" [wz_done]="Fertig!"
  [wz_watch_q]="Watchdog-Timer einrichten (prüft stündlich die Modelle und ersetzt tote automatisch)?"
  [wz_ide_q]="IDE im Browser einrichten (VS Code + Continue, ~150 MB Download)?" [wz_search_q]="Websuche für den Chat einrichten (SearXNG, ~60 MB)?" [wz_web_q]="Web-Oberfläche einrichten (Dashboard, Einstellungen und Statistik im Browser)?"
  [wz_next]="Ab jetzt:  nimctl        Dashboard\n           nimctl code   Claude Code mit NIM (in einem Projektordner)\n           nimctl chat   Chat im Browser öffnen\n           nimctl help   alle Befehle"
  [wz_chat_hint]="Chat: Das erste Konto, das sich unter http://localhost:%s registriert, wird Admin. Passwort vergessen? nimctl chat passwd"
)
T_en+=(
  [wz_welcome]="Welcome! This wizard sets up everything: key, tools, models, services." [wz_step]="Step %d/%d · %s"
  [wz_headless]="Without a terminal: NIMCTL_API_KEY=nvapi-… nimctl setup --yes"
  [wz_key]="API key" [wz_key_hint]="No key yet? Open %s, 'Generate API Key', copy it." [wz_key_in]="Paste key (input hidden, Enter = cancel)"
  [wz_key_abort]="No key entered. Later: nimctl setup" [wz_key_env_bad]="the key from the environment is invalid"
  [wz_tools]="Tools" [wz_tools_ok]="all present" [wz_tools_q]="Install missing tools now (2–5 min)?"
  [wz_models]="Models" [wz_models_hint]="I probe all candidates in parallel with real requests (max %ss per model) and check that the code model can make tool calls."
  [wz_start]="Services" [wz_start_q]="Start proxy and chat now?" [wz_done]="Done!"
  [wz_watch_q]="Set up the watchdog timer (probes the models hourly and replaces dead ones automatically)?"
  [wz_ide_q]="Set up the browser IDE (VS Code + Continue, ~150 MB download)?" [wz_search_q]="Set up web search for the chat (SearXNG, ~60 MB)?" [wz_web_q]="Set up the web UI (dashboard, settings and statistics in the browser)?"
  [wz_next]="From now on:  nimctl        dashboard\n              nimctl code   Claude Code on NIM (inside a project folder)\n              nimctl chat   open the chat in your browser\n              nimctl help   all commands"
  [wz_chat_hint]="Chat: the first account registered at http://localhost:%s becomes admin. Forgot the password? nimctl chat passwd"
)
wizard() { # wizard [--yes]
  [[ "${1:-}" == --yes ]] && YES=1
  banner "$(t title) $VERSION"; printf "  %s\n" "$(t wz_welcome)"
  (( INTERACTIVE || YES )) || { bad "$(t noninteractive)"; info "$(t wz_headless)"; return 1; }
  sect "$(tf wz_step 1 5 "$(t wz_key)")"
  inst_base || return 1
  if check_key; then ok "$(t key) $(t key_ok) ($(key_masked))"
  else
    [[ -n "$NVIDIA_API_KEY" ]] && bad "$(t wz_key_env_bad): $KEY_STATE"
    info "$(tf wz_key_hint "$KEY_URL")"; (( INTERACTIVE )) && open_url "$KEY_URL"
    (( INTERACTIVE )) || { bad "$(t wz_key_abort)"; info "$(t wz_headless)"; return 1; }
    local tries=0
    while true; do
      prompt "$(t wz_key_in)" hidden || { bad "$(t wz_key_abort)"; return 1; }
      [[ -z "$REPLY" ]] && { bad "$(t wz_key_abort)"; return 1; }
      set_key "$REPLY" && break; ((tries++)); (( tries >= 5 )) && { bad "$(t aborted)"; return 1; }
    done
  fi
  pool_wizard
  sect "$(tf wz_step 2 5 "$(t wz_tools)")"
  local missing=0 x; for x in uv litellm open-webui claude; do has "$x" && ok "$x" || { bad "$x $(t inst_missing)"; missing=1; }; done
  if ((missing)); then ask "$(t wz_tools_q)" y && inst_all; else ok "$(t wz_tools_ok)"; fi
  if declare -F inst_codeserver >/dev/null && [[ "$IDE_ENABLED" != 1 ]]; then ask "$(t wz_ide_q)" y && inst_codeserver; fi
  if declare -F inst_searxng >/dev/null && [[ "$SEARCH_ENABLED" != 1 ]]; then ask "$(t wz_search_q)" y && inst_searxng; fi
  if declare -F web_enable >/dev/null && [[ "$WEB_ENABLED" != 1 ]] && has python3; then ask "$(t wz_web_q)" y && web_enable; fi
  inst_alias
  sect "$(tf wz_step 3 5 "$(t wz_models)")"; info "$(tf wz_models_hint "$PROBE_TIMEOUT")"
  auto_select code fast chat review
  sect "$(tf wz_step 4 5 "$(t wz_start)")"
  if ask "$(t wz_start_q)" y; then start_all; fi
  if has systemctl && [[ -n "${XDG_RUNTIME_DIR:-}" ]] && declare -F inst_watch_timer >/dev/null && ask "$(t wz_watch_q)" y; then inst_watch_timer; fi
  sect "$(tf wz_step 5 5 "$(t wz_done)")"; local n=0 s; for s in "${SLOTS[@]}"; do ((n++)); [[ "$s" == review && -z "$MODEL_REVIEW" ]] && continue; slot_line "$s" "$n"; done
  printf "\n  %b\n" "$(t wz_next)"; info "$(tf wz_chat_hint "$CHAT_PORT")"; [[ "$IDE_ENABLED" == 1 ]] && declare -F ide_url >/dev/null && info "$(tf ide_url "$(ide_url)")"; [[ "$WEB_ENABLED" == 1 ]] && info "$(tf web_url "$WEB_PORT")"; path_hint; printf '\n'
}
