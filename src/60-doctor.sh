# ── Doctor ────────────────────────────────────────────────────────────────────
T_de+=(
  [doc_title]="Doctor – Diagnose" [doc_fix]="Beheben?" [doc_ok]="Alles in Ordnung" [doc_issues]="%d Problem(e): %s"
  [doc_net]="NVIDIA erreichbar" [doc_net_no]="NVIDIA nicht erreichbar (%s)" [doc_perm]="Dateirechte auf %s: %s (sollte 700 sein)" [doc_perm_ok]="Dateirechte %s 700"
  [doc_awk]="awk fehlt" [doc_bash]="bash %s" [doc_svc_foreign]="Port %s belegt von %s" [doc_fixing]="Behebe …" [doc_remaining]="Verbleibend: %s"
)
T_en+=(
  [doc_title]="Doctor – diagnosis" [doc_fix]="Fix it?" [doc_ok]="All good" [doc_issues]="%d issue(s): %s"
  [doc_net]="NVIDIA reachable" [doc_net_no]="NVIDIA unreachable (%s)" [doc_perm]="permissions on %s: %s (should be 700)" [doc_perm_ok]="permissions %s 700"
  [doc_awk]="awk missing" [doc_bash]="bash %s" [doc_svc_foreign]="port %s taken by %s" [doc_fixing]="Fixing …" [doc_remaining]="remaining: %s"
)
DOC_ISSUES=()
doc_issue() { DOC_ISSUES+=("$1"); }
doctor() { # doctor [--fix] → exit 0 when nothing is wrong
  local fix=0; [[ "${1:-}" == --fix ]] && fix=1
  sect "$(t doc_title)"; DOC_ISSUES=()
  ok "$(tf doc_bash "$BASH_VERSION")"
  local x; for x in curl jq awk; do has "$x" && ok "$x" || { bad "$x $(t inst_missing)"; doc_issue "tool:$x"; }; done
  if curl -s -m 5 -o /dev/null "$API_BASE/models"; then ok "$(t doc_net) ($API_BASE)"; else bad "$(tf doc_net_no "$API_BASE")"; doc_issue net; fi
  if check_key; then ok "$(t key) $(t key_ok) ($(key_masked))"; local w; w=$(key_warning) && warn "$w"; else bad "$(t key): $KEY_STATE"; doc_issue key; fi
  for x in litellm open-webui claude; do has "$x" && ok "$x $(command -v "$x")" || { bad "$x $(t inst_missing)"; doc_issue "tool:$x"; }; done
  local perm; perm=$(stat -c %a "$NIM_DIR" 2>/dev/null || stat -f %Lp "$NIM_DIR" 2>/dev/null || echo 700)
  [[ "$perm" == 700 ]] && ok "$(tf doc_perm_ok "$NIM_DIR")" || { warn "$(tf doc_perm "$NIM_DIR" "$perm")"; doc_issue perm; }
  local s; for s in proxy chat; do
    if svc_state "$s"; then case "$SVC_BY" in foreign) warn "$(tf doc_svc_foreign "$(svc_port "$s")" "${SVC_PID:-?}")"; doc_issue "port:$s";; *) ok "$s :$(svc_port "$s") ($(t "by_$SVC_BY"))";; esac
    else info "$s :$(svc_port "$s") $(t down)"; fi
    unit_failed "$s" && { warn "$(tf unit_failed "nimctl-$s" "nimctl-$s")"; doc_issue "unit:$s"; }
  done
  config_newer_than_proxy && { warn "$(t config_changed)"; doc_issue restart; }
  if [[ "$KEY_STATE" == ok ]] && configured; then
    act_probe >/dev/null 2>&1 || true
    for s in "${SLOTS[@]}"; do local m; m=$(slot_model "$s"); [[ -n "$m" ]] || continue; probe_get "$m"
      if [[ "$PROBE_RES" == ok ]]; then if [[ "$TOOL_SLOTS" == *" $s "* && "$PROBE_TOOLS" != ok ]]; then warn "$s: $(tf auto_notools "$m" "$s")"; doc_issue "model:$s"; else ok "$s: $m (${PROBE_MS} ms)"; fi
      else bad "$s: $m – $PROBE_RES"; doc_issue "model:$s"; fi; done
  elif [[ "$KEY_STATE" == ok ]]; then warn "$(tf slot_unconfigured code)"; doc_issue "model:code"; fi
  if svc_running proxy; then proxy_roundtrip nim-code || doc_issue proxy; proxy_roundtrip nim-code tools || doc_issue proxy; proxy_roundtrip nim-fast || doc_issue proxy; fi
  printf '\n'
  ((${#DOC_ISSUES[@]} == 0)) && { ok "$(t doc_ok)"; return 0; }
  bad "$(tf doc_issues "${#DOC_ISSUES[@]}" "${DOC_ISSUES[*]}")"
  (( fix )) || ask "$(t doc_fix)" n || return 1
  info "$(t doc_fixing)"; local remaining=() i
  for i in "${DOC_ISSUES[@]}"; do case "$i" in
    tool:curl|tool:jq) inst_base || remaining+=("$i");;
    tool:*) "inst_${i#tool:}" 2>/dev/null; has "${i#tool:}" || remaining+=("$i");;
    perm) chmod 700 "$NIM_DIR" && ok "chmod 700 $NIM_DIR" || remaining+=("$i");;
    key) (( INTERACTIVE )) && act_key; [[ "$KEY_STATE" == ok ]] || remaining+=("$i");;
    model:*) auto_select "${i#model:}" || remaining+=("$i");;
    restart) restart_all || remaining+=("$i");;
    unit:*) systemctl --user reset-failed "nimctl-${i#unit:}" 2>/dev/null; systemctl --user restart "nimctl-${i#unit:}" 2>/dev/null || remaining+=("$i");;
    *) remaining+=("$i");;
  esac; done
  [[ " ${DOC_ISSUES[*]} " == *" model:"* ]] && svc_running proxy && ! (( fix )) && restart_if_running
  ((${#remaining[@]} == 0)) && { ok "$(t doc_ok)"; return 0; }
  warn "$(tf doc_remaining "${remaining[*]}")"; return 1
}
