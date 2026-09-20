# ── Autopilot: the nightly run that keeps everything current without anyone at the keyboard ─────────────────
# `nimctl autopilot` updates nimctl (NIMCTL_AUTOPILOT_UPDATE=0 skips that), fetches fresh catalogs, scans every provider
# with a key at its pace (OpenRouter once a week – its free tier allows 50 requests a day), takes the finds into the
# rankings, rebuilds the chains, restarts the proxy when they changed and aligns the chat. `nimctl watch` (the hourly
# timer) starts it once a day in the hour NIMCTL_AUTOPILOT_HOUR (local time, default 3) or the two hours after it;
# NIMCTL_AUTOPILOT=0 leaves it to `nimctl autopilot` by hand. Report: $NIM_DIR/autopilot.json and logs/autopilot.log;
# the dashboard and the web UI show the last run. The per-request side lives in the proxy: nim-auto (src/25-throttle.sh).
T_de+=(
  [ap_title]="Autopilot" [h_autopilot]="nächtlicher Lauf jetzt: nimctl aktualisieren, alle Anbieter scannen, Funde übernehmen, Ketten neu bauen (--quiet)"
  [ap_off]="aus (NIMCTL_AUTOPILOT=0), nur von Hand" [ap_updated]="nimctl aktualisiert auf %s – der Lauf geht mit der neuen Version weiter"
  [ap_or_skip]="OpenRouter übersprungen (zuletzt vor %s Tagen gescannt, wöchentlich)" [ap_taken]="übernommen für %s: %s" [ap_nothing]="keine neuen Modelle außerhalb der Ranglisten"
  [ap_changed]="Ketten neu gebaut: %s" [ap_same]="Ketten unverändert" [ap_done]="Autopilot fertig in %s s"
  [ap_line]="Autopilot %s · %s" [ap_never]="noch nie gelaufen (nimctl autopilot)" [ap_next]="nächster Lauf gegen %s Uhr" [ap_sum_taken]="%s Modelle übernommen" [ap_sum_none]="nichts Neues" [ap_sum_errors]="Fehler: %s"
  [auto_line]="Auto     %s Anfragen verteilt: %s" [ide_auto]="nimctl wählt je Anfrage" [wz_autopilot]="Autopilot: jede Nacht gegen %s Uhr – nimctl aktualisieren, alle Anbieter scannen, Ketten neu bauen. Sofort: nimctl autopilot" [watch_launchd_on]="Watchdog aktiv (launchd: ~/Library/LaunchAgents/nimctl.watch.plist, stündlich)"
)
T_en+=(
  [ap_title]="Autopilot" [h_autopilot]="the nightly run, now: update nimctl, scan every provider, take the finds over, rebuild the chains (--quiet)"
  [ap_off]="off (NIMCTL_AUTOPILOT=0), by hand only" [ap_updated]="nimctl updated to %s – the run continues with the new version"
  [ap_or_skip]="OpenRouter skipped (scanned %s days ago, weekly)" [ap_taken]="taken over for %s: %s" [ap_nothing]="no new models outside the rankings"
  [ap_changed]="chains rebuilt: %s" [ap_same]="chains unchanged" [ap_done]="autopilot done in %s s"
  [ap_line]="Autopilot %s · %s" [ap_never]="never run yet (nimctl autopilot)" [ap_next]="next run around %s:00" [ap_sum_taken]="%s models taken over" [ap_sum_none]="nothing new" [ap_sum_errors]="errors: %s"
  [auto_line]="Auto     %s requests distributed: %s" [ide_auto]="nimctl picks per request" [wz_autopilot]="Autopilot: every night around %s:00 – update nimctl, scan every provider, rebuild the chains. Right now: nimctl autopilot" [watch_launchd_on]="watchdog active (launchd: ~/Library/LaunchAgents/nimctl.watch.plist, hourly)"
)
AUTOPILOT_FILE="$NIM_DIR/autopilot.json"
ap_log() { mkdir -p "$LOG_DIR"; printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M')" "$1" >>"$LOG_DIR/autopilot.log"; }
ap_read() { [[ -s "$AUTOPILOT_FILE" ]] && jq -r "$1" "$AUTOPILOT_FILE" 2>/dev/null; return 0; }
ap_hour() { local h="${NIMCTL_AUTOPILOT_HOUR:-3}"; [[ "$h" =~ ^[0-9]+$ ]] && h=$((10#$h)) && (( h < 24 )) || h=3; echo "$h"; }
autopilot_due() { # 0 when the nightly run should start now: switched on, inside its hours, more than 20 h since the last run
  [[ "${NIMCTL_AUTOPILOT:-1}" != 0 ]] || return 1
  local hour last h; hour=$(ap_hour); h=$((10#$(date +%H)))
  (( h >= hour && h < hour + 3 )) || return 1
  last=$(ap_read '.at // 0'); [[ "$last" =~ ^[0-9]+$ ]] || last=0
  (( $(date +%s) - last > 20 * 3600 ))
}
cmd_autopilot() { # cmd_autopilot [--quiet] [--after-update <previous version>]
  local quiet=0 from="" t0 self; t0=$(date +%s); self=$(realpath_ "$0")
  while (($#)); do case "$1" in --quiet) quiet=1;; --after-update) from="${2:-}"; shift;; esac; shift; done
  # 1. nimctl itself – a new version takes over the rest of the run
  if [[ -z "$from" && "${NIMCTL_AUTOPILOT_UPDATE:-1}" != 0 ]]; then
    local after yes_was="$YES"; YES=1; self_update >"$TMP_ROOT/ap.update" 2>&1 || true; YES="$yes_was"
    after=$(grep -m1 '^VERSION=' "$self" 2>/dev/null | cut -d'"' -f2)
    if [[ -n "$after" && "$after" != "$VERSION" ]]; then ap_log "$(tf ap_updated "$after")"; (( quiet )) || info "$(tf ap_updated "$after")"
      if (( quiet )); then exec "$self" autopilot --quiet --after-update "$VERSION"; else exec "$self" autopilot --after-update "$VERSION"; fi; fi
  fi
  local cap="$TMP_ROOT/ap.cap" errors=() provs=() p or_at changed=0 taken="{}" before after n_taken=0 slot found rep=() ob=() new i=0
  or_at=$(ap_read '.openrouter_at // 0'); [[ "$or_at" =~ ^[0-9]+$ ]] || or_at=0
  {
    sect "$(t ap_title)"; [[ -n "$from" ]] && ok "$(tf update_ok "$from" "$VERSION")"
    check_key; [[ "$KEY_STATE" == ok ]] || { bad "$(tf watch_keybad "$KEY_STATE")"; errors+=(key); }
    if [[ "$KEY_STATE" == ok ]]; then
      # 2. fresh catalogs, then every provider with a key at its pace (OpenRouter weekly)
      rm -f "$MODEL_CACHE"; for p in $(pool_active); do rm -f "$NIM_DIR/models.$p.cache"; done
      provs=(nim)
      for p in $(pool_active); do
        if [[ "$p" == openrouter ]] && (( t0 - or_at < 6 * 86400 )); then info "$(tf ap_or_skip "$(( (t0 - or_at) / 86400 ))")"; continue; fi
        provs+=("$p"); done
      SCAN_ROWS=(); for p in "${provs[@]}"; do scan_provider "$p" 0 || errors+=("scan:$p"); [[ "$p" == openrouter ]] && or_at=$t0; done
      printf "\n  ${B}%s${R}\n" "$(t scan_summary)"; for p in "${SCAN_ROWS[@]}"; do out "  $p"; done
      # 3. finds outside the rankings join them (like `scan --use`)
      for slot in "${SLOTS[@]}"; do mapfile -t found < <(scan_found "$slot" "${provs[@]}"); ((${#found[@]})) || continue
        scan_use "$slot" "${found[@]}"; n_taken=$((n_taken + ${#found[@]})); info "$(tf ap_taken "$slot" "${found[*]}")"
        taken=$(jq -n --argjson a "$taken" --arg s "$slot" --arg v "${found[*]}" '$a + {($s): ($v | split(" "))}'); done
      (( n_taken )) || info "$(t ap_nothing)"
      # 4. chains from the fresh probes; the proxy and the chat follow when they changed
      before="$CHAIN_CODE|$CHAIN_FAST|$CHAIN_CHAT|$CHAIN_REVIEW"; for slot in "${SLOTS[@]}"; do ob+=("$(slot_model "$slot")"); done
      auto_all || errors+=(auto)
      after="$CHAIN_CODE|$CHAIN_FAST|$CHAIN_CHAT|$CHAIN_REVIEW"
      for slot in "${SLOTS[@]}"; do new=$(slot_model "$slot"); [[ "$new" != "${ob[i]}" ]] && rep+=("$slot ${ob[i]:-–} → ${new:-–}"); ((i++)); done
      if [[ "$before" != "$after" ]]; then changed=1; info "$(tf ap_changed "${rep[*]:-$(t ap_same)}")"; svc_running proxy && { restart_svc proxy || errors+=(proxy); }; else ok "$(t ap_same)"; fi
      svc_running chat && chat_sync_db >/dev/null 2>&1
    fi
    ok "$(tf ap_done "$(( $(date +%s) - t0 ))")"
  } >"$cap" 2>&1
  (( quiet )) || cat "$cap"
  local summary; if ((${#errors[@]})); then summary=$(tf ap_sum_errors "${errors[*]}"); elif (( n_taken )); then summary=$(tf ap_sum_taken "$n_taken"); else summary=$(t ap_sum_none); fi
  (( changed )) && summary+=" · $(tf ap_changed "${rep[*]:-$(t ap_same)}")"
  jq -n --argjson at "$t0" --argjson seconds "$(( $(date +%s) - t0 ))" --arg version "$VERSION" --arg from "$from" --arg provs "${provs[*]}" --argjson taken "$taken" \
    --argjson changed "$changed" --arg rep "$(printf '%s\n' "${rep[@]}")" --arg errors "${errors[*]}" --argjson or_at "$or_at" --arg summary "$summary" \
    '{at: $at, seconds: $seconds, version: $version, updated_from: (if $from == "" then null else $from end), providers: ($provs | split(" ") | map(select(. != ""))),
      taken: $taken, chains_changed: ($changed == 1), replaced: ($rep | split("\n") | map(select(. != ""))), errors: ($errors | split(" ") | map(select(. != ""))),
      openrouter_at: $or_at, summary: $summary}' >"$AUTOPILOT_FILE.tmp" && mv "$AUTOPILOT_FILE.tmp" "$AUTOPILOT_FILE"
  ap_log "$summary"; watch_notify "$(t ap_title): $summary"
  if (( quiet )); then if ((${#errors[@]})); then bad "$summary"; else ok "$summary"; fi; fi
  ((${#errors[@]} == 0))
}
autopilot_line() { # one dashboard line: the last run and when the next one is due
  local at summary next; at=$(ap_read '.at // 0'); summary=$(ap_read '.summary // ""')
  if [[ "${NIMCTL_AUTOPILOT:-1}" == 0 ]]; then next=$(t ap_off); else next=$(tf ap_next "$(ap_hour)"); fi
  if [[ ! "$at" =~ ^[0-9]+$ ]] || (( at == 0 )); then tf ap_line "$(t ap_never)" "$next"; return 0; fi
  tf ap_line "$(fmt_time "$at" '+%d.%m. %H:%M') · $summary" "$next"
}
auto_line() { # one dashboard line from health.json: how nim-auto distributed the requests since the proxy started (fresh only)
  local f="$NIM_DIR/health.json" updated total parts; [[ -s "$f" ]] || return 1
  updated=$(jq -r '.updated // 0' "$f" 2>/dev/null); [[ "$updated" =~ ^[0-9]+$ ]] && (( $(date +%s) - updated < 120 )) || return 1
  total=$(jq -r '[(.auto // {})[]] | add // 0' "$f" 2>/dev/null); [[ "$total" =~ ^[0-9]+$ ]] && (( total > 0 )) || return 1
  parts=$(jq -r '(.auto // {}) | to_entries | sort_by(-.value) | map("\(.key) \(.value)") | join(" · ")' "$f" 2>/dev/null)
  tf auto_line "$total" "$parts"
}
