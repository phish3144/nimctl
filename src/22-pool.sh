# ── Provider pool: other free APIs next to NVIDIA ─────────────────────────────────────────────────────────────
# Groq, Google AI Studio, Cerebras, OpenRouter (:free models) and Mistral give away a free tier and speak the
# OpenAI chat format. `nimctl pool add <provider> <key>` stores the key in ~/.nimctl/config (600) and rebuilds the
# slot chains: the candidate ranking in src/05-core.sh names provider models with `provider:` and every provider
# with a key takes part, probed like NVIDIA (ids namespaced <provider>:<id> in the probes file). Whether a provider
# ranks first or third is a matter of that list, not of being NVIDIA or not.
POOL_PROVIDERS=(groq gemini cerebras openrouter mistral)
declare -A POOL_LABEL=([groq]="Groq" [gemini]="Google AI Studio" [cerebras]="Cerebras" [openrouter]="OpenRouter" [mistral]="Mistral")
declare -A POOL_BASE=([groq]="https://api.groq.com/openai/v1" [gemini]="https://generativelanguage.googleapis.com/v1beta/openai" [cerebras]="https://api.cerebras.ai/v1" [openrouter]="https://openrouter.ai/api/v1" [mistral]="https://api.mistral.ai/v1")
declare -A POOL_KEY_URL=([groq]="https://console.groq.com/keys" [gemini]="https://aistudio.google.com/apikey" [cerebras]="https://cloud.cerebras.ai" [openrouter]="https://openrouter.ai/settings/keys" [mistral]="https://console.mistral.ai/api-keys")
RE_POOL_KEY='^[A-Za-z0-9_.-]{16,}$'                    # provider keys differ in shape; the real check is the request
T_de+=(
  [k_m]="Pool" [h_pool]="Weitere Anbieter mit kostenlosen Kontingenten in die Rangliste aufnehmen: nimctl pool [add <anbieter> [key]|remove <anbieter>|auto|test|models <anbieter>]"
  [pool_title]="Pool – Anbieter in der Rangliste" [pool_hint]="Jeder Slot ist eine Kette von Rängen über alle Anbieter (Reihenfolge: Kandidatenliste). Fällt ein Rang aus (keine Antwort für %ss, 429, 5xx), übernimmt der nächste; er pausiert %ss, dann doppelt so lange. Anbieter hinzufügen: nimctl pool add <anbieter> <key>"
  [pool_nokey]="kein Key" [pool_key_url]="Key erzeugen: %s" [pool_unknown]="unbekannter Anbieter: %s (bekannt: %s)" [pool_key_bad]="Key sieht falsch aus (mindestens 16 Zeichen, keine Leerzeichen)"
  [pool_key_in]="Key für %s (Eingabe unsichtbar, Enter = abbrechen)" [pool_checking]="prüfe Key bei %s … " [pool_rejected]="%s lehnt den Key ab (%s)" [pool_offline]="nicht erreichbar"
  [pool_added]="%s ist dabei – die Ketten wurden neu gebaut" [pool_removed]="%s entfernt – die Ketten wurden neu gebaut" [pool_not_conf]="%s ist nicht im Pool" [pool_noranks]="in keiner Kette"
  [pool_empty]="Pool leer – nimctl pool add <anbieter> <key>" [pool_empty_dash]="– keiner · m: kostenlose Anbieter hinzufügen"
  [pool_which]="Anbieter hinzufügen (%s; Enter = zurück)"
  [pool_note_groq]="~30 Anfragen/min, ~1.000/Tag, keine Karte nötig" [pool_note_gemini]="10–15 Anfragen/min, 250–1.000/Tag; Google darf Free-Tier-Daten zum Training nutzen"
  [pool_note_cerebras]="~30 Anfragen/min, 1 Mio. Tokens/Tag, sehr schnell" [pool_note_openrouter]="20 Anfragen/min, 50/Tag (1.000 ab 10 \$ Guthaben), nur :free-Modelle"
  [pool_note_mistral]="Experiment-Tier: ~1 Anfrage/s, 1 Mrd. Tokens/Monat; Daten dürfen zum Training genutzt werden"
  [pool_wz_q]="Weitere Anbieter mit kostenlosen Kontingenten hinzufügen (Groq, Google AI Studio, Cerebras, OpenRouter, Mistral)?"
  [pool_wz_key]="Key für %s (Eingabe unsichtbar, Enter = überspringen)" [pool_env]="%s: Key aus der Umgebung übernommen"
)
T_en+=(
  [k_m]="Pool" [h_pool]="add providers with free quotas to the ranking: nimctl pool [add <provider> [key]|remove <provider>|auto|test|models <provider>]"
  [pool_title]="Pool – providers in the ranking" [pool_hint]="Every slot is a chain of ranks across all providers (order: the candidate list). When a rank fails (no answer for %ss, 429, 5xx) the next one takes over; it pauses %ss, then twice as long. Add a provider: nimctl pool add <provider> <key>"
  [pool_nokey]="no key" [pool_key_url]="create a key: %s" [pool_unknown]="unknown provider: %s (known: %s)" [pool_key_bad]="key looks wrong (at least 16 characters, no spaces)"
  [pool_key_in]="key for %s (input hidden, Enter = cancel)" [pool_checking]="checking the key at %s … " [pool_rejected]="%s rejects the key (%s)" [pool_offline]="unreachable"
  [pool_added]="%s is in – the chains were rebuilt" [pool_removed]="%s removed – the chains were rebuilt" [pool_not_conf]="%s is not in the pool" [pool_noranks]="in no chain"
  [pool_empty]="pool empty – nimctl pool add <provider> <key>" [pool_empty_dash]="– none · m: add free providers"
  [pool_which]="add a provider (%s; Enter = back)"
  [pool_note_groq]="~30 requests/min, ~1,000/day, no card needed" [pool_note_gemini]="10–15 requests/min, 250–1,000/day; Google may train on free-tier data"
  [pool_note_cerebras]="~30 requests/min, 1M tokens/day, very fast" [pool_note_openrouter]="20 requests/min, 50/day (1,000 with \$10 credit), :free models only"
  [pool_note_mistral]="experiment tier: ~1 request/s, 1B tokens/month; data may be used for training"
  [pool_wz_q]="Add providers with free quotas (Groq, Google AI Studio, Cerebras, OpenRouter, Mistral)?"
  [pool_wz_key]="key for %s (input hidden, Enter = skip)" [pool_env]="%s: key taken from the environment"
)
pool_of() { local p="${1%%:*}"; [[ "$1" == *:* && " ${POOL_PROVIDERS[*]} " == *" $p "* ]] && printf '%s' "$p"; return 0; }   # provider of a namespaced id, else ""
plain_id() { if [[ -n "$(pool_of "$1")" ]]; then printf '%s' "${1#*:}"; else printf '%s' "$1"; fi; }
pool_valid() { [[ -n "$1" && " ${POOL_PROVIDERS[*]} " == *" $1 "* ]] || { bad "$(tf pool_unknown "${1:--}" "${POOL_PROVIDERS[*]}")"; return 1; }; }
pool_key() { local v="${1^^}_API_KEY"; printf '%s' "${!v:-}"; }
pool_configured() { [[ -n "$(pool_key "$1")" ]]; }
pool_active() { local p; for p in "${POOL_PROVIDERS[@]}"; do pool_configured "$p" && printf '%s\n' "$p"; done; return 0; }
pool_base() { local v="NIMCTL_POOL_BASE_${1^^}"; printf '%s' "${!v:-${POOL_BASE[$1]}}"; }   # NIMCTL_POOL_BASE_<PROVIDER>: tests, mirrors
pool_env() { local p; for p in $(pool_active); do export "${p^^}_API_KEY"; done; }   # the proxy reads the keys from its environment
pool_hdr() { # pool_hdr <provider> → the curl config file with that provider's Authorization header (600, written once per run)
  local h="$TMP_ROOT/hdr.$1"
  [[ -s "$h" ]] || { printf 'header = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\n' "$(pool_key "$1")" >"$h"; chmod 600 "$h"; }; printf '%s' "$h"
}
pool_api() { local p="$1"; shift; API_BASE="$(pool_base "$p")" HDR_FILE="$(pool_hdr "$p")" api "$@"; }   # pool_api <provider> <GET|POST> <path> [timeout] [body] – like api()
model_api() { local p; p=$(pool_of "$1"); shift; if [[ -n "$p" ]]; then pool_api "$p" "$@"; else api "$@"; fi; }   # model_api <id> <GET|POST> <path> [timeout] [body]
model_base() { local p; p=$(pool_of "$1"); if [[ -n "$p" ]]; then pool_base "$p"; else printf '%s' "$API_BASE"; fi; }   # endpoint and header file for raw curl (bench)
model_hdr() { local p; p=$(pool_of "$1"); if [[ -n "$p" ]]; then pool_hdr "$p"; else printf '%s' "$HDR_FILE"; fi; }
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
pool_ranks() { # pool_ranks <provider> → "slot rank id" per chain entry of that provider
  local s i m; for s in "${SLOTS[@]}"; do i=0; for m in $(slot_chain "$s"); do ((i++)); [[ "$(pool_of "$m")" == "$1" ]] && printf '%s %s %s\n' "$s" "$i" "${m#*:}"; done; done; return 0
}
pool_add() { # pool_add <provider> [key] → key checked at the provider, saved, chains rebuilt; exit 64 for an unknown provider
  local p="$1" key="${2:-}"; pool_valid "$p" || return 64
  if [[ -z "$key" ]]; then info "$(tf pool_key_url "${POOL_KEY_URL[$p]}")"; prompt "$(tf pool_key_in "${POOL_LABEL[$p]}")" hidden || return 1; key="$REPLY"; [[ -z "$key" ]] && { info "$(t aborted)"; return 1; }; fi
  [[ "$key" =~ $RE_POOL_KEY ]] || { bad "$(t pool_key_bad)"; return 1; }
  local v="${p^^}_API_KEY" old; old=$(pool_key "$p"); printf -v "$v" '%s' "$key"
  printf "  %s" "$(tf pool_checking "${POOL_LABEL[$p]}")"
  if ! pool_check "$p"; then printf "%s %s\n" "$NO" "$(tf pool_rejected "${POOL_LABEL[$p]}" "$POOL_ERR")"; printf -v "$v" '%s' "$old"; rm -f "$TMP_ROOT/hdr.$p"; return 1; fi
  printf "%s %s\n" "$OK" "$(t key_ok)"; save_conf
  auto_select "${SLOTS[@]}" || true; ok "$(tf pool_added "${POOL_LABEL[$p]}")"
}
pool_remove() { # pool_remove <provider> – key out of the config, its ranks out of the chains, catalog cache gone; probes stay
  local p="$1" s m keep; pool_valid "$p" || return 64; pool_configured "$p" || { info "$(tf pool_not_conf "${POOL_LABEL[$p]}")"; return 1; }
  printf -v "${p^^}_API_KEY" '%s' ""; rm -f "$NIM_DIR/models.$p.cache" "$TMP_ROOT/hdr.$p"
  for s in "${SLOTS[@]}"; do keep=""; for m in $(slot_chain "$s"); do [[ "$(pool_of "$m")" == "$p" ]] || keep+="${keep:+ }$m"; done; set_chain "$s" "$keep"; done
  save_conf; auto_select "${SLOTS[@]}" || true; ok "$(tf pool_removed "${POOL_LABEL[$p]}")"
}
pool_overview() { # the table: one row per provider – key state, its ranks in the chains or where to get a key, free-tier note
  sect "$(t pool_title)"; info "$(tf pool_hint "$STALL_TIMEOUT" "$COOLDOWN")"; printf '\n'
  local p line
  for p in "${POOL_PROVIDERS[@]}"; do
    if pool_configured "$p"; then line=""; while read -r s i m; do [[ -n "$s" ]] && line+="$s #$i $m  "; done < <(pool_ranks "$p")
      out "  $OK $(printf '%-16s' "${POOL_LABEL[$p]}") ${line:-$(t pool_noranks)}"
    else out "  $GR $(printf '%-16s' "${POOL_LABEL[$p]}") ${D}$(t pool_nokey) · $(tf pool_key_url "${POOL_KEY_URL[$p]}")${R}"; fi
    out "     ${D}$(t "pool_note_$p")${R}"
  done
}
pool_line() { # one dashboard row: "✓ Groq (3)  ✓ Cerebras (2)" – ranks held across the chains – or the hint
  local p n line=""
  for p in "${POOL_PROVIDERS[@]}"; do pool_configured "$p" || continue; n=$(pool_ranks "$p" | wc -l); line+="$OK ${POOL_LABEL[$p]} ($n)  "; done
  if [[ -n "$line" ]]; then printf '%s' "${line%  }"; else printf '%s%s%s' "$D" "$(t pool_empty_dash)" "$R"; fi
}
pool_json() { # → {"groq": {"ranks": [{"slot": "code", "rank": 2, "model": "…"}]}, …} for status --json (configured providers only)
  local j="{}" p rj; for p in $(pool_active); do rj="[]"
    while read -r s i m; do [[ -n "$s" ]] && rj=$(jq -n --argjson a "$rj" --arg s "$s" --arg i "$i" --arg m "$m" '$a + [{slot: $s, rank: ($i|tonumber), model: $m}]'); done < <(pool_ranks "$p")
    j=$(jq -n --argjson a "$j" --arg p "$p" --argjson r "$rj" '$a + {($p): {ranks: $r}}'); done
  printf '%s' "$j"
}
pool_wizard() { # setup: keys from the environment are taken over silently; on a terminal each provider can be added in turn
  local p v added=0
  for p in "${POOL_PROVIDERS[@]}"; do pool_configured "$p" || continue; [[ -n "$(pool_ranks "$p")" ]] && continue
    if pool_check "$p"; then info "$(tf pool_env "${POOL_LABEL[$p]}")"; save_conf; added=1; else bad "$(tf pool_rejected "${POOL_LABEL[$p]}" "$POOL_ERR")"; fi
  done
  (( added )) && { auto_select "${SLOTS[@]}" || true; }
  (( INTERACTIVE )) || return 0
  [[ -z "$(pool_active)" ]] || return 0
  ask "$(t pool_wz_q)" n || return 0
  for p in "${POOL_PROVIDERS[@]}"; do
    info "${POOL_LABEL[$p]}: $(t "pool_note_$p") · $(tf pool_key_url "${POOL_KEY_URL[$p]}")"
    prompt "$(tf pool_wz_key "${POOL_LABEL[$p]}")" hidden || return 0; v="$REPLY"; [[ -n "$v" ]] || continue
    pool_add "$p" "$v" || true
  done
}
pool_doctor() { # doctor: key accepted, its ranks still answering (from the stored probes); issues "pool:<provider>"
  local p s i m; for p in $(pool_active); do
    if pool_check "$p"; then ok "$(t k_m) ${POOL_LABEL[$p]}: $(t key_ok)"; else bad "$(t k_m) ${POOL_LABEL[$p]}: $POOL_ERR"; doc_issue "pool:$p"; continue; fi
    while read -r s i m; do [[ -n "$s" ]] || continue; probe_get "$p:$m"
      [[ "$PROBE_RES" == ok || -z "$PROBE_RES" ]] || { warn "$(t k_m) ${POOL_LABEL[$p]} $s #$i: $m – $PROBE_RES"; doc_issue "pool:$p"; }; done < <(pool_ranks "$p")
  done
}
cmd_pool() { # cmd_pool [add <provider> [key]|remove <provider>|auto|test|models <provider>]
  local sub="${1:-}" rc=0; (( $# )) && shift
  case "$sub" in
    "")   pool_overview; (( INTERACTIVE )) || return 0; printf '\n'; prompt "$(tf pool_which "${POOL_PROVIDERS[*]}")" || return 0; [[ -n "$REPLY" ]] || return 0
          pool_add "$REPLY" || return $?; restart_if_running;;
    add)  pool_add "${1:-}" "${2:-}"; rc=$?; (( rc == 0 )) && restart_if_running; return $rc;;
    remove|rm) pool_remove "${1:-}"; rc=$?; (( rc == 0 )) && restart_if_running; return $rc;;
    auto) auto_all; rc=$?; restart_if_running; return $rc;;
    test) svc_running proxy || { bad "$(t proxy_down)"; return 2; }; act_proxy;;
    models) pool_valid "${1:-}" || return 64; pool_configured "$1" || { bad "$(tf pool_not_conf "${POOL_LABEL[$1]}")"; return 1; }; pool_catalog "$1";;
    *)    bad "$(t invalid): $sub"; return 64;;
  esac
}
dash_register m cmd_pool k_m use
