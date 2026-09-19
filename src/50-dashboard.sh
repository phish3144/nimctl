# ── Dashboard ─────────────────────────────────────────────────────────────────
T_de+=(
  [title]="nimctl · NVIDIA NIM" [key]="Key" [tools]="Werkzeuge" [today]="Heute" [last_action]="Letzte Aktion" [notices]="Hinweise"
  [grp_svc]="Dienste" [grp_models]="Modelle" [grp_use]="Nutzen" [grp_sys]="System"
  [k_s]="Start" [k_x]="Stop" [k_r]="Neustart" [k_a]="Auto" [k_p]="Prüfen" [k_1234]="Slot wählen" [k_f]="Finden" [k_t]="Testen" [k_b]="Bench"
  [k_c]="Claude Code" [k_w]="Chat" [k_e]="Env" [k_g]="Statistik" [k_n]="Konten" [k_k]="Key" [k_d]="Doctor" [k_i]="Install" [k_l]="Logs" [k_u]="Update" [k_q]="Ende" [k_help]="Hilfe"
  [k_watch_timer]="Watchdog-Timer (systemd)"
  [bye]="Dienste laufen weiter. Stoppen: nimctl stop" [any_key]="Taste drücken …" [config_changed]="Konfiguration geändert – r startet den Proxy neu, damit sie wirkt"
  [help_title]="Tasten" [help_foot]="Alles auch als Befehl: nimctl help" [reprobing]="Modell-Status ist älter als %s h – prüfe …"
  [chat_via_proxy]="über Proxy"
)
T_en+=(
  [title]="nimctl · NVIDIA NIM" [key]="Key" [tools]="Tools" [today]="Today" [last_action]="Last action" [notices]="Notices"
  [grp_svc]="Services" [grp_models]="Models" [grp_use]="Use" [grp_sys]="System"
  [k_s]="Start" [k_x]="Stop" [k_r]="Restart" [k_a]="Auto" [k_p]="Probe" [k_1234]="pick slot" [k_f]="Find" [k_t]="Test" [k_b]="Bench"
  [k_c]="Claude Code" [k_w]="Chat" [k_e]="Env" [k_g]="Stats" [k_n]="Accounts" [k_k]="Key" [k_d]="Doctor" [k_i]="Install" [k_l]="Logs" [k_u]="Update" [k_q]="Quit" [k_help]="Help"
  [k_watch_timer]="watchdog timer (systemd)"
  [bye]="Services keep running. Stop: nimctl stop" [any_key]="press a key …" [config_changed]="configuration changed – r restarts the proxy so it takes effect"
  [help_title]="Keys" [help_foot]="Everything is also a command: nimctl help" [reprobing]="model status is older than %s h – probing …"
  [chat_via_proxy]="via proxy"
)
# Module keys registered with dash_register (src/05-core.sh) are shown in the footer and handled in the loop.
PANEL_LINES=8
PAUSE_KEYS=" a f t 1 2 3 4 d l e g n b m ? "

svc_row() { # svc_row <proxy|chat> → "✓ läuft  :4000  nimctl" or "✗ aus"
  local s="$1"
  if svc_state "$s"; then
    case "$SVC_BY" in foreign) printf '%s %-6s :%s  %s%s%s' "$WA" "$(t by_foreign)" "$(svc_port "$s")" "$D" "${SVC_PID:-?}" "$R";;
      *) printf '%s %-6s :%s  %s%s%s' "$OK" "$(t up)" "$(svc_port "$s")" "$D" "$(t "by_$SVC_BY")${SVC_PID:+ · pid $SVC_PID}" "$R";; esac
  else printf '%s %-6s :%s' "$NO" "$(t down)" "$(svc_port "$s")"; fi
}
render_dashboard() {
  term_cols; banner "$(t title) $VERSION"
  key_line >"$TMP_ROOT/keyline"; printf "  %-8s %s %s\n" "$(t key)" "$KEY_FLAG" "$(cat "$TMP_ROOT/keyline")"
  printf "  %-8s %s\n" "$(t proxy)" "$(svc_row proxy)"
  printf "  %-8s %s%s\n" "$(t chat)" "$(svc_row chat)" "$([[ "${NIMCTL_CHAT_VIA_PROXY:-1}" == 1 ]] && printf ' %s(%s)%s' "$D" "$(t chat_via_proxy)" "$R")"
  { [[ "$IDE_ENABLED" == 1 ]] || has code-server; } && printf "  %-8s %s\n" "$(t ide)" "$(svc_row ide)"
  { [[ "$SEARCH_ENABLED" == 1 ]] || [[ -x "$SEARX_DIR/venv/bin/python" ]]; } && printf "  %-8s %s\n" "$(t svc_search)" "$(svc_row search)"
  { [[ "$WEB_ENABLED" == 1 ]] || [[ -f "$WEB_DIR/server.py" ]]; } && printf "  %-8s %s\n" "$(t svc_web)" "$(svc_row web)"
  local tl="" x; for x in litellm open-webui claude uv code-server; do has "$x" && tl+="$OK $x  " || tl+="$NO $x  "; done
  printf "  %-8s %s\n" "$(t tools)" "$tl"
  printf "  %-8s %s\n" "$(t k_m)" "$(pool_line)"
  declare -F stats_summary >/dev/null && { local st; st=$(stats_summary 2>/dev/null); [[ -n "$st" ]] && printf "  %-8s %s\n" "$(t today)" "$st"; }
  declare -F throttle_line >/dev/null && { local tl2; tl2=$(throttle_line 2>/dev/null) && printf "  %s\n" "$tl2"; }
  declare -F cooldown_line >/dev/null && { local cl; cl=$(cooldown_line 2>/dev/null) && printf "  %s\n" "$cl"; }
  sect "$(t models)"
  local n=0 s; for s in "${SLOTS[@]}"; do ((n++)); [[ "$s" == review && -z "$MODEL_REVIEW" ]] && { (( COLS >= 100 )) || continue; }; slot_line "$s" "$n"; done
  (( COLS >= 100 )) && info "$(t slots_hint)"
  # notices
  local notes=() w
  config_newer_than_proxy && notes+=("$(t config_changed)")
  w=$(key_warning) && notes+=("$w")
  unit_failed proxy && notes+=("$(tf unit_failed nimctl-proxy nimctl-proxy)"); unit_failed chat && notes+=("$(tf unit_failed nimctl-chat nimctl-chat)")
  ((${#notes[@]})) && { printf '\n'; for w in "${notes[@]}"; do printf "  %s %s\n" "$WA" "$w"; done; }
  # last action panel
  if [[ -n "$LAST_OUT" && -s "$LAST_OUT" ]]; then
    local la; la=$(t last_action); printf "\n%s%s %s %s%s\n" "$D" "$G_SOFT$G_SOFT" "$la" "$(printf '%*s' $(( COLS - ${#la} - 4 )) '' | tr ' ' "$G_SOFT")" "$R"
    tail -n "$PANEL_LINES" "$LAST_OUT"
  fi
  printf '\n'; rule
  dash_footer; printf "  ${B}›${R} "
}
dash_footer() {
  local k; declare -A extra=([svc]="" [models]="" [use]="" [sys]="")
  for k in $(printf '%s\n' "${!DASH_FN[@]}" | sort); do extra[${DASH_GROUP[$k]}]+="  ${B}$k${R} $(t "${DASH_LABEL[$k]}")"; done
  printf "  ${D}%-8s${R} ${B}s${R} %s  ${B}x${R} %s  ${B}r${R} %s%b\n" "$(t grp_svc)" "$(t k_s)" "$(t k_x)" "$(t k_r)" "${extra[svc]}"
  printf "  ${D}%-8s${R} ${B}a${R} %s  ${B}p${R} %s  ${B}1-4${R} %s  ${B}f${R} %s  ${B}t${R} %s%b\n" "$(t grp_models)" "$(t k_a)" "$(t k_p)" "$(t k_1234)" "$(t k_f)" "$(t k_t)" "${extra[models]}"
  printf "  ${D}%-8s${R} ${B}c${R} %s  ${B}w${R} %s  ${B}e${R} %s%b\n" "$(t grp_use)" "$(t k_c)" "$(t k_w)" "$(t k_e)" "${extra[use]}"
  printf "  ${D}%-8s${R} ${B}k${R} %s  ${B}d${R} %s  ${B}i${R} %s  ${B}l${R} %s  ${B}u${R} %s  ${B}?${R} %s  ${B}q${R} %s%b\n" "$(t grp_sys)" "$(t k_k)" "$(t k_d)" "$(t k_i)" "$(t k_l)" "$(t k_u)" "$(t k_help)" "$(t k_q)" "${extra[sys]}"
}
dash_help() {
  sect "$(t help_title)"
  local rows=(s:k_s:h_start x:k_x:h_stop r:k_r:h_restart a:k_a:h_auto p:k_p:h_check "1-4:k_1234:h_pick" f:k_f:h_find t:k_t:h_test c:k_c:h_code w:k_w:h_chat e:k_e:h_env k:k_k:h_key d:k_d:h_doctor i:k_i:h_install l:k_l:h_logs u:k_u:h_update "?:k_help:h_help" q:k_q:h_quit)
  local r k; for r in "${rows[@]}"; do IFS=: read -r k _ h <<<"$r"; printf "  ${B}%-4s${R} %s\n" "$k" "$(t "$h")"; done
  for k in $(printf '%s\n' "${!DASH_FN[@]}" | sort); do printf "  ${B}%-4s${R} %s\n" "$k" "$(t "h_${DASH_FN[$k]#cmd_}")"; done
  info "$(t help_foot)"
}
dash_reprobe_if_stale() {
  [[ "$KEY_STATE" == ok ]] || return 0; local s m stale=0
  for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); [[ -n "$m" ]] || continue; (( $(probe_age "$m") > REPROBE_HOURS * 3600 )) && stale=1; done
  (( stale )) || return 0; info "$(tf reprobing "$REPROBE_HOURS")"; act_probe >/dev/null 2>&1 || true
}
dash_read_key() { # single key on a terminal, a whole line when input is piped (tests, expect)
  if [[ -t 0 ]]; then read -rsn1 KEY || return 1; [[ "$KEY" == $'\e' ]] && { read -rsn2 -t 0.05 _ || true; KEY=""; }
  else read -r KEY || return 1; KEY="${KEY:0:1}"; fi
}
dash_pause() { (( INTERACTIVE )) || return 0; printf "\n  ${D}%s${R}" "$(t any_key)"; if [[ -t 0 ]]; then read -rsn1 _ || true; else read -r _ || true; fi; printf '\n'; }
main_loop() {
  trap on_int INT; INT_TRAP=on_int
  LAST_OUT="$TMP_ROOT/last"; : >"$LAST_OUT"
  key_fresh || check_key >/dev/null
  dash_reprobe_if_stale
  local KEY rc
  while true; do
    INTERRUPTED=0; render_dashboard; dash_read_key || { printf '\n'; exit 0; }
    [[ -z "$KEY" ]] && continue
    printf '%s\n' "$KEY"; : >"$LAST_OUT"; rc=0
    case "$KEY" in
      s) start_all;; x) stop_all;; r) restart_all;;
      a) auto_all; restart_if_running;; p) act_probe;;
      1) act_pick code;; 2) act_pick fast;; 3) act_pick chat;; 4) act_pick review;;
      f) act_find;; t) act_test;;
      c) act_code;; w) act_chat_open;; e) act_env;;
      k) act_key; [[ $? == 0 ]] && restart_if_running;; d) doctor;; i) act_install;; l) act_logs;; u) self_update;;
      \?|h) dash_help;;
      q|Q|0) info "$(t bye)"; exit 0;;
      *) if [[ -n "${DASH_FN[$KEY]:-}" ]]; then "${DASH_FN[$KEY]}"; else bad "$(t unknown): $KEY  ${D}(? = $(t k_help))${R}"; fi;;
    esac
    if [[ "$PAUSE_KEYS" == *" $KEY "* ]] || (( $(wc -l <"$LAST_OUT") > PANEL_LINES )); then dash_pause; fi
  done
}
