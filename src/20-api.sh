# ── API ───────────────────────────────────────────────────────────────────────
T_de+=(
  [probing]="prüfe %d Modell(e) mit echter Anfrage (max. %ss) …" [probing_tools]="prüfe Tool-Calling bei %d Modell(en) …"
  [no_endpoint]="kein Endpoint für diesen Account" [timeout]="Timeout nach %ss" [ratelimit]="Rate-Limit (429)" [noanswer]="keine Antwort"
  [overloaded]="überlastet (Worker-Limit)" [retry]="Zweiter Versuch für %s mit %ss …" [cached]="(bereits geprüft)" [answers]="antwortet"
  [tools_ok]="Tools ✓" [tools_no]="keine Tool-Calls" [catalog_fail]="Katalog nicht abrufbar" [catalog_stale]="Katalog-Abruf fehlgeschlagen – nutze Stand von %s"
  [auto_title]="Automatische Modellwahl" [auto_slot]="Slot %s: %d Kandidaten" [auto_pick]="%s → %s (%s ms)" [auto_none]="kein Kandidat antwortet – Slot %s bleibt: %s"
  [auto_notools]="%s antwortet, kann aber keine Tool-Calls – für Slot %s ungeeignet" [auto_done]="Fertig. Ergebnis:" [auto_progress]="Slot %d/%d"
  [auto_chain]="Ausweich in dieser Reihenfolge: %s" [chain_more]="Ausweich"
  [probing_size]="prüfe %s-Anfrage bei %s … " [size_no]="%s: %s-Anfrage abgelehnt (%s) %s" [auto_toolarge]="%s nimmt keine %s-Anfrage – für Slot %s ungeeignet"
  [auto_toolsfail]="%s: Tool-Calling-Prüfung fehlgeschlagen (%s) – für Slot %s diesmal übersprungen" [pick_toolarge]="%s nimmt keine %s-Anfrage (%s) – Claude Code schickt größere; trotzdem gesetzt"
)
T_en+=(
  [probing]="probing %d model(s) with a real request (max %ss) …" [probing_tools]="probing tool calling on %d model(s) …"
  [no_endpoint]="no endpoint for this account" [timeout]="timeout after %ss" [ratelimit]="rate limit (429)" [noanswer]="no answer"
  [overloaded]="overloaded (worker limit)" [retry]="Second attempt for %s with %ss …" [cached]="(already probed)" [answers]="responds"
  [tools_ok]="tools ✓" [tools_no]="no tool calls" [catalog_fail]="catalog unavailable" [catalog_stale]="catalog refresh failed – using the copy from %s"
  [auto_title]="Automatic model selection" [auto_slot]="Slot %s: %d candidates" [auto_pick]="%s → %s (%s ms)" [auto_none]="no candidate responds – slot %s stays: %s"
  [auto_notools]="%s responds but cannot make tool calls – unsuitable for slot %s" [auto_done]="Done. Result:" [auto_progress]="slot %d/%d"
  [auto_chain]="fallback in this order: %s" [chain_more]="fallback"
  [probing_size]="probing a %s request at %s … " [size_no]="%s: %s request rejected (%s) %s" [auto_toolarge]="%s takes no %s request – unsuitable for slot %s"
  [auto_toolsfail]="%s: tool-calling check failed (%s) – skipped for slot %s this time" [pick_toolarge]="%s takes no %s request (%s) – Claude Code sends bigger ones; set anyway"
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
probe_ok_models() { local re; re="^($(IFS='|'; printf '%s' "${POOL_PROVIDERS[*]}")):"; awk -F'\t' -v re="$re" '$2=="ok" && $1 !~ re {print $1}' "$PROBES" | sort -u; }   # NVIDIA ids only – pool ids are namespaced

# ── Request sizes: ~/.nimctl/sizes, tab-separated: id  tokens  result  epoch. A rank must take a request of its slot's size ──
# (SLOT_TOKENS, src/05-core.sh): free tiers cap a single request at their per-minute token limit (Groq: 6–12k), a model's
# context window is what it is – neither shows in a 5-token probe. Probed once per model and size, kept for a day.
SIZE_TTL=86400; SIZE_RES=""; SIZE_T=0
size_k() { printf '%sk' "$(( $1 / 1000 ))"; }   # 32000 → 32k
size_get() { # size_get <id> <tokens> → SIZE_RES (ok|error text|""), SIZE_T (epoch)
  local rec; rec=$(awk -F'\t' -v id="$1" -v n="$2" '$1==id && $2==n {l=$3"\x1f"$4} END{print l}' "$SIZES" 2>/dev/null)
  SIZE_RES="${rec%%$'\x1f'*}"; SIZE_T="${rec#*$'\x1f'}"; [[ "$SIZE_T" =~ ^[0-9]+$ ]] || SIZE_T=0
}
_size_write() { { awk -F'\t' -v id="$1" -v n="$2" '!($1==id && $2==n)' "$SIZES" 2>/dev/null; printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(date +%s)"; } >"$SIZES.tmp" && mv "$SIZES.tmp" "$SIZES"; }
size_set() { valid_model "$1" || return 1; with_lock _size_write "$1" "$2" "${3//$'\t'/ }"; }   # size_set <id> <tokens> <ok|error>
size_probe() { # size_probe <id> <tokens> → "ok <ms>" | error text: one request of about that many tokens, 5 tokens back
  local id="$1" n="$2" to=$((PROBE_TIMEOUT * 2)) body out t0 i; local pad="$TMP_ROOT/pad.$n"
  # ~10 tokens a sentence; a file, not an argument (128 KB limit); no pipe – a runner that ignores SIGPIPE would print "Broken pipe" into the probe line
  [[ -s "$pad" ]] || { for ((i = 0; i < n / 10; i++)); do printf 'The quick brown fox jumps over the lazy dog. '; done; } >"$pad"
  body=$(jq -n --arg m "$(plain_id "$id")" --rawfile pad "$pad" '{model:$m,max_tokens:5,messages:[{role:"user",content:("Reply with the single word OK. Ignore the text below.\n\n"+$pad)}]}')
  t0=$(now_ms); out=$(model_api "$id" POST /chat/completions "$to" "$body")
  if echo "$out" | jq -e '.choices[0]' >/dev/null 2>&1; then echo "ok $(( $(now_ms) - t0 ))"; return; fi
  probe_err_text "$out" "$to"
}
size_ok() { # size_ok <id> <tokens> → 0 when the model takes a request of that size; probes when unknown or older than a day, prints the probe or the cached rejection
  local id="$1" n="$2" res; size_get "$id" "$n"
  if [[ -z "$SIZE_RES" ]] || (( $(date +%s) - SIZE_T > SIZE_TTL )); then
    printf "  %s" "$(tf probing_size "$(size_k "$n")" "$(trunc "$id" 46)")"; res=$(size_probe "$id" "$n")
    (( INTERRUPTED )) && { printf "%s\n" "$(t aborted)"; return 1; }
    if [[ "$res" == ok* ]]; then size_set "$id" "$n" ok; printf "%s %s ms\n" "$OK" "${res#ok }"; else size_set "$id" "$n" "$res"; printf "%s %s\n" "$NO" "$res"; fi
    size_get "$id" "$n"
  elif [[ "$SIZE_RES" != ok ]]; then out "  $NO $(tf size_no "$(trunc "$id" 46)" "$(size_k "$n")" "$SIZE_RES" "$(t cached)")"; fi
  [[ "$SIZE_RES" == ok ]]
}

probe_err_text() { # probe_err_text <raw body> <timeout> → readable error
  local out="$1" to="$2" err
  err=$(echo "$out" | jq -r '.error.message // .detail // .message // .' 2>/dev/null | tr '\n\t' '  ' | head -c 200)
  [[ -z "$out" ]] && err="$(tf timeout "$to")"
  case "$err" in *"Not found for account"*|*Function*) err="$(t no_endpoint)";; *429*|*"Too Many"*) err="$(t ratelimit)";;
    *ResourceExhausted*|*"request limit"*|*"limit reached"*) err="$(t overloaded)";; esac
  printf '%s' "${err:-$(t noanswer)}"
}
probe_one() { # probe_one <id> [timeout] [tools] → "ok <ms>" | "notools <ms>" | error text; a namespaced id (groq:…) is probed at its provider
  local id="$1" to="${2:-$PROBE_TIMEOUT}" mode="${3:-plain}" body out t0 pid; pid=$(plain_id "$id")
  if [[ "$mode" == tools ]]; then
    body=$(jq -n --arg m "$pid" '{model:$m,max_tokens:64,tool_choice:"auto",
      tools:[{type:"function",function:{name:"read_file",description:"Read a file from disk",parameters:{type:"object",properties:{path:{type:"string"}},required:["path"]}}}],
      messages:[{role:"user",content:"Use the read_file tool to read README.md. Call the tool, do not answer in prose."}]}')
  else body=$(jq -n --arg m "$pid" '{model:$m,messages:[{role:"user",content:"Hi"}],max_tokens:5}'); fi
  t0=$(now_ms); out=$(model_api "$id" POST /chat/completions "$to" "$body")
  if echo "$out" | jq -e '.choices[0]' >/dev/null 2>&1; then
    if [[ "$mode" == tools ]] && ! echo "$out" | jq -e '.choices[0].message.tool_calls[0].function.name' >/dev/null 2>&1; then echo "notools $(( $(now_ms) - t0 ))"; return; fi
    echo "ok $(( $(now_ms) - t0 ))"; return
  fi
  probe_err_text "$out" "$to"
}
declare -A RUN_OK=() RUN_TOOLS=() TOOLS_ERR=()  # answers in this process: id → ms / ok|no|err (never downgraded within a run); TOOLS_ERR: why a check failed
probe_line() { # probe_line <id> → one table row from the stored result: answer, latency, tool calling, request sizes (32k ✓ · 8k ✗)
  probe_get "$1"; local tools="" sizes="" n
  case "$PROBE_TOOLS" in ok) tools="${D}$(t tools_ok)${R}";; no) tools="${YEL}$(t tools_no)${R}";; esac
  for n in $(printf '%s\n' "${SLOT_TOKENS[@]}" | sort -nru); do size_get "$1" "$n"; case "$SIZE_RES" in ok) sizes+="  ${D}$(size_k "$n")${R} $OK";; "") ;; *) sizes+="  ${D}$(size_k "$n")${R} $NO";; esac; done
  if [[ "$PROBE_RES" == ok ]]; then out "  $OK $(printf '%-46s' "$(trunc "$1" 46)") $(t answers) ${PROBE_MS} ms  $tools$sizes"
  else out "  $NO $(printf '%-46s' "$(trunc "$1" 46)") ${RED}$PROBE_RES${R}"; fi
}
probe_many() { # probe_many <id…> – parallel, stores results, prints rows; skips ids already OK in this run
  local tmp="$TMP_ROOT/probe.$$.$RANDOM"; mkdir -p "$tmp"; local i=0 id todo=() res
  for id in "$@"; do [[ -n "${RUN_OK[$id]:-}" ]] || todo+=("$id"); done
  ((${#todo[@]})) && [[ -z "${PROBE_QUIET:-}" ]] && info "$(tf probing "${#todo[@]}" "$PROBE_TIMEOUT")"   # PROBE_QUIET: no headline, no rows (scan prints its own)
  for id in "${todo[@]}"; do ( probe_one "$id" >"$tmp/$i" ) & ((i++)); done; wait
  i=0
  for id in "$@"; do
    if [[ -z "${RUN_OK[$id]:-}" ]]; then
      res=$(cat "$tmp/$i" 2>/dev/null); ((i++))
      if [[ "$res" == ok* ]]; then RUN_OK[$id]="${res#ok }"; probe_set "$id" ok "${res#ok }"
      elif (( INTERRUPTED )); then probe_set "$id" "$(t aborted)"; else probe_set "$id" "${res:-$(t noanswer)}"; fi
    fi
    [[ -n "${PROBE_QUIET:-}" ]] || probe_line "$id"
  done
  rm -rf "$tmp"
}
probe_tools_many() { # probe_tools_many <id…> – tool-calling check for models that already answered
  local tmp="$TMP_ROOT/tools.$$.$RANDOM"; mkdir -p "$tmp"; local i=0 id todo=() res
  for id in "$@"; do [[ -n "${RUN_TOOLS[$id]:-}" ]] || todo+=("$id"); done
  ((${#todo[@]})) && [[ -z "${PROBE_QUIET:-}" ]] && info "$(tf probing_tools "${#todo[@]}")"
  for id in "${todo[@]}"; do ( probe_one "$id" "$PROBE_TIMEOUT" tools >"$tmp/$i" ) & ((i++)); done; wait
  i=0; local again=()
  for id in "${todo[@]}"; do res=$(cat "$tmp/$i" 2>/dev/null); ((i++))
    case "$res" in ok*) RUN_TOOLS[$id]=ok; probe_set "$id" ok "${RUN_OK[$id]:-${res#ok }}" ok;;
      notools*) RUN_TOOLS[$id]=no; probe_set "$id" ok "${RUN_OK[$id]:-${res#notools }}" no;;
      *) again+=("$id");; esac
  done
  for id in "${again[@]}"; do res=$(probe_one "$id" $((PROBE_TIMEOUT * 2)) tools)   # a timeout or 429 says nothing about tools: one more try, then undecided
    case "$res" in ok*) RUN_TOOLS[$id]=ok; probe_set "$id" ok "${RUN_OK[$id]:-${res#ok }}" ok;;
      notools*) RUN_TOOLS[$id]=no; probe_set "$id" ok "${RUN_OK[$id]:-${res#notools }}" no;;
      *) RUN_TOOLS[$id]=err; TOOLS_ERR[$id]="${res:-$(t noanswer)}"; probe_set "$id" ok "${RUN_OK[$id]:-0}" "";; esac
  done
  [[ -n "${PROBE_QUIET:-}" ]] || for id in "$@"; do probe_line "$id"; done
  rm -rf "$tmp"
}
pat_provider() { local p="${1%%:*}"; [[ "$1" == *:* && " ${POOL_PROVIDERS[*]} " == *" $p "* ]] && printf '%s' "$p"; return 0; }   # provider of a candidate pattern, "" = NVIDIA
pat_regex() { if [[ -n "$(pat_provider "$1")" ]]; then printf '%s' "${1#*:}"; else printf '%s' "$1"; fi; }
declare -A CATALOG_CACHE=()
catalog_cached() { # catalog_cached <provider|""> → ids (namespaced for a provider; empty when the provider has no key), fetched once per run
  local p="$1" k="${1:-nim}"                                   # "" (NVIDIA) cannot be an associative-array key
  if [[ -z "${CATALOG_CACHE[$k]+x}" ]]; then
    if [[ -z "$p" ]]; then CATALOG_CACHE[$k]=$(models_cached); elif pool_configured "$p"; then CATALOG_CACHE[$k]=$(pool_catalog "$p" | sed "s/^/$p:/"); else CATALOG_CACHE[$k]=""; fi
  fi
  printf '%s\n' "${CATALOG_CACHE[$k]}"
}
match_candidates() { # match_candidates <pattern…> → concrete ids in ranking order (≤2 per pattern), pool ids namespaced
  local pat p re m seen=" "
  for pat in "$@"; do [[ -n "$pat" ]] || continue; p=$(pat_provider "$pat"); re=$(pat_regex "$pat")
    while read -r m; do [[ -n "$m" && "$seen" != *" $m "* ]] && { seen+="$m "; printf '%s\n' "$m"; }; done < <(catalog_cached "$p" | grep -iE -- "$re" | head -n 2)
  done
}
slot_candidates() { local pats=() pat; while read -r pat; do [[ -n "$pat" ]] && pats+=("$pat"); done < <(candidates "$1"); match_candidates "${pats[@]}"; }   # slot_candidates <slot>
pattern_applies() { local p; p=$(pat_provider "$1"); [[ -z "$p" ]] || pool_configured "$p"; }   # a pool pattern counts only when that provider has a key
auto_select() { # auto_select <slot…> – probes the union of all candidates once, then builds each slot's chain in ranking order
  local slots=("$@") slot m pat first union=() seen=" " n=0; local total=${#slots[@]}
  models_cached >/dev/null || return 1
  declare -A CANDS=()
  for slot in "${slots[@]}"; do CANDS[$slot]=$(slot_candidates "$slot")
    while read -r m; do [[ -n "$m" && "$seen" != *" $m "* ]] && { seen+="$m "; union+=("$m"); }; done <<<"${CANDS[$slot]}"; done
  ((${#union[@]})) || { for slot in "${slots[@]}"; do bad "$(tf auto_none "$slot" "$(slot_model "$slot")")"; done; return 1; }
  printf "\n  ${B}%s${R}\n" "$(t auto_title)"; probe_many "${union[@]}"
  local rc=0
  for slot in "${slots[@]}"; do ((n++))
    local cands=() var="MODEL_${slot^^}"; while read -r m; do [[ -n "$m" ]] && cands+=("$m"); done <<<"${CANDS[$slot]}"
    printf "\n  ${B}%s${R}  ${D}%s${R}\n" "$(tf auto_slot "$slot" "${#cands[@]}")" "$(tf auto_progress "$n" "$total")"
    ((${#cands[@]})) || { bad "$(tf auto_none "$slot" "${!var:--}")"; rc=1; continue; }
    # second chance: if the top applicable pattern only timed out (cold start / load), retry once with 2x timeout
    first=""; while read -r pat; do [[ -n "$pat" ]] && pattern_applies "$pat" && { first="$pat"; break; }; done < <(candidates "$slot")
    local retry=() any_ok=0 r res fp fre; fp=$(pat_provider "$first"); fre=$(pat_regex "$first")
    for m in "${cands[@]}"; do [[ "$(pool_of "$m")" == "$fp" ]] && echo "$m" | grep -qiE -- "$fre" || continue
      if [[ -n "${RUN_OK[$m]:-}" ]]; then any_ok=1; else probe_get "$m"; [[ "$PROBE_RES" == *imeout* ]] && retry+=("$m"); fi; done
    if ((any_ok == 0 && ${#retry[@]})); then
      for r in "${retry[@]}"; do info "$(tf retry "$r" $((PROBE_TIMEOUT * 2)))"; res=$(probe_one "$r" $((PROBE_TIMEOUT * 2)))
        if [[ "$res" == ok* ]]; then RUN_OK[$r]="${res#ok }"; probe_set "$r" ok "${res#ok }"; else probe_set "$r" "$res"; fi; probe_line "$r"; done
    fi
    # models that need function calling: check the responders of this slot once
    if [[ "$TOOL_SLOTS" == *" $slot "* ]]; then local responders=(); for m in "${cands[@]}"; do [[ -n "${RUN_OK[$m]:-}" ]] && responders+=("$m"); done
      ((${#responders[@]})) && probe_tools_many "${responders[@]}"; fi
    # the ranking: patterns in order, a pattern's responders by latency (tool calling where the slot needs it)
    local rows p re notools=" " tokens="${SLOT_TOKENS[$slot]:-0}" ordered=()
    while read -r pat; do [[ -n "$pat" ]] || continue; p=$(pat_provider "$pat"); re=$(pat_regex "$pat"); rows=()
      for m in "${cands[@]}"; do [[ "$(pool_of "$m")" == "$p" ]] && echo "$m" | grep -qiE -- "$re" || continue
        probe_get "$m"; [[ "$PROBE_RES" == ok ]] || continue
        if [[ "$TOOL_SLOTS" == *" $slot "* && "$PROBE_TOOLS" != ok ]]; then
          [[ "$notools" == *" $m "* ]] || { notools+="$m "; if [[ "$PROBE_TOOLS" == no ]]; then info "$(tf auto_notools "$m" "$slot")"; else info "$(tf auto_toolsfail "$m" "${TOOLS_ERR[$m]:-?}" "$slot")"; fi; }; continue; fi
        rows+=("$PROBE_MS $m")
      done
      ((${#rows[@]})) || continue
      while read -r _ m; do [[ -n "$m" && " ${ordered[*]} " != *" $m "* ]] && ordered+=("$m"); done < <(printf '%s\n' "${rows[@]}" | sort -n)
    done < <(candidates "$slot")
    # the chain: first pass takes at most CHAIN_PER_PROVIDER ranks per provider (every provider with a key gets its turn), the
    # second pass fills up with the ranks skipped for that, in ranking order; a rank must take a request of the slot's size,
    # probed once per model and size, until the chain has CHAIN_LEN ranks
    local chain=() skipped=() pass; declare -A percount=()
    for pass in 1 2; do (( pass == 2 )) && ordered=("${skipped[@]}")
      for m in "${ordered[@]}"; do (( ${#chain[@]} >= CHAIN_LEN )) && break 2
        p=$(pool_of "$m"); p="${p:-nim}"
        if (( pass == 1 && ${percount[$p]:-0} >= CHAIN_PER_PROVIDER )); then skipped+=("$m"); continue; fi
        if (( tokens > 0 )) && ! size_ok "$m" "$tokens"; then info "$(tf auto_toolarge "$m" "$(size_k "$tokens")" "$slot")"; continue; fi
        chain+=("$m"); percount[$p]=$(( ${percount[$p]:-0} + 1 ))
      done
    done
    if ((${#chain[@]})); then
      chain=("${chain[@]:0:CHAIN_LEN}"); set_chain "$slot" "${chain[*]}"; probe_get "${chain[0]}"
      ok "$(tf auto_pick "$slot" "${chain[0]}" "$PROBE_MS")"; (( ${#chain[@]} > 1 )) && info "$(tf auto_chain "${chain[*]:1}")"
      save_conf; write_litellm_yaml
    else bad "$(tf auto_none "$slot" "${!var:--}")"; rc=1; fi
  done
  return $rc
}
auto_all() { auto_select code fast chat review; local rc=$?; printf "\n  %s\n" "$(t auto_done)"; local s; for s in "${SLOTS[@]}"; do slot_line "$s"; done; return $rc; }

# ── LiteLLM config ────────────────────────────────────────────────────────────
COOLDOWN="${NIMCTL_COOLDOWN:-90}"    # seconds a failed rank is paused for timeouts/5xx (RateLimit uses NIMCTL_COOLDOWN_RATELIMIT)
rank_group() { if (( $2 == 1 )); then printf 'nim-%s' "$1"; else printf 'nim-%s-r%s' "$1" "$2"; fi; }   # rank_group <slot> <rank> → model group name
write_litellm_yaml() {
  local DROP='"prompt_cache_key", "prompt_cache_retention", "safety_identifier", "store", "metadata", "service_tier", "web_search_options"'
  local m s i n seen=" " fbs=() fb groups nimg="" cj="{}" tail
  entry() { # entry <name> <id> [max_tokens] – NVIDIA, or the pool provider a namespaced id names (skipped when that provider has no key)
    local p base keyref id="$2"; p=$(pool_of "$2")
    if [[ -n "$p" ]]; then pool_configured "$p" || return 0; base=$(pool_base "$p"); keyref="os.environ/${p^^}_API_KEY"; id="${2#*:}"; else base="$API_BASE"; keyref="os.environ/NVIDIA_API_KEY"; fi
    printf '  - model_name: %s\n    litellm_params: { model: %s/%s, api_base: %s, api_key: %s%s, timeout: %s, additional_drop_params: [%s] }\n' "$1" "$PROVIDER" "$id" "$base" "$keyref" "${3:+, max_tokens: $3}" "$STALL_TIMEOUT" "$DROP"
  }
  {
    cat <<EOF
# generated by nimctl – change models via the dashboard, not here
# NVIDIA validates requests strictly and rejects OpenAI-only parameters that LiteLLM adds while
# translating Claude Code's Anthropic-format requests (e.g. prompt_cache_key from session metadata).
# Every slot is a chain of ranks: nim-<slot> is rank 1, nim-<slot>-r2 … the others, each its own group with one
# deployment, falling back down the chain. nimctl_hooks (src/25-throttle.sh) sends a request to the best rank that
# is not paused and pauses a rank that fails (timeout: no byte for NIMCTL_STALL_TIMEOUT seconds, 429, 5xx) in
# LiteLLM's cooldown cache, so the running request's fallbacks and every later request skip it.
model_list:
EOF
    for s in "${SLOTS[@]}"; do [[ "$s" == review && -z "$MODEL_REVIEW" ]] && continue; i=0; groups=()
      for m in $(slot_chain "$s"); do ((i++)); groups+=("$(rank_group "$s" "$i")")
        if [[ "$s" == fast ]]; then entry "$(rank_group "$s" "$i")" "$m" 8192; elif [[ "$s" == chat ]]; then entry "$(rank_group "$s" "$i")" "$m" "${NIMCTL_MAX_OUTPUT_TOKENS:-16384}"; else entry "$(rank_group "$s" "$i")" "$m" 16384; fi
        [[ -n "$(pool_of "$m")" ]] || nimg+="\"$(rank_group "$s" "$i")\","
        cj=$(jq -n --argjson a "$cj" --arg g "$(rank_group "$s" "$i")" --arg m "$m" '$a | .models[$g] = $m')
      done
      (( i == 0 )) && { m=$(slot_model "$s"); [[ -n "$m" ]] || m="$MODEL_CODE"; entry "nim-$s" "${m:-none}" 16384; groups=("nim-$s"); nimg+="\"nim-$s\","; }
      cj=$(jq -n --argjson a "$cj" --arg s "$s" --arg g "${groups[*]}" '$a | .[$s] = ($g | split(" "))')
      # fallbacks: every rank falls through the rest of its chain, then to the fast model (review: the code model)
      case "$s" in fast) tail="";; review) tail='"nim-code"';; *) tail='"nim-fast"';; esac
      n=${#groups[@]}; for ((i = 0; i < n; i++)); do local list=""; local j; for ((j = i + 1; j < n; j++)); do list+="${list:+, }\"${groups[j]}\""; done
        [[ -n "$tail" ]] && list+="${list:+, }$tail"; [[ -n "$list" ]] && fbs+=("{ ${groups[i]}: [$list] }"); done
    done
    # every model that answered a probe is reachable by its own id, so `nimctl code --model <id>` needs no restart
    for m in $(probe_ok_models) $EXTRA_MODELS $CHAIN_CODE $CHAIN_FAST $CHAIN_CHAT $CHAIN_REVIEW; do valid_model "$m" || continue; [[ "$seen" == *" $m "* ]] && continue; seen+="$m "; entry "$m" "$m" 16384; done
    fb=$(printf '%s, ' "${fbs[@]}"); fb="${fb%, }"
    cat <<EOF
# nimctl_hooks.throttle: NVIDIA budget (NIMCTL_RPM per minute), chain routing and cooldowns, see src/25-throttle.sh
litellm_settings: { drop_params: true, num_retries: 1, request_timeout: 300, callbacks: nimctl_hooks.throttle }
router_settings:
  # cooldowns come from nimctl_hooks (LiteLLM never cools a single-deployment group down by itself); a stall is not
  # retried on the same rank but handed down the chain, a 429 or 5xx gets one retry first
  disable_cooldowns: true
  allowed_fails: 1000
  cooldown_time: 1
  num_retries: 1
  retry_after: 1
  retry_policy: { TimeoutErrorRetries: 0, DefaultRetries: 0, RateLimitErrorRetries: 1, InternalServerErrorRetries: 1, ServiceUnavailableErrorRetries: 1, BadRequestErrorRetries: 0, AuthenticationErrorRetries: 0, ContentPolicyViolationErrorRetries: 0 }
  fallbacks: [ $fb ]
general_settings: { master_key: $MASTER_KEY }
EOF
  } >"$LITELLM_YAML.tmp"; chmod 600 "$LITELLM_YAML.tmp"; mv "$LITELLM_YAML.tmp" "$LITELLM_YAML"
  jq -n --argjson a "$cj" --argjson nim "[${nimg%,}]" '$a + {nim: $nim}' >"$NIM_DIR/chains.json.tmp" && mv "$NIM_DIR/chains.json.tmp" "$NIM_DIR/chains.json"
}
yaml_has_model() { grep -qE "^  - model_name: $(printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g')\$" "$LITELLM_YAML" 2>/dev/null; }
