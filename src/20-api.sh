# ── API ───────────────────────────────────────────────────────────────────────
T_de+=(
  [probing]="prüfe %d Modell(e) mit echter Anfrage (max. %ss) …" [probing_tools]="prüfe Tool-Calling bei %d Modell(en) …"
  [no_endpoint]="kein Endpoint für diesen Account" [timeout]="Timeout nach %ss" [ratelimit]="Rate-Limit (429)" [noanswer]="keine Antwort"
  [overloaded]="überlastet (Worker-Limit)" [retry]="Zweiter Versuch für %s mit %ss …" [cached]="(bereits geprüft)" [answers]="antwortet"
  [tools_ok]="Tools ✓" [tools_no]="keine Tool-Calls" [catalog_fail]="Katalog nicht abrufbar" [catalog_stale]="Katalog-Abruf fehlgeschlagen – nutze Stand von %s"
  [auto_title]="Automatische Modellwahl" [auto_slot]="Slot %s: %d Kandidaten" [auto_pick]="%s → %s (%s ms)" [auto_none]="kein Kandidat antwortet – Slot %s bleibt: %s"
  [auto_notools]="%s antwortet, kann aber keine Tool-Calls – für Slot %s ungeeignet" [auto_done]="Fertig. Ergebnis:" [auto_progress]="Slot %d/%d"
)
T_en+=(
  [probing]="probing %d model(s) with a real request (max %ss) …" [probing_tools]="probing tool calling on %d model(s) …"
  [no_endpoint]="no endpoint for this account" [timeout]="timeout after %ss" [ratelimit]="rate limit (429)" [noanswer]="no answer"
  [overloaded]="overloaded (worker limit)" [retry]="Second attempt for %s with %ss …" [cached]="(already probed)" [answers]="responds"
  [tools_ok]="tools ✓" [tools_no]="no tool calls" [catalog_fail]="catalog unavailable" [catalog_stale]="catalog refresh failed – using the copy from %s"
  [auto_title]="Automatic model selection" [auto_slot]="Slot %s: %d candidates" [auto_pick]="%s → %s (%s ms)" [auto_none]="no candidate responds – slot %s stays: %s"
  [auto_notools]="%s responds but cannot make tool calls – unsuitable for slot %s" [auto_done]="Done. Result:" [auto_progress]="slot %d/%d"
)

write_hdr() { # the Authorization header lives in a 600 file inside a 700 tmp dir; curl reads it with -K
  printf 'header = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\n' "$NVIDIA_API_KEY" >"$HDR_FILE"; chmod 600 "$HDR_FILE"
}
API_CODE=000
api() { # api <GET|POST> <path|url> [timeout] [json-body] → body on stdout, HTTP code in API_CODE
  local m="$1" url="$2" to="${3:-30}" body="${4:-}" out
  [[ "$url" != http* ]] && url="$API_BASE$url"
  if [[ -n "$body" ]]; then out=$(curl -s -m "$to" -K "$HDR_FILE" -X "$m" "$url" --data-binary @- -w '\n%{http_code}' <<<"$body" 2>/dev/null)
  else out=$(curl -s -m "$to" -K "$HDR_FILE" -X "$m" "$url" -w '\n%{http_code}' 2>/dev/null); fi
  API_CODE="${out##*$'\n'}"; [[ "$API_CODE" =~ ^[0-9]{3}$ ]] || API_CODE=000
  printf '%s' "${out%$'\n'*}"
}
check_key() {
  if [[ -z "$NVIDIA_API_KEY" ]]; then KEY_STATE="none"; KEY_TIME=$(date +%s); save_state; return 1; fi
  api GET /models 10 >/dev/null
  case "$API_CODE" in 200) KEY_STATE="ok";; 401|403) KEY_STATE="invalid";; 000) KEY_STATE="offline";; *) KEY_STATE="http$API_CODE";; esac
  KEY_TIME=$(date +%s); save_state; [[ "$KEY_STATE" == ok ]]
}
key_fresh() { (( $(date +%s) - KEY_TIME < 300 )); }
refresh_models() {
  local json ids; json=$(api GET /models 15); echo "$json" | jq -e '.data' >/dev/null 2>&1 || return 1
  ids=$(echo "$json" | jq -r '.data[].id' | grep -E "$RE_MODEL" | sort -u); [[ -n "$ids" ]] || return 1
  printf '%s\n' "$ids" >"$MODEL_CACHE.tmp" && mv "$MODEL_CACHE.tmp" "$MODEL_CACHE"
}
models_cached() { # prints the catalog; refreshes hourly, falls back to the stale copy when the refresh fails
  if [[ ! -s "$MODEL_CACHE" ]] || (( $(date +%s) - $(mtime "$MODEL_CACHE") > 3600 )); then
    if ! refresh_models; then
      [[ -s "$MODEL_CACHE" ]] || { bad "$(t catalog_fail)"; return 1; }
      warn "$(tf catalog_stale "$(fmt_time "$(mtime "$MODEL_CACHE")" '+%H:%M')")" >&2
    fi
  fi
  cat "$MODEL_CACHE"
}

# ── Probe results: ~/.nimctl/probes, tab-separated: id  result  ms  epoch  tools ────────────────
PROBE_RES=""; PROBE_MS=""; PROBE_T=""; PROBE_TOOLS=""
probe_get() { # probe_get <id> → PROBE_RES (ok|error text|""), PROBE_MS, PROBE_T (epoch), PROBE_TOOLS (ok|no|"")
  local rec; rec=$(awk -F'\t' -v id="$1" '$1==id{l=$2"\x1f"$3"\x1f"$4"\x1f"$5} END{print l}' "$PROBES" 2>/dev/null)
  PROBE_RES="${rec%%$'\x1f'*}"; rec="${rec#*$'\x1f'}"; PROBE_MS="${rec%%$'\x1f'*}"; rec="${rec#*$'\x1f'}"
  PROBE_T="${rec%%$'\x1f'*}"; PROBE_TOOLS="${rec#*$'\x1f'}"; [[ "$PROBE_TOOLS" == "$PROBE_T" ]] && PROBE_TOOLS=""
  [[ "$PROBE_MS" =~ ^[0-9]+$ ]] || PROBE_MS=0
}
_probe_write() { { awk -F'\t' -v id="$1" '$1!=id' "$PROBES"; printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(date +%s)" "$4"; } >"$PROBES.tmp" && mv "$PROBES.tmp" "$PROBES"; }
probe_set() { # probe_set <id> <ok|error> [ms] [tools ok|no] – the tools column survives a plain re-probe
  valid_model "$1" || return 1
  local tools="${4-}"; if [[ -z "${4+x}" ]]; then probe_get "$1"; tools="$PROBE_TOOLS"; fi
  with_lock _probe_write "$1" "$2" "${3:-}" "$tools"
}
probe_age() { probe_get "$1"; [[ "$PROBE_T" =~ ^[0-9]+$ ]] && echo $(( $(date +%s) - PROBE_T )) || echo 999999; }
probe_ok_models() { awk -F'\t' '$2=="ok"{print $1}' "$PROBES" | sort -u; }

probe_err_text() { # probe_err_text <raw body> <timeout> → readable error
  local out="$1" to="$2" err
  err=$(echo "$out" | jq -r '.error.message // .detail // .message // .' 2>/dev/null | tr '\n' ' ' | head -c 140)
  [[ -z "$out" ]] && err="$(tf timeout "$to")"
  case "$err" in *"Not found for account"*|*Function*) err="$(t no_endpoint)";; *429*|*"Too Many"*) err="$(t ratelimit)";;
    *ResourceExhausted*|*"request limit"*|*"limit reached"*) err="$(t overloaded)";; esac
  printf '%s' "${err:-$(t noanswer)}"
}
probe_one() { # probe_one <id> [timeout] [tools] → "ok <ms>" | "notools <ms>" | error text
  local id="$1" to="${2:-$PROBE_TIMEOUT}" mode="${3:-plain}" body out t0
  if [[ "$mode" == tools ]]; then
    body=$(jq -n --arg m "$id" '{model:$m,max_tokens:64,tool_choice:"auto",
      tools:[{type:"function",function:{name:"read_file",description:"Read a file from disk",parameters:{type:"object",properties:{path:{type:"string"}},required:["path"]}}}],
      messages:[{role:"user",content:"Use the read_file tool to read README.md. Call the tool, do not answer in prose."}]}')
  else body=$(jq -n --arg m "$id" '{model:$m,messages:[{role:"user",content:"Hi"}],max_tokens:5}'); fi
  t0=$(now_ms); out=$(api POST /chat/completions "$to" "$body")
  if echo "$out" | jq -e '.choices[0]' >/dev/null 2>&1; then
    if [[ "$mode" == tools ]] && ! echo "$out" | jq -e '.choices[0].message.tool_calls[0].function.name' >/dev/null 2>&1; then echo "notools $(( $(now_ms) - t0 ))"; return; fi
    echo "ok $(( $(now_ms) - t0 ))"; return
  fi
  probe_err_text "$out" "$to"
}
declare -A RUN_OK=() RUN_TOOLS=()  # answers in this process: id → ms / ok|no (never downgraded within a run)
probe_line() { # probe_line <id> → one table row from the stored result
  probe_get "$1"; local tools=""
  case "$PROBE_TOOLS" in ok) tools="${D}$(t tools_ok)${R}";; no) tools="${YEL}$(t tools_no)${R}";; esac
  if [[ "$PROBE_RES" == ok ]]; then out "  $OK $(printf '%-46s' "$(trunc "$1" 46)") $(t answers) ${PROBE_MS} ms  $tools"
  else out "  $NO $(printf '%-46s' "$(trunc "$1" 46)") ${RED}$PROBE_RES${R}"; fi
}
probe_many() { # probe_many <id…> – parallel, stores results, prints rows; skips ids already OK in this run
  local tmp="$TMP_ROOT/probe.$$.$RANDOM"; mkdir -p "$tmp"; local i=0 id todo=() res
  for id in "$@"; do [[ -n "${RUN_OK[$id]:-}" ]] || todo+=("$id"); done
  ((${#todo[@]})) && info "$(tf probing "${#todo[@]}" "$PROBE_TIMEOUT")"
  for id in "${todo[@]}"; do ( probe_one "$id" >"$tmp/$i" ) & ((i++)); done; wait
  i=0
  for id in "$@"; do
    if [[ -z "${RUN_OK[$id]:-}" ]]; then
      res=$(cat "$tmp/$i" 2>/dev/null); ((i++))
      if [[ "$res" == ok* ]]; then RUN_OK[$id]="${res#ok }"; probe_set "$id" ok "${res#ok }"
      elif (( INTERRUPTED )); then probe_set "$id" "$(t aborted)"; else probe_set "$id" "${res:-$(t noanswer)}"; fi
    fi
    probe_line "$id"
  done
  rm -rf "$tmp"
}
probe_tools_many() { # probe_tools_many <id…> – tool-calling check for models that already answered
  local tmp="$TMP_ROOT/tools.$$.$RANDOM"; mkdir -p "$tmp"; local i=0 id todo=() res
  for id in "$@"; do [[ -n "${RUN_TOOLS[$id]:-}" ]] || todo+=("$id"); done
  ((${#todo[@]})) && info "$(tf probing_tools "${#todo[@]}")"
  for id in "${todo[@]}"; do ( probe_one "$id" "$PROBE_TIMEOUT" tools >"$tmp/$i" ) & ((i++)); done; wait
  i=0
  for id in "${todo[@]}"; do res=$(cat "$tmp/$i" 2>/dev/null); ((i++))
    case "$res" in ok*) RUN_TOOLS[$id]=ok; probe_set "$id" ok "${RUN_OK[$id]:-${res#ok }}" ok;;
      notools*) RUN_TOOLS[$id]=no; probe_set "$id" ok "${RUN_OK[$id]:-${res#notools }}" no;;
      *) RUN_TOOLS[$id]=no; probe_set "$id" ok "${RUN_OK[$id]:-0}" no;; esac
  done
  for id in "$@"; do probe_line "$id"; done
  rm -rf "$tmp"
}
slot_candidates() { # slot_candidates <slot> → concrete ids from the catalog, in pattern order (≤3 per pattern)
  local catalog="$1" slot="$2" pat m seen=" "
  while read -r pat; do [[ -n "$pat" ]] || continue
    while read -r m; do [[ -n "$m" && "$seen" != *" $m "* ]] && { seen+="$m "; printf '%s\n' "$m"; }; done < <(echo "$catalog" | grep -iE -- "$pat" | head -n 3)
  done < <(candidates "$slot")
}
auto_select() { # auto_select <slot…> – probes the union of all candidates once, then decides per slot
  local slots=("$@") catalog slot m pat first union=() seen=" " n=0; local total=${#slots[@]}
  catalog=$(models_cached) || return 1
  declare -A CANDS=()
  for slot in "${slots[@]}"; do CANDS[$slot]=$(slot_candidates "$catalog" "$slot")
    while read -r m; do [[ -n "$m" && "$seen" != *" $m "* ]] && { seen+="$m "; union+=("$m"); }; done <<<"${CANDS[$slot]}"; done
  ((${#union[@]})) || { for slot in "${slots[@]}"; do bad "$(tf auto_none "$slot" "$(slot_model "$slot")")"; done; return 1; }
  printf "\n  ${B}%s${R}\n" "$(t auto_title)"; probe_many "${union[@]}"
  local rc=0
  for slot in "${slots[@]}"; do ((n++))
    local cands=() var="MODEL_${slot^^}"; while read -r m; do [[ -n "$m" ]] && cands+=("$m"); done <<<"${CANDS[$slot]}"
    printf "\n  ${B}%s${R}  ${D}%s${R}\n" "$(tf auto_slot "$slot" "${#cands[@]}")" "$(tf auto_progress "$n" "$total")"
    ((${#cands[@]})) || { bad "$(tf auto_none "$slot" "${!var:--}")"; rc=1; continue; }
    # second chance: if the top-priority pattern only timed out (cold start / load), retry once with 2x timeout
    first=$(candidates "$slot" | head -n1); local retry=() any_ok=0 r res
    for m in "${cands[@]}"; do echo "$m" | grep -qiE -- "$first" || continue
      if [[ -n "${RUN_OK[$m]:-}" ]]; then any_ok=1; else probe_get "$m"; [[ "$PROBE_RES" == *imeout* ]] && retry+=("$m"); fi; done
    if ((any_ok == 0 && ${#retry[@]})); then
      for r in "${retry[@]}"; do info "$(tf retry "$r" $((PROBE_TIMEOUT * 2)))"; res=$(probe_one "$r" $((PROBE_TIMEOUT * 2)))
        if [[ "$res" == ok* ]]; then RUN_OK[$r]="${res#ok }"; probe_set "$r" ok "${res#ok }"; else probe_set "$r" "$res"; fi; probe_line "$r"; done
    fi
    # models that need function calling: check the responders of this slot once
    if [[ "$TOOL_SLOTS" == *" $slot "* ]]; then local responders=(); for m in "${cands[@]}"; do [[ -n "${RUN_OK[$m]:-}" ]] && responders+=("$m"); done
      ((${#responders[@]})) && probe_tools_many "${responders[@]}"; fi
    local best="" best_ms=999999
    while read -r pat; do [[ -n "$pat" ]] || continue
      for m in "${cands[@]}"; do echo "$m" | grep -qiE -- "$pat" || continue
        probe_get "$m"; [[ "$PROBE_RES" == ok ]] || continue
        if [[ "$TOOL_SLOTS" == *" $slot "* && "$PROBE_TOOLS" != ok ]]; then info "$(tf auto_notools "$m" "$slot")"; continue; fi
        (( PROBE_MS < best_ms )) && { best="$m"; best_ms=$PROBE_MS; }
      done
      [[ -n "$best" ]] && break
    done < <(candidates "$slot")
    if [[ -n "$best" ]]; then set_slot "$slot" "$best"; ok "$(tf auto_pick "$slot" "$best" "$best_ms")"; save_conf; write_litellm_yaml
    else bad "$(tf auto_none "$slot" "${!var:--}")"; rc=1; fi
  done
  return $rc
}
auto_all() { auto_select code fast chat review; local rc=$?; printf "\n  %s\n" "$(t auto_done)"; local s; for s in "${SLOTS[@]}"; do slot_line "$s"; done; return $rc; }

# ── LiteLLM config ────────────────────────────────────────────────────────────
write_litellm_yaml() {
  local DROP='"prompt_cache_key", "prompt_cache_retention", "safety_identifier", "store", "metadata", "service_tier", "web_search_options"'
  local rpm=""; [[ "${NIMCTL_RPM:-}" =~ ^[0-9]+$ ]] && rpm=", rpm: $NIMCTL_RPM"
  local m seen=" "
  entry() { printf '  - model_name: %s\n    litellm_params: { model: %s/%s, api_base: %s, api_key: os.environ/NVIDIA_API_KEY%s%s, additional_drop_params: [%s] }\n' "$1" "$PROVIDER" "$2" "$API_BASE" "${3:+, max_tokens: $3}" "$rpm" "$DROP"; }
  {
    cat <<EOF
# generated by nimctl – change models via the dashboard, not here
# NVIDIA validates requests strictly and rejects OpenAI-only parameters that LiteLLM adds while
# translating Claude Code's Anthropic-format requests (e.g. prompt_cache_key from session metadata).
model_list:
EOF
    entry nim-code "${MODEL_CODE:-none}" 16384; entry nim-fast "${MODEL_FAST:-$MODEL_CODE}" 8192; entry nim-chat "${MODEL_CHAT:-$MODEL_CODE}"
    [[ -n "$MODEL_REVIEW" ]] && entry nim-review "$MODEL_REVIEW" 16384
    # every model that answered a probe is reachable by its own id, so `nimctl code --model <id>` needs no restart
    for m in $(probe_ok_models) $EXTRA_MODELS; do valid_model "$m" || continue; [[ "$seen" == *" $m "* ]] && continue; seen+="$m "; entry "$m" "$m" 16384; done
    cat <<EOF
litellm_settings: { drop_params: true, num_retries: 4, request_timeout: 300 }
router_settings:
  # NIM free tier answers slowly or with 429 under load. Never take a model out of rotation
  # (each slot has exactly one), retry with backoff instead, and fall back to the fast model.
  disable_cooldowns: true
  allowed_fails: 1000
  cooldown_time: 1
  num_retries: 4
  retry_after: 3
  fallbacks: [ { nim-code: ["nim-fast"] }, { nim-chat: ["nim-fast"] }${MODEL_REVIEW:+, { nim-review: ["nim-code"] }} ]
general_settings: { master_key: $MASTER_KEY }
EOF
  } >"$LITELLM_YAML.tmp"; chmod 600 "$LITELLM_YAML.tmp"; mv "$LITELLM_YAML.tmp" "$LITELLM_YAML"
}
yaml_has_model() { grep -qE "^  - model_name: $(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g')\$" "$LITELLM_YAML" 2>/dev/null; }
