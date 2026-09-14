# ── CLI: help, dispatch, exit codes ───────────────────────────────────────────
# Exit codes: 0 ok · 1 key missing/invalid · 2 proxy not running · 3 tools/prerequisites · 4 a configured model does not respond
# · 64 usage error (unknown command or argument, sysexits EX_USAGE)
T_de+=(
  [usage]="Nutzung: nimctl [Befehl] [Optionen]   (ohne Befehl: Dashboard, beim ersten Start der Assistent)"
  [usage_flags]="Globale Optionen: --yes (jede Frage mit Ja beantworten) · --lang=de|en · --json (bei status, stats) · NO_COLOR=1"
  [usage_codes]="Exit-Codes: 0 ok · 1 Key fehlt/ungültig · 2 Proxy läuft nicht · 3 Voraussetzung fehlt · 4 ein gewähltes Modell antwortet nicht · 64 falsche Nutzung"
  [usage_more]="Details: nimctl help <Befehl>   ·   Doku: https://github.com/%s"
  [h_setup]="Assistent: Key, Werkzeuge, Modelle, Dienste (--yes für Skripte, Key aus NIMCTL_API_KEY)"
  [h_start]="Proxy (LiteLLM) und Chat (Open WebUI) starten" [h_stop]="beide Dienste stoppen" [h_restart]="beide Dienste neu starten"
  [h_status]="Dashboard einmalig, nicht interaktiv (--json für Skripte)" [h_check]="die gewählten Modelle mit echter Anfrage prüfen (code/review auch Tool-Calls)"
  [h_auto]="Modelle automatisch wählen, optional nur für einzelne Slots: nimctl auto code" [h_pick]="Slot manuell setzen: nimctl pick code [Suchbegriff]"
  [h_find]="alle Katalogeinträge zu <text> prüfen – zeigt, was wirklich antwortet" [h_test]="einen Prompt schicken: nimctl test [Modell|Slot] [Prompt]"
  [h_proxy]="Roundtrip durch den Proxy im Anthropic-Format für alle Slots (das sieht Claude Code)"
  [h_code]="Claude Code über den Proxy starten (--model <Slot|ID>, --think, .nimctl-Profil im Projekt)"
  [h_chat]="Chat starten und im Browser öffnen; Konten: nimctl chat users | passwd [E-Mail] | reset"
  [h_env]="Export-Zeilen für andere Werkzeuge ausgeben: eval \"\$(nimctl env)\"" [h_key]="API-Key prüfen oder setzen: nimctl key [nvapi-…]"
  [h_doctor]="diagnostizieren und reparieren (--fix ohne Rückfrage)" [h_logs]="Log anzeigen: nimctl logs [proxy|chat|watch] [-f]"
  [h_install]="Werkzeuge, PATH, Autostart, Completion" [h_update]="Selbst-Update von GitHub (--check zeigt nur an)" [h_models]="Katalog ausgeben (eine ID je Zeile)"
  [h_version]="Version" [h_help]="diese Hilfe" [h_quit]="Dashboard verlassen (Dienste laufen weiter)"
)
T_en+=(
  [usage]="Usage: nimctl [command] [options]   (no command: dashboard; the wizard on first start)"
  [usage_flags]="Global options: --yes (answer every question with yes) · --lang=de|en · --json (with status, stats) · NO_COLOR=1"
  [usage_codes]="Exit codes: 0 ok · 1 key missing/invalid · 2 proxy not running · 3 prerequisite missing · 4 a selected model does not respond · 64 usage error"
  [usage_more]="Details: nimctl help <command>   ·   Docs: https://github.com/%s"
  [h_setup]="wizard: key, tools, models, services (--yes for scripts, key from NIMCTL_API_KEY)"
  [h_start]="start proxy (LiteLLM) and chat (Open WebUI)" [h_stop]="stop both services" [h_restart]="restart both services"
  [h_status]="dashboard once, non-interactive (--json for scripts)" [h_check]="probe the selected models with a real request (code/review also tool calls)"
  [h_auto]="select models automatically, optionally for single slots: nimctl auto code" [h_pick]="set a slot manually: nimctl pick code [search]"
  [h_find]="probe every catalog entry matching <text> – shows what really answers" [h_test]="send a prompt: nimctl test [model|slot] [prompt]"
  [h_proxy]="Anthropic-format round-trip through the proxy for all slots (what Claude Code sees)"
  [h_code]="launch Claude Code through the proxy (--model <slot|id>, --think, .nimctl profile in the project)"
  [h_chat]="start the chat and open it in the browser; accounts: nimctl chat users | passwd [email] | reset"
  [h_env]="print export lines for other tools: eval \"\$(nimctl env)\"" [h_key]="check or set the API key: nimctl key [nvapi-…]"
  [h_doctor]="diagnose and repair (--fix without asking)" [h_logs]="show a log: nimctl logs [proxy|chat|watch] [-f]"
  [h_install]="tools, PATH, autostart, completion" [h_update]="self-update from GitHub (--check only reports)" [h_models]="print the catalog (one id per line)"
  [h_version]="version" [h_help]="this help" [h_quit]="leave the dashboard (services keep running)"
)
COMMANDS=(setup start stop restart status check auto pick find test proxy code chat env key doctor logs install update models version help)
usage() {
  local c w=10 extra=()
  printf '%s\n\n' "$(t usage)"
  for c in "${COMMANDS[@]}"; do printf "  %-${w}s %s\n" "$c" "$(t "h_$c")"; done
  for c in $(declare -F | awk '{print $3}' | grep '^cmd_' | sed 's/^cmd_//' | sort); do [[ " ${COMMANDS[*]} " == *" $c "* ]] || printf "  %-${w}s %s\n" "$c" "$(t "h_$c")"; done
  printf '\n%s\n%s\n%s\n' "$(t usage_flags)" "$(t usage_codes)" "$(tf usage_more "$NIMCTL_REPO")"
}
help_cmd() { local c="${1:-}"; [[ -z "$c" ]] && { usage; return 0; }; local h; h=$(t "h_$c"); [[ "$h" == "h_$c" ]] && { bad "$(t unknown): $c"; usage; return 64; }; printf '  nimctl %s\n  %s\n' "$c" "$h"; }
status_code() { # bit flags for scripts
  local rc=0 s m; [[ "$KEY_STATE" == ok ]] || rc=$((rc | 1)); svc_running proxy || rc=$((rc | 2))
  for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); [[ -n "$m" ]] || continue; probe_get "$m"; [[ "$PROBE_RES" == ok || -z "$PROBE_RES" ]] || rc=$((rc | 4)); done; return $rc
}
status_json() {
  local sj="{}" s m by_p by_c up_p=false up_c=false pid_p="" pid_c=""
  svc_state proxy && { [[ "$SVC_BY" != foreign ]] && up_p=true; }; by_p="${SVC_BY:-}"; pid_p="${SVC_PID:-}"
  svc_state chat && { [[ "$SVC_BY" != foreign ]] && up_c=true; }; by_c="${SVC_BY:-}"; pid_c="${SVC_PID:-}"
  for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); probe_get "$m"
    sj=$(jq -n --argjson acc "$sj" --arg s "$s" --arg m "$m" --arg res "$PROBE_RES" --arg ms "$PROBE_MS" --arg t "$PROBE_T" --arg tools "$PROBE_TOOLS" \
      '$acc + {($s): {model: (if $m=="" then null else $m end), state: (if $res=="" then "unprobed" elif $res=="ok" then "ok" else "error" end), error: (if $res=="ok" or $res=="" then null else $res end), ms: ($ms|tonumber? // null), probed: ($t|tonumber? // null), tools: (if $tools=="" then null else $tools end)}}')
  done
  local tj="{}" x; for x in litellm open-webui claude uv jq curl; do has "$x" && tj=$(jq -n --argjson a "$tj" --arg x "$x" '$a + {($x): true}') || tj=$(jq -n --argjson a "$tj" --arg x "$x" '$a + {($x): false}'); done
  jq -n --arg v "$VERSION" --arg ks "$KEY_STATE" --arg kt "$KEY_TIME" --arg kd "$(key_days_left)" --argjson up_p "$up_p" --arg by_p "$by_p" --arg pid_p "$pid_p" --arg pp "$PROXY_PORT" \
    --argjson up_c "$up_c" --arg by_c "$by_c" --arg pid_c "$pid_c" --arg cp "$CHAT_PORT" --argjson slots "$sj" --argjson tools "$tj" --arg mk "$MASTER_KEY" \
    '{version:$v, key:{state:$ks, checked:($kt|tonumber? // null), expires_in_days:($kd|tonumber? // null)},
      proxy:{up:$up_p, by:(if $by_p=="" then null else $by_p end), pid:($pid_p|tonumber? // null), port:($pp|tonumber), url:("http://127.0.0.1:"+$pp)},
      chat:{up:$up_c, by:(if $by_c=="" then null else $by_c end), pid:($pid_c|tonumber? // null), port:($cp|tonumber), url:("http://localhost:"+$cp)},
      slots:$slots, tools:$tools}'
}
status_once() { NO_CLEAR=1 LAST_OUT="" render_dashboard; printf '\n'; status_code; }
JSON=0   # set by the global --json flag; commands and modules read it instead of parsing their own argv
main() {
  local args=() rc=0
  while (( $# )); do
    case "$1" in --yes|-y) YES=1;; --json) JSON=1;; --lang=*) L="${1#*=}"; [[ "$L" == de ]] || L=en;; --lang) shift; L="${1:-}"; [[ "$L" == de ]] || L=en;;
      --no-color) :;; *) args+=("$1");; esac
    (( $# )) && shift
  done
  set -- ${args[@]+"${args[@]}"}
  local cmd="${1:-}"; (( $# )) && shift
  case "$cmd" in version|-v|--version) echo "nimctl $VERSION"; exit 0;; help|-h|--help) help_cmd "${1:-}"; exit $?;; esac
  load_conf
  if ! has curl || ! has jq; then case "$cmd" in setup|install) ;; *) bad "$(tf tools_missing_ro "jq/curl" "$(pkg_hint jq curl)")"; exit 3;; esac; fi
  case "$cmd" in
    "")       if configured; then main_loop; else wizard "$@"; fi;;
    setup)    wizard "$@";;
    status)   key_fresh || check_key >/dev/null; if (( JSON )); then status_json; status_code; else status_once; fi;;
    start)    start_all;; stop) stop_all;; restart) restart_all;;
    check)    act_probe;;
    auto)     if (( $# )); then auto_select "$@"; else auto_all; fi; rc=$?; restart_if_running; exit $rc;;
    pick)     [[ -n "${1:-}" && " ${SLOTS[*]} " == *" $1 "* ]] || { bad "$(t invalid): ${1:-}"; exit 64; }; act_pick "$1" "${2:-}";;
    find)     act_find "${1:-}";;
    models)   models_cached;;
    test)     act_test "${1:-}" "${2:-}";;
    code)     act_code "$@";;
    chat)     case "${1:-}" in ""|open) act_chat_open;; *) if declare -F chat_admin >/dev/null; then chat_admin "$@"; else bad "$(t unknown): $1"; exit 64; fi;; esac;;
    env)      act_env;;
    key)      if [[ -n "${1:-}" ]]; then set_key "$1"; else act_key; fi; rc=$?; (( rc == 0 )) && restart_if_running; (( rc == 3 )) && rc=0; exit $rc;;
    doctor)   doctor "${1:-}";;
    proxy)    svc_running proxy || { bad "$(t proxy_down)"; exit 2; }; act_proxy;;
    logs)     act_logs "$@";;
    install)  case "${1:-}" in all) inst_all; inst_alias;; alias|path) inst_alias;; systemd|autostart) inst_systemd;; "") act_install;; *) declare -F "inst_$1" >/dev/null && "inst_$1" || { bad "$(t invalid): $1"; exit 64; };; esac;;
    update)   self_update "${1:-}";;
    _fg)      fg_service "${1:-}";;
    *)        if declare -F "cmd_$cmd" >/dev/null; then "cmd_$cmd" "$@"; else bad "$(t unknown): $cmd"; printf '\n'; usage; exit 64; fi;;
  esac
}
