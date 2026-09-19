# ── Scan: every model of every provider with a key ────────────────────────────────────────────────────────────────
# `nimctl scan [provider…] [--sizes] [--use|--clear]` probes the whole catalogs – NVIDIA and the pool – at the pace each
# free tier tolerates (SCAN_RPM, override NIMCTL_SCAN_RPM), then tool calling for the responders and, with --sizes, the
# request sizes of the slots. Results land in ~/.nimctl/probes and sizes like every probe: the dashboard, `find`, the web
# UI catalog and the next `nimctl auto` use them. Models no ranking names but that qualify for a slot are listed; --use
# appends them to the slot's ranking (~/.nimctl/discovered, read by candidates()) and rebuilds the chains, --clear takes
# them out again. OpenRouter is scanned only when named: its free tier allows 50 requests a day.
T_de+=(
  [h_scan]="alle Modelle aller Anbieter mit Key prüfen und passende in die Ranglisten aufnehmen: nimctl scan [anbieter…|all] [--sizes] [--use|--clear]"
  [scan_title]="Scan – alle Modelle" [scan_provider]="%s: %d Modelle im Katalog, %d davon Chat-Modelle" [scan_pace]="%d Anfragen/min in Blöcken von %d – etwa %s"
  [scan_skip_or]="OpenRouter wird nur geprüft, wenn es genannt wird (nimctl scan openrouter): 50 Anfragen am Tag im Free-Tier"
  [scan_nokey]="%s: kein Key – übersprungen" [scan_tools]="Tool-Calling bei %d Modellen …" [scan_sizes]="Anfragegrößen bei %d Modellen …"
  [scan_summary]="Ergebnis" [scan_row]="%-16s %3d von %3d antworten, %3d mit Tool-Calls" [scan_none]="nichts zu prüfen – Key setzen: nimctl key, Anbieter: nimctl pool add"
  [scan_found]="Zusätzlich geeignet für %s (in keiner Rangliste): %s" [scan_nothing]="keine weiteren geeigneten Modelle außerhalb der Ranglisten"
  [scan_use_q]="Diese Modelle ans Ende der Ranglisten hängen und die Ketten neu bauen?" [scan_used]="übernommen – die Ketten werden neu gebaut" [scan_hint_use]="übernehmen: nimctl scan %s --use"
  [scan_cleared]="zusätzliche Modelle aus den Ranglisten entfernt" [scan_busy]="der Scan schickt bis zu %d Anfragen/min an NVIDIA – laufende Sitzungen sind solange langsamer"
  [scan_secs]="%d s" [scan_mins]="%d min"
)
T_en+=(
  [h_scan]="probe every model of every provider with a key and take suitable ones into the rankings: nimctl scan [provider…|all] [--sizes] [--use|--clear]"
  [scan_title]="Scan – all models" [scan_provider]="%s: %d models in the catalog, %d of them chat models" [scan_pace]="%d requests/min in blocks of %d – about %s"
  [scan_skip_or]="OpenRouter is scanned only when named (nimctl scan openrouter): its free tier allows 50 requests a day"
  [scan_nokey]="%s: no key – skipped" [scan_tools]="tool calling on %d models …" [scan_sizes]="request sizes on %d models …"
  [scan_summary]="Result" [scan_row]="%-16s %3d of %3d answer, %3d make tool calls" [scan_none]="nothing to probe – set a key: nimctl key, providers: nimctl pool add"
  [scan_found]="Also suitable for %s (in no ranking): %s" [scan_nothing]="no further suitable models outside the rankings"
  [scan_use_q]="Append these models to the rankings and rebuild the chains?" [scan_used]="taken over – the chains are rebuilt" [scan_hint_use]="take them over: nimctl scan %s --use"
  [scan_cleared]="additional models removed from the rankings" [scan_busy]="the scan sends up to %d requests/min to NVIDIA – running sessions are slower meanwhile"
  [scan_secs]="%d s" [scan_mins]="%d min"
)
# catalog entries that are no chat models (embeddings, rerankers, guards, speech, images, …): not worth a request
RE_NOT_CHAT='embed|rerank|reward|guard|safety|moderation|ocr|parse|whisper|transcri|tts|speech|audio|voxtral|image|imagen|veo|video|detector|diffusion|sdxl|flux|nvclip|deplot|translate|aqa|live-|robotics|nemoretriever|riva|synthetic|calibration'
# a size in the id below 30B: not a candidate for the tool-calling slots (code, review) when discovered by a scan
RE_SMALL='(^|[^0-9a-z.])([0-9]|[12][0-9])(\.[0-9]+)?b([^a-z0-9]|$)'
declare -A SCAN_RPM=([nim]=30 [groq]=25 [gemini]=8 [cerebras]=25 [openrouter]=15 [mistral]=40)   # what a free tier tolerates while a session may be running
scan_rpm() { printf '%s' "${NIMCTL_SCAN_RPM:-${SCAN_RPM[$1]:-20}}"; }
scan_label() { if [[ "$1" == nim ]]; then printf 'NVIDIA'; else printf '%s' "${POOL_LABEL[$1]}"; fi; }
scan_eta() { if (( $1 >= 120 )); then tf scan_mins $(( $1 / 60 )); else tf scan_secs "$1"; fi; }
scan_ids() { # scan_ids <nim|provider> → the chat models of the catalog, namespaced for a provider; OpenRouter: :free only
  local p="$1" ids; if [[ "$p" == nim ]]; then ids=$(models_cached) || return 1; else ids=$(pool_catalog "$p" | sed "s/^/$p:/"); fi
  [[ "$p" == openrouter ]] && ids=$(grep ':free$' <<<"$ids")
  grep -viE -- "$RE_NOT_CHAT" <<<"$ids"; return 0
}
scan_batches() { # scan_batches <probe_many|probe_tools_many> <rpm> <id…> – in blocks the pace allows, ten seconds apart
  local fn="$1" rpm="$2"; shift 2; local per=$(( rpm / 6 )) i=0 n=$#; (( per < 1 )) && per=1
  while (( i < n )); do (( i > 0 )) && sleep 10; (( INTERRUPTED )) && return 1; PROBE_QUIET=1 "$fn" "${@:$(( i + 1 )):$per}"; i=$(( i + per )); done; return 0
}
SCAN_ROWS=()
scan_provider() { # scan_provider <nim|provider> <sizes 0|1> – probes the catalog, tool calling for the responders, sizes when asked; prints the rows
  local p="$1" sizes="$2" ids=() resp=() m all n rpm per ok=0 tools=0; rpm=$(scan_rpm "$p")
  if [[ "$p" != nim ]] && ! pool_configured "$p"; then info "$(tf scan_nokey "$(scan_label "$p")")"; return 0; fi
  if [[ "$p" == nim ]]; then all=$(models_cached | wc -l); else all=$(pool_catalog "$p" | wc -l); fi
  mapfile -t ids < <(scan_ids "$p"); n=${#ids[@]}
  printf "\n  ${B}%s${R}\n" "$(tf scan_provider "$(scan_label "$p")" "$all" "$n")"; (( n )) || return 0
  per=$(( rpm / 6 )); (( per < 1 )) && per=1; info "$(tf scan_pace "$rpm" "$per" "$(scan_eta $(( (n + per - 1) / per * 10 )))")"
  scan_batches probe_many "$rpm" "${ids[@]}" || return 1
  for m in "${ids[@]}"; do probe_get "$m"; [[ "$PROBE_RES" == ok ]] && resp+=("$m"); done; ok=${#resp[@]}
  if (( ok )); then info "$(tf scan_tools "$ok")"; scan_batches probe_tools_many "$rpm" "${resp[@]}" || return 1; fi
  if (( sizes && ok )); then info "$(tf scan_sizes "$ok")"   # tool-capable models at the code size, the others at the chat size, one at a time
    for m in "${resp[@]}"; do (( INTERRUPTED )) && return 1; probe_get "$m"
      if [[ "$PROBE_TOOLS" == ok ]]; then size_ok "$m" "${SLOT_TOKENS[code]}" || true; else size_ok "$m" "${SLOT_TOKENS[chat]}" || true; fi; sleep $(( 60 / rpm + 1 )); done
  fi
  for m in "${ids[@]}"; do probe_get "$m"; [[ "$PROBE_RES" == ok && "$PROBE_TOOLS" == ok ]] && ((tools++)); [[ "$PROBE_RES" == ok ]] && probe_line "$m"; done   # responders first …
  for m in "${ids[@]}"; do probe_get "$m"; [[ "$PROBE_RES" == ok ]] || probe_line "$m"; done                                                      # … then the rest
  SCAN_ROWS+=("$(tf scan_row "$(scan_label "$p")" "$ok" "$n" "$tools")")
}
scan_use() { # scan_use <slot> <id…> – append to the slot's line in ~/.nimctl/discovered
  local slot="$1" cur="" m; shift; [[ -f "$DISCOVERED_FILE" ]] && cur=$(grep -E "^${slot}:" "$DISCOVERED_FILE" | head -n1); cur="${cur#*:}"
  for m in "$@"; do [[ " $cur " == *" $m "* ]] || cur+=" $m"; done
  { [[ -f "$DISCOVERED_FILE" ]] && grep -vE "^${slot}:" "$DISCOVERED_FILE"; printf '%s: %s\n' "$slot" "${cur# }"; } >"$DISCOVERED_FILE.tmp" && mv "$DISCOVERED_FILE.tmp" "$DISCOVERED_FILE"   # "code: id id …" like ~/.nimctl/candidates
}
scan_found() { # scan_found <slot> <nim|provider…> → responders of those providers that qualify for the slot but sit in no ranking, best latency first
  local slot="$1"; shift; local scanned=" $* " listed m res tools p; [[ -s "$PROBES" ]] || return 0
  listed=" $(slot_candidates "$slot" | tr '\n' ' ') "
  while IFS=$'\t' read -r m res _ _ tools; do
    [[ "$res" == ok && "$listed" != *" $m "* ]] || continue; p=$(pool_of "$m"); [[ "$scanned" == *" ${p:-nim} "* ]] || continue
    [[ -z "$p" || -n "$(pool_key "$p")" ]] || continue; [[ "$p" == openrouter && "$m" != *:free ]] && continue
    echo "${m#*:}" | grep -qiE -- "$RE_NOT_CHAT" && continue
    if [[ "$TOOL_SLOTS" == *" $slot "* ]]; then [[ "$tools" == ok ]] || continue; echo "${m#*:}" | grep -qiE -- "$RE_SMALL" && continue; fi
    printf '%s\n' "$m"
  done < <(sort -t$'\t' -k3,3n "$PROBES"); return 0
}
scan_discover() { # scan_discover <use 0|1> <nim|provider…> – list the finds per slot; --use (or the question) appends them to the rankings
  local use="$1"; shift; local slot found=() any=0
  printf '\n'
  for slot in "${SLOTS[@]}"; do mapfile -t found < <(scan_found "$slot" "$@"); ((${#found[@]})) || continue; any=1
    info "$(tf scan_found "$slot" "${found[*]}")"; (( use )) && scan_use "$slot" "${found[@]}"; done
  (( any )) || { info "$(t scan_nothing)"; return 0; }
  if (( ! use )) && (( INTERACTIVE )) && ask "$(t scan_use_q)" n; then use=1
    for slot in "${SLOTS[@]}"; do mapfile -t found < <(scan_found "$slot" "$@"); ((${#found[@]})) && scan_use "$slot" "${found[@]}"; done; fi
  if (( use )); then ok "$(t scan_used)"; auto_all || true; restart_if_running; else info "$(tf scan_hint_use "${*//nim/nvidia}")"; fi
}
cmd_scan() { # cmd_scan [provider…|all|nvidia] [--sizes] [--use] [--clear]
  local sizes=0 use=0 provs=() a p
  for a in "$@"; do case "$a" in
    --sizes) sizes=1;; --use) use=1;;
    --clear) rm -f "$DISCOVERED_FILE"; ok "$(t scan_cleared)"; auto_all || true; restart_if_running; return 0;;
    all) provs=(nim); for p in $(pool_active); do provs+=("$p"); done;;
    nvidia|nim) provs+=(nim);;
    *) pool_valid "$a" || return 64; provs+=("$a");;
  esac; done
  if ((${#provs[@]} == 0)); then provs=(nim); for p in $(pool_active); do [[ "$p" == openrouter ]] && { info "$(t scan_skip_or)"; continue; }; provs+=("$p"); done; fi
  sect "$(t scan_title)"; [[ -n "$NVIDIA_API_KEY" ]] || { bad "$(t scan_none)"; return 1; }
  [[ " ${provs[*]} " == *" nim "* ]] && { models_cached >/dev/null || return 1; info "$(tf scan_busy "$(scan_rpm nim)")"; }
  SCAN_ROWS=(); for p in "${provs[@]}"; do scan_provider "$p" "$sizes" || { info "$(t aborted)"; break; }; done
  printf "\n  ${B}%s${R}\n" "$(t scan_summary)"; for a in "${SCAN_ROWS[@]}"; do out "  $a"; done
  scan_discover "$use" "${provs[@]}"
}
