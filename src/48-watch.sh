# ── Watch: keep the configured slots healthy from a timer/cron ───────────────
T_de+=(
  [watch_title]="nimctl watch" [watch_keybad]="kein gültiger API-Key (%s)" [watch_none]="keine Slots konfiguriert"
  [watch_timer_on]="Watchdog-Timer aktiv (systemd --user: nimctl-watch.timer)"
  [h_watch]="Slots prüfen und tote Modelle automatisch ersetzen (für Timer/Cron; --quiet)"
)
T_en+=(
  [watch_title]="nimctl watch" [watch_keybad]="no valid API key (%s)" [watch_none]="no slots configured"
  [watch_timer_on]="watchdog timer active (systemd --user: nimctl-watch.timer)"
  [h_watch]="probe the slots and replace dead models automatically (for timers/cron; --quiet)"
)
watch_log() { mkdir -p "$LOG_DIR"; printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M')" "$1" >>"$LOG_DIR/watch.log"; }
watch_notify() { has notify-send && notify-send "$(t watch_title)" "$1" >/dev/null 2>&1; return 0; }
watch_bad() { # watch_bad <slot> → 0 (unhealthy) when it does not answer, or (for TOOL_SLOTS) can't call tools
  local m; m=$(slot_model "$1"); [[ -n "$m" ]] || return 0
  probe_get "$m"; [[ "$PROBE_RES" == ok ]] || return 0
  [[ "$TOOL_SLOTS" == *" $1 "* && "$PROBE_TOOLS" != ok ]] && return 0
  return 1
}
cmd_watch() { # cmd_watch [--quiet] – probe every configured slot, auto-replace dead ones, log + notify
  local quiet=0; [[ "${1:-}" == --quiet ]] && quiet=1
  check_key
  if [[ "$KEY_STATE" != ok ]]; then
    local km; km=$(tf watch_keybad "$KEY_STATE"); bad "$km"; watch_log "$km"; watch_notify "$km"; return 1
  fi
  local slots=() s m seen=" " ids=() tool_ids=" "
  for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); [[ -n "$m" ]] || continue; slots+=("$s")
    [[ "$seen" == *" $m "* ]] || { seen+="$m "; ids+=("$m"); }
    [[ "$TOOL_SLOTS" == *" $s "* ]] && tool_ids+="$m "; done
  ((${#slots[@]})) || { watch_log "$(t watch_none)"; return 0; }
  local cap="$TMP_ROOT/watch.cap" unhealthy=() changed=0 dead=() rep=()
  {
    probe_many "${ids[@]}"
    local tids=()
    for m in "${ids[@]}"; do [[ "$tool_ids" == *" $m "* ]] || continue
      probe_get "$m"; [[ "$PROBE_RES" == ok ]] && tids+=("$m"); done
    ((${#tids[@]})) && probe_tools_many "${tids[@]}"
    for s in "${slots[@]}"; do watch_bad "$s" && unhealthy+=("$s"); done
    local old new
    for s in "${unhealthy[@]}"; do
      old=$(slot_model "$s"); auto_select "$s"; new=$(slot_model "$s")
      [[ "$new" != "$old" ]] && { changed=1; rep+=("$s $old $new"); }
      watch_bad "$s" && dead+=("$s")
    done
    (( changed )) && svc_running proxy && restart_svc proxy
  } >"$cap" 2>&1
  if (( quiet )); then grep -F -e "$NO" -e "$WA" "$cap"; else cat "$cap"; fi
  local msg="" parts=() part r o n
  for r in "${rep[@]}"; do read -r part o n <<<"$r"; parts+=("replaced $part: $o → $n"); done
  ((${#dead[@]})) && parts+=("dead ${dead[*]}")
  if ((${#parts[@]} == 0)); then msg="ok ${slots[*]}"; (( quiet )) || ok "$msg"
  else
    for part in "${parts[@]}"; do msg+="${msg:+; }$part"; case "$part" in dead*) bad "$part";; *) warn "$part";; esac; done
  fi
  watch_log "$msg"; [[ "$msg" == ok\ * ]] || watch_notify "$msg"
  ((${#dead[@]})) && return 4
  return 0
}
inst_watch_timer() {
  has systemctl || { bad "$(t no_systemd)"; return 1; }
  local d self; d=$(unit_dir); mkdir -p "$d"; self=$(realpath_ "$0")
  printf '[Unit]\nDescription=nimctl watch\n\n[Service]\nType=oneshot\nExecStart=%s watch --quiet\nEnvironment=NIMCTL_HOME=%s\n' "$self" "$NIM_DIR" >"$d/nimctl-watch.service"
  printf '[Unit]\nDescription=nimctl watch timer\n\n[Timer]\nOnBootSec=5min\nOnUnitActiveSec=1h\nPersistent=true\n\n[Install]\nWantedBy=timers.target\n' >"$d/nimctl-watch.timer"
  systemctl --user daemon-reload && systemctl --user enable --now nimctl-watch.timer && ok "$(t watch_timer_on)" || { bad "$(tf inst_fail systemd)"; return 1; }
}
