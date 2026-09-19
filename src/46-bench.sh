# ── Bench: compare models by throughput and suitability ───────────────────────
T_de+=(
  [bn_model]="Modell" [bn_ttft]="TTFT ms" [bn_toks]="Tok/s" [bn_tokens]="Tokens" [bn_tools]="Tools"
  [bench_run]="vergleiche %d Modell(e) (sequenziell, 1s Pause) …" [bench_progress]="%d/%d %s …"
  [bench_fastest]="Am schnellsten: %s (%s Tok/s)" [bench_none]="keine Daten" [bench_norun]="keine Modelle zum Vergleichen"
  [h_bench]="Modelle vergleichen: Tokens/s, Zeit bis erstes Token, Tool-Calls (--last zeigt gespeicherte Werte)"
)
T_en+=(
  [bn_model]="Model" [bn_ttft]="TTFT ms" [bn_toks]="tok/s" [bn_tokens]="tokens" [bn_tools]="tools"
  [bench_run]="comparing %d model(s) (sequential, 1s pause) …" [bench_progress]="%d/%d %s …"
  [bench_fastest]="Fastest: %s (%s tok/s)" [bench_none]="no data" [bench_norun]="no models to compare"
  [h_bench]="compare models: tokens/s, time to first token, tool calls (--last shows stored results)"
)

BENCH_FILE="$NIM_DIR/bench"
bench_resolve_ids() { # bench_resolve_ids <model-id|slot…> → resolved, deduped ids, one per line (default: configured slots)
  local seen=" " a id s m
  if (( $# )); then
    for a in "$@"; do
      case "$a" in
        code|fast|chat|review) id=$(slot_model "$a"); [[ -n "$id" ]] || { warn "$(tf slot_unconfigured "$a")" >&2; continue; };;
        *) valid_model "$a" || { bad "$(t invalid): $a" >&2; continue; }; id="$a";;
      esac
      [[ "$seen" == *" $id "* ]] && continue; seen+="$id "; printf '%s\n' "$id"
    done
  else
    for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); [[ -n "$m" ]] || continue
      [[ "$seen" == *" $m "* ]] && continue; seen+="$m "; printf '%s\n' "$m"
    done
  fi
}

BENCH_TTFT=""; BENCH_TOKS=""; BENCH_TOKENS=""; BENCH_ERR=""
bench_stream() { # bench_stream <id> → 0 + BENCH_TTFT/BENCH_TOKS/BENCH_TOKENS, or 1 + BENCH_ERR
  local id="$1" json line first=1 err_body="" ttft_ms="" delta_count=0 completion_tokens=0 last_ms=0 t0 payload delta u
  BENCH_TTFT=""; BENCH_TOKS=""; BENCH_TOKENS=""; BENCH_ERR=""
  json=$(jq -n --arg m "$(plain_id "$id")" '{model:$m, stream:true, stream_options:{include_usage:true}, max_tokens:160,
    messages:[{role:"user", content:"Explain in about 100 words what a reverse proxy does."}]}')
  t0=$(now_ms)
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if (( first )); then
      first=0
      [[ "$line" != data:* ]] && { err_body="$line"; continue; }
    fi
    [[ "$line" == data:* ]] || continue
    payload="${line#data: }"; [[ "$payload" == "[DONE]" ]] && { last_ms=$(( $(now_ms) - t0 )); break; }
    delta=$(printf '%s' "$payload" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
    if [[ -n "$delta" ]]; then ((delta_count++)); [[ -z "$ttft_ms" ]] && ttft_ms=$(( $(now_ms) - t0 )); fi
    u=$(printf '%s' "$payload" | jq -r '.usage.completion_tokens // empty' 2>/dev/null)
    [[ -n "$u" ]] && completion_tokens="$u"
    last_ms=$(( $(now_ms) - t0 ))
  done < <(curl -sN -m 120 -K "$(model_hdr "$id")" "$(model_base "$id")/chat/completions" --data-binary @- <<<"$json" 2>/dev/null)
  if [[ -z "$ttft_ms" ]]; then BENCH_ERR=$(probe_err_text "$err_body" 120); return 1; fi
  (( completion_tokens > 0 )) || completion_tokens=$delta_count
  local denom=$(( last_ms - ttft_ms )) tps="0.0"
  (( denom > 0 && completion_tokens > 0 )) && tps=$(awk -v tk="$completion_tokens" -v d="$denom" 'BEGIN{printf "%.1f", tk/(d/1000)}')
  BENCH_TTFT="$ttft_ms"; BENCH_TOKS="$tps"; BENCH_TOKENS="$completion_tokens"
}
bench_append() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5:-}" "$(date +%s)" >>"$BENCH_FILE"; }
bench_row_width() { local w=$(( COLS - 34 )); (( w > 50 )) && w=50; (( w < 20 )) && w=20; printf '%s' "$w"; }
bench_header() { out "$(printf "  ${B}%-${1}s %8s %8s %8s  %s${R}" "$(t bn_model)" "$(t bn_ttft)" "$(t bn_toks)" "$(t bn_tokens)" "$(t bn_tools)")"; }
bench_tools_glyph() { case "$1" in ok) printf '%s' "$OK";; no) printf '%s' "$NO";; *) printf '%s' "$GR";; esac; }

bench_last() { # bench_last <id…> – most recent stored row per id, straight from $BENCH_FILE, no request
  local w id rec ttft toks tokens tools epoch; w=$(bench_row_width); bench_header "$w"
  for id in "$@"; do
    rec=""; [[ -s "$BENCH_FILE" ]] && rec=$(awk -F'\t' -v id="$id" '$1==id{line=$0} END{print line}' "$BENCH_FILE" 2>/dev/null)
    if [[ -z "$rec" ]]; then out "  $GR $(printf "%-${w}s" "$(trunc "$id" "$w")") ${D}$(t bench_none)${R}"; continue; fi
    IFS=$'\t' read -r _ ttft toks tokens tools epoch <<<"$rec"
    out "$(printf "  %-${w}s %8s %8s %8s  %s  ${D}%s${R}" "$(trunc "$id" "$w")" "$ttft" "$toks" "$tokens" "$(bench_tools_glyph "$tools")" "$(age_of "$epoch")")"
  done
}
cmd_bench() { # cmd_bench [--last] [model-id|slot…] – default: models of all configured slots, deduplicated
  local last=0 args=() a; for a in "$@"; do case "$a" in --last) last=1;; *) args+=("$a");; esac; done
  set -- ${args[@]+"${args[@]}"}
  sect "$(t k_b)"
  local ids=() id; while IFS= read -r id; do [[ -n "$id" ]] && ids+=("$id"); done < <(bench_resolve_ids "$@")
  ((${#ids[@]})) || { bad "$(t bench_norun)"; return 1; }
  if (( last )); then bench_last "${ids[@]}"; return 0; fi
  info "$(tf bench_run "${#ids[@]}")"
  declare -A ROW_OK=() ROW_TTFT=() ROW_TOKS=() ROW_TOKENS=() ROW_TOOLS=() ROW_ERR=()
  local i=0 n=${#ids[@]} tres
  for id in "${ids[@]}"; do
    ((i++)); info "$(tf bench_progress "$i" "$n" "$(trunc "$id" 60)")"
    if bench_stream "$id"; then
      ROW_OK[$id]=1; ROW_TTFT[$id]="$BENCH_TTFT"; ROW_TOKS[$id]="$BENCH_TOKS"; ROW_TOKENS[$id]="$BENCH_TOKENS"
      tres=$(probe_one "$id" "$PROBE_TIMEOUT" tools)
      case "$tres" in
        ok*) ROW_TOOLS[$id]=ok; probe_set "$id" ok "${tres#ok }" ok;;
        notools*) ROW_TOOLS[$id]=no; probe_set "$id" ok "${tres#notools }" no;;
      esac
      with_lock bench_append "$id" "$BENCH_TTFT" "$BENCH_TOKS" "$BENCH_TOKENS" "${ROW_TOOLS[$id]:-}"
    else
      ROW_ERR[$id]="$BENCH_ERR"; bad "$id: $BENCH_ERR"
    fi
    (( i < n )) && sleep 1
  done
  printf '\n'; local w; w=$(bench_row_width); bench_header "$w"
  local best="" best_toks="0"
  for id in "${ids[@]}"; do
    if [[ -n "${ROW_OK[$id]:-}" ]]; then
      out "$(printf "  %-${w}s %8s %8s %8s  %s" "$(trunc "$id" "$w")" "${ROW_TTFT[$id]}" "${ROW_TOKS[$id]}" "${ROW_TOKENS[$id]}" "$(bench_tools_glyph "${ROW_TOOLS[$id]:-}")")"
      awk -v a="${ROW_TOKS[$id]}" -v b="$best_toks" 'BEGIN{exit !(a>b)}' && { best="$id"; best_toks="${ROW_TOKS[$id]}"; }
    else
      out "  $NO $(printf "%-${w}s" "$(trunc "$id" "$w")") ${RED}${ROW_ERR[$id]}${R}"
    fi
  done
  [[ -n "$best" ]] && ok "$(tf bench_fastest "$best" "$best_toks")"
}
dash_register b cmd_bench k_b models
