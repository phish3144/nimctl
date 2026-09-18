# ── Provider pool: other free APIs behind NVIDIA ─────────────────────────────────────────────────────────────
# Groq, Google AI Studio, Cerebras, OpenRouter (:free models) and Mistral give away a free tier and speak the
# OpenAI chat format. `nimctl pool add <provider> <key>` stores the key in ~/.nimctl/config (600), picks one model
# per slot from the provider's catalog with the same probe NVIDIA gets (ids namespaced <provider>:<id> in the probes
# file) and writes them into the LiteLLM config as pool-<slot>, the fallback of nim-<slot>. NVIDIA stays first; the
# pool takes a request only when NVIDIA fails it (no bytes for NIMCTL_STALL_TIMEOUT seconds, 429, 5xx). Providers
# are tried in the order below (LiteLLM `order`); one that fails is cooled down for a while and the next takes over.
POOL_PROVIDERS=(groq gemini cerebras openrouter mistral)
declare -A POOL_LABEL=([groq]="Groq" [gemini]="Google AI Studio" [cerebras]="Cerebras" [openrouter]="OpenRouter" [mistral]="Mistral")
declare -A POOL_BASE=([groq]="https://api.groq.com/openai/v1" [gemini]="https://generativelanguage.googleapis.com/v1beta/openai" [cerebras]="https://api.cerebras.ai/v1" [openrouter]="https://openrouter.ai/api/v1" [mistral]="https://api.mistral.ai/v1")
declare -A POOL_KEY_URL=([groq]="https://console.groq.com/keys" [gemini]="https://aistudio.google.com/apikey" [cerebras]="https://cloud.cerebras.ai" [openrouter]="https://openrouter.ai/settings/keys" [mistral]="https://console.mistral.ai/api-keys")
# Candidate patterns per provider and slot: regex against the provider's catalog, the first pattern with a responding
# model wins (tool calling required for code/review). Override: NIMCTL_CAND_<PROVIDER>_<SLOT> or "groq.code: …" in
# ~/.nimctl/candidates.
declare -A POOL_CAND=(
  [groq.code]="gpt-oss-120b kimi-k2 llama-3.3-70b qwen3-32b" [groq.fast]="llama-3.1-8b-instant gpt-oss-20b llama-3.3-70b"
  [groq.chat]="llama-3.3-70b gpt-oss-120b kimi-k2" [groq.review]="gpt-oss-120b kimi-k2 llama-3.3-70b"
  [gemini.code]="gemini-[0-9.]+-pro$ gemini-[0-9.]+-flash$" [gemini.fast]="flash-lite$ gemini-[0-9.]+-flash$"
  [gemini.chat]="gemini-[0-9.]+-flash$ gemini-[0-9.]+-pro$" [gemini.review]="gemini-[0-9.]+-pro$ gemini-[0-9.]+-flash$"
  [cerebras.code]="gpt-oss-120b qwen-3-235b zai-glm llama-3.3-70b" [cerebras.fast]="llama3.1-8b llama-3.3-70b gpt-oss-120b"
  [cerebras.chat]="llama-3.3-70b gpt-oss-120b qwen-3-235b" [cerebras.review]="gpt-oss-120b qwen-3-235b llama-3.3-70b"
  [openrouter.code]="qwen3-coder.*:free deepseek-chat.*:free kimi-k2.*:free glm-4.*:free gpt-oss-120b:free" [openrouter.fast]="gpt-oss-20b:free llama-3.3-70b.*:free qwen3-[0-9]+b.*:free"
  [openrouter.chat]="deepseek-chat.*:free llama-3.3-70b.*:free gpt-oss-120b:free" [openrouter.review]="deepseek-r1.*:free kimi-k2.*:free gpt-oss-120b:free"
  [mistral.code]="devstral-medium codestral-latest mistral-medium-latest" [mistral.fast]="mistral-small-latest ministral-8b"
  [mistral.chat]="mistral-medium-latest mistral-small-latest" [mistral.review]="mistral-medium-latest magistral-medium"
)
RE_POOL_KEY='^[A-Za-z0-9_.-]{16,}$'                    # provider keys differ in shape; the real check is the request
T_de+=(
  [k_m]="Pool" [h_pool]="Ausweich-Anbieter mit kostenlosen Kontingenten: nimctl pool [add <anbieter> [key]|remove <anbieter>|auto [anbieter]|test|models <anbieter>]"
  [pool_title]="Pool – Ausweich-Anbieter" [pool_hint]="NVIDIA bleibt erste Wahl. Scheitert eine Anfrage dort (keine Antwort für %ss, 429, 5xx), übernimmt der Pool: nimctl pool add <anbieter> <key>"
  [pool_nokey]="kein Key" [pool_key_url]="Key erzeugen: %s" [pool_unknown]="unbekannter Anbieter: %s (bekannt: %s)" [pool_key_bad]="Key sieht falsch aus (mindestens 16 Zeichen, keine Leerzeichen)"
  [pool_key_in]="Key für %s (Eingabe unsichtbar, Enter = abbrechen)" [pool_checking]="prüfe Key bei %s … " [pool_rejected]="%s lehnt den Key ab (%s)" [pool_offline]="nicht erreichbar"
  [pool_added]="%s im Pool – übernimmt, wenn NVIDIA ausfällt" [pool_removed]="%s aus dem Pool entfernt" [pool_not_conf]="%s ist nicht im Pool" [pool_auto]="%s: %d Modelle im Katalog, wähle je Slot …"
  [pool_pick]="%s %-7s → %s (%s ms)" [pool_nopick]="%s %s: kein Kandidat antwortet" [pool_catalog_fail]="%s: Katalog nicht abrufbar"
  [pool_empty]="Pool leer – nimctl pool add <anbieter> <key>" [pool_empty_dash]="– keiner · m: kostenlose Ausweich-Anbieter hinzufügen"
  [pool_which]="Anbieter hinzufügen (%s; Enter = zurück)" [pool_test_none]="kein Pool-Modell für Slot %s"
  [pool_note_groq]="~30 Anfragen/min, ~1.000/Tag, keine Karte nötig" [pool_note_gemini]="10–15 Anfragen/min, 250–1.000/Tag; Google darf Free-Tier-Daten zum Training nutzen"
  [pool_note_cerebras]="~30 Anfragen/min, 1 Mio. Tokens/Tag, sehr schnell" [pool_note_openrouter]="20 Anfragen/min, 50/Tag (1.000 ab 10 $ Guthaben), nur :free-Modelle"
  [pool_note_mistral]="Experiment-Tier: ~1 Anfrage/s, 1 Mrd. Tokens/Monat; Daten dürfen zum Training genutzt werden"
  [pool_wz_q]="Ausweich-Anbieter mit kostenlosen Kontingenten hinzufügen (Groq, Google AI Studio, Cerebras, OpenRouter, Mistral)?"
  [pool_wz_key]="Key für %s (Eingabe unsichtbar, Enter = überspringen)" [pool_env]="%s: Key aus der Umgebung übernommen"
)
T_en+=(
  [k_m]="Pool" [h_pool]="fallback providers with free quotas: nimctl pool [add <provider> [key]|remove <provider>|auto [provider]|test|models <provider>]"
  [pool_title]="Pool – fallback providers" [pool_hint]="NVIDIA stays first. When a request fails there (no answer for %ss, 429, 5xx) the pool takes over: nimctl pool add <provider> <key>"
  [pool_nokey]="no key" [pool_key_url]="create a key: %s" [pool_unknown]="unknown provider: %s (known: %s)" [pool_key_bad]="key looks wrong (at least 16 characters, no spaces)"
  [pool_key_in]="key for %s (input hidden, Enter = cancel)" [pool_checking]="checking the key at %s … " [pool_rejected]="%s rejects the key (%s)" [pool_offline]="unreachable"
  [pool_added]="%s in the pool – takes over when NVIDIA fails" [pool_removed]="%s removed from the pool" [pool_not_conf]="%s is not in the pool" [pool_auto]="%s: %d models in the catalog, picking one per slot …"
  [pool_pick]="%s %-7s → %s (%s ms)" [pool_nopick]="%s %s: no candidate responds" [pool_catalog_fail]="%s: catalog unavailable"
  [pool_empty]="pool empty – nimctl pool add <provider> <key>" [pool_empty_dash]="– none · m: add free fallback providers"
  [pool_which]="add a provider (%s; Enter = back)" [pool_test_none]="no pool model for slot %s"
  [pool_note_groq]="~30 requests/min, ~1,000/day, no card needed" [pool_note_gemini]="10–15 requests/min, 250–1,000/day; Google may train on free-tier data"
  [pool_note_cerebras]="~30 requests/min, 1M tokens/day, very fast" [pool_note_openrouter]="20 requests/min, 50/day (1,000 with \$10 credit), :free models only"
  [pool_note_mistral]="experiment tier: ~1 request/s, 1B tokens/month; data may be used for training"
  [pool_wz_q]="Add fallback providers with free quotas (Groq, Google AI Studio, Cerebras, OpenRouter, Mistral)?"
  [pool_wz_key]="key for %s (input hidden, Enter = skip)" [pool_env]="%s: key taken from the environment"
)
pool_of() { local p="${1%%:*}"; [[ "$1" == *:* && " ${POOL_PROVIDERS[*]} " == *" $p "* ]] && printf '%s' "$p"; }   # provider of a namespaced id, else ""
plain_id() { if [[ -n "$(pool_of "$1")" ]]; then printf '%s' "${1#*:}"; else printf '%s' "$1"; fi; }
pool_valid() { [[ -n "$1" && " ${POOL_PROVIDERS[*]} " == *" $1 "* ]] || { bad "$(tf pool_unknown "${1:--}" "${POOL_PROVIDERS[*]}")"; return 1; }; }
pool_key() { local v="${1^^}_API_KEY"; printf '%s' "${!v:-}"; }
pool_configured() { [[ -n "$(pool_key "$1")" ]]; }
pool_active() { local p; for p in "${POOL_PROVIDERS[@]}"; do pool_configured "$p" && printf '%s\n' "$p"; done; return 0; }
pool_base() { local v="NIMCTL_POOL_BASE_${1^^}"; printf '%s' "${!v:-${POOL_BASE[$1]}}"; }   # NIMCTL_POOL_BASE_<PROVIDER>: tests, mirrors
pool_slot_model() { # pool_slot_model <provider> <slot> → the plain id chosen for that slot, or ""
  local v="POOL_${1^^}" e; for e in ${!v}; do [[ "${e%%=*}" == "$2" ]] && { printf '%s' "${e#*=}"; return; }; done; return 0
}
pool_set_slot() { # pool_set_slot <provider> <slot> <id|""> → rewrites POOL_<PROVIDER> ("code=… fast=… chat=… review=…")
  local v="POOL_${1^^}" s m new=""
  for s in "${SLOTS[@]}"; do if [[ "$s" == "$2" ]]; then m="$3"; else m=$(pool_slot_model "$1" "$s"); fi; [[ -n "$m" ]] && new+="$s=$m "; done
  printf -v "$v" '%s' "${new% }"
}
pool_sanitize() { # pool_sanitize <provider> – keep only "slot=id" tokens with a known slot and a valid model id
  local v="POOL_${1^^}" e new=""; for e in ${!v}; do [[ " ${SLOTS[*]} " == *" ${e%%=*} "* ]] && valid_model "${e#*=}" && new+="$e "; done; printf -v "$v" '%s' "${new% }"
}
pool_env() { local p; for p in $(pool_active); do export "${p^^}_API_KEY"; done; }   # the proxy reads the keys from its environment
pool_api() { # pool_api <provider> <GET|POST> <path> [timeout] [body] – like api(), against the provider's endpoint
  local p="$1" h="$TMP_ROOT/hdr.$1"; shift
  [[ -s "$h" ]] || { printf 'header = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\n' "$(pool_key "$p")" >"$h"; chmod 600 "$h"; }
  API_BASE="$(pool_base "$p")" HDR_FILE="$h" api "$@"
}
model_api() { local p; p=$(pool_of "$1"); shift; if [[ -n "$p" ]]; then pool_api "$p" "$@"; else api "$@"; fi; }   # model_api <id> <GET|POST> <path> [timeout] [body]
pool_catalog() { # pool_catalog <provider> → plain ids, cached hourly in $NIM_DIR/models.<provider>.cache
  local f="$NIM_DIR/models.$1.cache" json ids
  if [[ ! -s "$f" ]] || (( $(date +%s) - $(mtime "$f") > 3600 )); then
    json=$(pool_api "$1" GET /models 20)
    if echo "$json" | jq -e '.data' >/dev/null 2>&1; then
      ids=$(echo "$json" | jq -r '.data[].id' | sed 's#^models/##' | grep -E "$RE_MODEL" | sort -u)   # Gemini lists "models/<id>"
      [[ -n "$ids" ]] && { printf '%s\n' "$ids" >"$f.tmp" && mv "$f.tmp" "$f"; }
    fi
  fi
  [[ -s "$f" ]] && cat "$f"
}
POOL_ERR=""
pool_check() { # pool_check <provider> → 0 when the key is accepted; POOL_ERR has the reason. OpenRouter's catalog is public, its /key is not.
  rm -f "$NIM_DIR/models.$1.cache" "$TMP_ROOT/hdr.$1"; POOL_ERR=""
  if [[ "$1" == openrouter ]]; then pool_api "$1" GET /key 15 >/dev/null; else pool_api "$1" GET /models 15 >/dev/null; fi
  case "$API_CODE" in 200) return 0;; 000) POOL_ERR="$(t pool_offline)";; *) POOL_ERR="HTTP $API_CODE";; esac; return 1
}
pool_candidates() { # pool_candidates <provider> <slot> → patterns: env NIMCTL_CAND_<PROVIDER>_<SLOT>, ~/.nimctl/candidates ("groq.code: a b"), defaults
  local ev="NIMCTL_CAND_${1^^}_${2^^}" line
  if [[ -n "${!ev:-}" ]]; then printf '%s\n' ${!ev}; return; fi
  if [[ -f "$CAND_FILE" ]]; then line=$(grep -E "^$1\.$2:" "$CAND_FILE" 2>/dev/null | head -n1); [[ -n "$line" ]] && { printf '%s\n' ${line#*:}; return; }; fi
  printf '%s\n' ${POOL_CAND[$1.$2]}
}
pool_auto_one() { # pool_auto_one <provider> – one model per slot from the provider's catalog (probed like NVIDIA's), saved and written to the proxy config
  local p="$1" catalog slot m pat best best_ms union=() seen=" " rc=0; declare -A C=()
  catalog=$(pool_catalog "$p"); [[ -n "$catalog" ]] || { bad "$(tf pool_catalog_fail "${POOL_LABEL[$p]}")"; return 1; }
  info "$(tf pool_auto "${POOL_LABEL[$p]}" "$(echo "$catalog" | wc -l)")"
  local pats; for slot in "${SLOTS[@]}"; do mapfile -t pats < <(pool_candidates "$p" "$slot"); C[$slot]=$(match_candidates "$catalog" "${pats[@]}")
    while read -r m; do [[ -n "$m" && "$seen" != *" $m "* ]] && { seen+="$m "; union+=("$p:$m"); }; done <<<"${C[$slot]}"; done
  ((${#union[@]})) || { bad "$(tf pool_nopick "${POOL_LABEL[$p]}" "*")"; return 1; }
  probe_many "${union[@]}"
  local tc=(); for slot in code review; do while read -r m; do [[ -n "$m" && -n "${RUN_OK[$p:$m]:-}" && " ${tc[*]} " != *" $p:$m "* ]] && tc+=("$p:$m"); done <<<"${C[$slot]}"; done
  ((${#tc[@]})) && probe_tools_many "${tc[@]}"
  for slot in "${SLOTS[@]}"; do best=""; best_ms=999999
    while read -r pat; do [[ -n "$pat" ]] || continue
      while read -r m; do [[ -n "$m" ]] || continue; echo "$m" | grep -qiE -- "$pat" || continue
        probe_get "$p:$m"; [[ "$PROBE_RES" == ok ]] || continue
        [[ "$TOOL_SLOTS" == *" $slot "* && "$PROBE_TOOLS" != ok ]] && continue
        (( PROBE_MS < best_ms )) && { best="$m"; best_ms=$PROBE_MS; }
      done <<<"${C[$slot]}"
      [[ -n "$best" ]] && break
    done < <(pool_candidates "$p" "$slot")
    pool_set_slot "$p" "$slot" "$best"
    if [[ -n "$best" ]]; then ok "$(tf pool_pick "${POOL_LABEL[$p]}" "$slot" "$best" "$best_ms")"; else warn "$(tf pool_nopick "${POOL_LABEL[$p]}" "$slot")"; rc=1; fi
  done
  save_conf; write_litellm_yaml; return $rc
}
pool_add() { # pool_add <provider> [key] → key checked at the provider, saved, models selected; exit 64 for an unknown provider
  local p="$1" key="${2:-}"; pool_valid "$p" || return 64
  if [[ -z "$key" ]]; then info "$(tf pool_key_url "${POOL_KEY_URL[$p]}")"; prompt "$(tf pool_key_in "${POOL_LABEL[$p]}")" hidden || return 1; key="$REPLY"; [[ -z "$key" ]] && { info "$(t aborted)"; return 1; }; fi
  [[ "$key" =~ $RE_POOL_KEY ]] || { bad "$(t pool_key_bad)"; return 1; }
  local v="${p^^}_API_KEY" old; old=$(pool_key "$p"); printf -v "$v" '%s' "$key"
  printf "  %s" "$(tf pool_checking "${POOL_LABEL[$p]}")"
  if ! pool_check "$p"; then printf "%s %s\n" "$NO" "$(tf pool_rejected "${POOL_LABEL[$p]}" "$POOL_ERR")"; printf -v "$v" '%s' "$old"; rm -f "$TMP_ROOT/hdr.$p"; return 1; fi
  printf "%s %s\n" "$OK" "$(t key_ok)"; save_conf
  pool_auto_one "$p" || true; ok "$(tf pool_added "${POOL_LABEL[$p]}")"
}
pool_remove() { # pool_remove <provider> – key and models out of the config, catalog cache gone; probes stay
  local p="$1"; pool_valid "$p" || return 64; pool_configured "$p" || { info "$(tf pool_not_conf "${POOL_LABEL[$p]}")"; return 1; }
  printf -v "${p^^}_API_KEY" '%s' ""; printf -v "POOL_${p^^}" '%s' ""; rm -f "$NIM_DIR/models.$p.cache" "$TMP_ROOT/hdr.$p"
  save_conf; write_litellm_yaml; ok "$(tf pool_removed "${POOL_LABEL[$p]}")"
}
pool_overview() { # the table: one row per provider – key state, chosen models or where to get a key, free-tier note
  sect "$(t pool_title)"; info "$(tf pool_hint "$STALL_TIMEOUT")"; printf '\n'
  local p s m line
  for p in "${POOL_PROVIDERS[@]}"; do
    if pool_configured "$p"; then line=""; for s in "${SLOTS[@]}"; do m=$(pool_slot_model "$p" "$s"); [[ -n "$m" ]] && line+="$s=$m  "; done
      out "  $OK $(printf '%-16s' "${POOL_LABEL[$p]}") ${line:-$(tf pool_nopick "" "*")}"
    else out "  $GR $(printf '%-16s' "${POOL_LABEL[$p]}") ${D}$(t pool_nokey) · $(tf pool_key_url "${POOL_KEY_URL[$p]}")${R}"; fi
    out "     ${D}$(t "pool_note_$p")${R}"
  done
}
pool_test() { # Anthropic-format round trip through the proxy for every pool-<slot> that has a deployment
  svc_running proxy || { bad "$(t proxy_down)"; return 2; }
  local s p any rc=0; for s in "${SLOTS[@]}"; do any=0; for p in $(pool_active); do [[ -n "$(pool_slot_model "$p" "$s")" ]] && any=1; done
    if ((any)); then proxy_roundtrip "pool-$s" || rc=1; [[ "$s" == code ]] && { proxy_roundtrip pool-code tools || rc=1; }; else info "$(tf pool_test_none "$s")"; fi; done
  return $rc
}
pool_line() { # one dashboard row: "✓ Groq (4)  ✓ Cerebras (3)" or the hint
  local p s n line=""
  for p in "${POOL_PROVIDERS[@]}"; do pool_configured "$p" || continue; n=0; for s in "${SLOTS[@]}"; do [[ -n "$(pool_slot_model "$p" "$s")" ]] && ((n++)); done; line+="$OK ${POOL_LABEL[$p]} ($n)  "; done
  if [[ -n "$line" ]]; then printf '%s' "${line%  }"; else printf '%s%s%s' "$D" "$(t pool_empty_dash)" "$R"; fi
}
pool_json() { # → {"groq": {"models": {"code": …}}, …} for status --json (configured providers only)
  local j="{}" p s m mj; for p in $(pool_active); do mj="{}"
    for s in "${SLOTS[@]}"; do m=$(pool_slot_model "$p" "$s"); mj=$(jq -n --argjson a "$mj" --arg s "$s" --arg m "$m" '$a + {($s): (if $m=="" then null else $m end)}'); done
    j=$(jq -n --argjson a "$j" --arg p "$p" --argjson m "$mj" '$a + {($p): {models: $m}}'); done
  printf '%s' "$j"
}
pool_wizard() { # setup: keys from the environment are taken over silently; on a terminal each provider can be added in turn
  local p v
  for p in "${POOL_PROVIDERS[@]}"; do pool_configured "$p" || continue; [[ -z "$(pool_slot_model "$p" code)$(pool_slot_model "$p" fast)" ]] || continue
    if pool_check "$p"; then info "$(tf pool_env "${POOL_LABEL[$p]}")"; save_conf; pool_auto_one "$p" || true; else bad "$(tf pool_rejected "${POOL_LABEL[$p]}" "$POOL_ERR")"; fi
  done
  (( INTERACTIVE )) || return 0
  [[ -z "$(pool_active)" ]] || return 0
  ask "$(t pool_wz_q)" n || return 0
  for p in "${POOL_PROVIDERS[@]}"; do
    info "${POOL_LABEL[$p]}: $(t "pool_note_$p") · $(tf pool_key_url "${POOL_KEY_URL[$p]}")"
    prompt "$(tf pool_wz_key "${POOL_LABEL[$p]}")" hidden || return 0; v="$REPLY"; [[ -n "$v" ]] || continue
    pool_add "$p" "$v" || true
  done
}
pool_doctor() { # doctor: key accepted, chosen models still answering (from the stored probes); issues "pool:<provider>"
  local p s m; for p in $(pool_active); do
    if pool_check "$p"; then ok "$(t k_m) ${POOL_LABEL[$p]}: $(t key_ok)"; else bad "$(t k_m) ${POOL_LABEL[$p]}: $POOL_ERR"; doc_issue "pool:$p"; continue; fi
    for s in "${SLOTS[@]}"; do m=$(pool_slot_model "$p" "$s"); [[ -n "$m" ]] || continue; probe_get "$p:$m"
      [[ "$PROBE_RES" == ok || -z "$PROBE_RES" ]] || { warn "$(t k_m) ${POOL_LABEL[$p]} $s: $m – $PROBE_RES"; doc_issue "pool:$p"; }; done
  done
}
cmd_pool() { # cmd_pool [add <provider> [key]|remove <provider>|auto [provider]|test|models <provider>]
  local sub="${1:-}" rc=0 p; (( $# )) && shift
  case "$sub" in
    "")   pool_overview; (( INTERACTIVE )) || return 0; printf '\n'; prompt "$(tf pool_which "${POOL_PROVIDERS[*]}")" || return 0; [[ -n "$REPLY" ]] || return 0
          pool_add "$REPLY" || return $?; restart_if_running;;
    add)  pool_add "${1:-}" "${2:-}"; rc=$?; (( rc == 0 )) && restart_if_running; return $rc;;
    remove|rm) pool_remove "${1:-}"; rc=$?; (( rc == 0 )) && restart_if_running; return $rc;;
    auto) if [[ -n "${1:-}" ]]; then pool_valid "$1" || return 64; pool_configured "$1" || { bad "$(tf pool_not_conf "${POOL_LABEL[$1]}")"; return 1; }; pool_auto_one "$1" || rc=1
          else [[ -n "$(pool_active)" ]] || { info "$(t pool_empty)"; return 1; }; for p in $(pool_active); do pool_auto_one "$p" || rc=1; done; fi
          restart_if_running; return $rc;;
    test) pool_test;;
    models) pool_valid "${1:-}" || return 64; pool_configured "$1" || { bad "$(tf pool_not_conf "${POOL_LABEL[$1]}")"; return 1; }; pool_catalog "$1";;
    *)    bad "$(t invalid): $sub"; return 64;;
  esac
}
dash_register m cmd_pool k_m use
