# ── Actions (shared by the dashboard and the CLI) ─────────────────────────────
T_de+=(
  [models]="Modelle" [slots_hint]="code = Claude Code · fast = Nebenaufgaben & Fallback · chat = Browser-Chat · review = großes Modell für nimctl code --model review"
  [unprobed]="nicht geprüft → p" [slot_empty]="nicht gewählt → a" [slot_unconfigured]="Slot %s ist nicht konfiguriert → nimctl auto"
  [search]="Suchbegriff (z.B. deepseek, laguna, glm, nemotron)" [nohit]="keine Treffer" [toomany]="%d Treffer – enger filtern (max. %d)"
  [pick_slot]="Modell für Slot %s" [pick_hint]="Suchbegriff (Enter = bereits geprüfte Modelle)" [number]="Nummer (Enter = abbrechen)"
  [force]="Modell antwortet nicht – trotzdem setzen?" [unchanged]="nicht geändert" [set_ok]="%s → %s"
  [test_which]="1) code  2) fast  3) chat  4) review  5) ID eingeben" [test_prompt]="Prompt (Enter = Standardfrage)"
  [test_default]="Antworte in einem Satz auf Deutsch: Was ist NVIDIA NIM?" [reply]="Antwort" [tokens]="Tokens" [test_run]="%s … (max 180s)"
  [claude_missing]="claude fehlt → nimctl install" [proxy_starting]="Proxy läuft nicht – starte …" [claude_start]="Claude Code mit %s (fast: %s) · beenden mit /exit"
  [code_home]="Achtung: aktuelles Verzeichnis ist dein Home – Claude Code arbeitet im aktuellen Ordner. In einen Projektordner wechseln?" [code_cwd]="Projekt: %s"
  [code_model_unknown]="Modell %s ist nicht geprüft – prüfe …" [code_model_bad]="Modell %s antwortet nicht: %s" [code_model_added]="%s zum Proxy hinzugefügt"
  [code_profile]="Profil .nimctl: %s" [code_think]="Extended Thinking an (funktioniert nur mit Modellen, die es unterstützen)"
  [key_title]="API-Key" [key_help]="Erzeugen: %s  (beginnt mit nvapi-, ~6 Monate gültig)" [key_cur]="prüfe aktuellen Key …"
  [key_enter]="Neuen Key eingeben (Enter = behalten)" [key_prefix]="Key muss mit nvapi- beginnen (Buchstaben, Ziffern, - und _)" [key_saved]="gültig – gespeichert"
  [key_rej]="nicht akzeptiert (%s) – alter Key bleibt" [checking]="prüfe … " [key_same]="gleicher Key – nichts geändert"
  [key_ok]="gültig" [key_none]="kein Key → k" [key_bad]="ungültig/abgelaufen → k" [key_off]="NVIDIA nicht erreichbar" [key_unk]="nicht geprüft" [checked]="geprüft"
  [key_expires]="läuft in ~%d Tagen ab" [key_expire_soon]="Key läuft in ~%d Tagen ab – neuen Key unter %s erzeugen" [key_expired]="Key ist vermutlich abgelaufen (älter als 180 Tage)"
  [logs_which]="1) LiteLLM  2) Open WebUI  3) Watchdog  4) IDE  5) Web-UI  (Enter = zurück)" [logs_follow]="f folgt live (Ctrl+C beendet nur die Anzeige)" [logs_none]="noch kein Log: %s"
  [env_hint]="# Für andere Werkzeuge (Aider, Continue, Zed, OpenAI-SDK …): eval \"\$(nimctl env)\"" [env_proxy_down]="# Hinweis: Proxy läuft nicht – nimctl start"
  [inst_title]="Installation" [inst_missing]="fehlt" [inst_menu]="1) alles Fehlende installieren  2) PATH/Aliase  3) Autostart (systemd) an  4) Autostart aus  5) Shell-Completion%s  (Enter = zurück)"
  [inst_alias]="Befehle verfügbar: nimctl, nimctl code" [inst_npm]="npm fehlt – Node.js installieren: %s" [inst_working]="installiere %s … (2–5 Min.)"
  [sudo_jq]="jq/curl fehlen – Installation: %s" [tools_missing_ro]="%s fehlt – bitte installieren: nimctl install (oder: %s)"
  [proxy_rt]="Proxy-Roundtrip (wie Claude Code): %s" [proxy_rt_fail]="Proxy antwortet nicht wie erwartet: %s" [proxy_down]="Proxy läuft nicht → nimctl start"
)
T_en+=(
  [models]="Models" [slots_hint]="code = Claude Code · fast = side tasks & fallback · chat = browser chat · review = big model for nimctl code --model review"
  [unprobed]="not probed → p" [slot_empty]="not selected → a" [slot_unconfigured]="slot %s is not configured → nimctl auto"
  [search]="Search term (e.g. deepseek, laguna, glm, nemotron)" [nohit]="no matches" [toomany]="%d matches – narrow down (max %d)"
  [pick_slot]="Model for slot %s" [pick_hint]="Search term (Enter = already probed models)" [number]="Number (Enter = cancel)"
  [force]="model does not respond – set anyway?" [unchanged]="unchanged" [set_ok]="%s → %s"
  [test_which]="1) code  2) fast  3) chat  4) review  5) enter ID" [test_prompt]="Prompt (Enter = default question)"
  [test_default]="Answer in one sentence: what is NVIDIA NIM?" [reply]="Reply" [tokens]="tokens" [test_run]="%s … (max 180s)"
  [claude_missing]="claude missing → nimctl install" [proxy_starting]="Proxy not running – starting …" [claude_start]="Claude Code with %s (fast: %s) · quit with /exit"
  [code_home]="Careful: the current directory is your home – Claude Code works in the current folder. Change into a project folder first?" [code_cwd]="project: %s"
  [code_model_unknown]="model %s has not been probed – probing …" [code_model_bad]="model %s does not respond: %s" [code_model_added]="%s added to the proxy"
  [code_profile]="profile .nimctl: %s" [code_think]="extended thinking on (works only with models that support it)"
  [key_title]="API key" [key_help]="Create: %s  (starts with nvapi-, valid ~6 months)" [key_cur]="checking current key …"
  [key_enter]="Enter new key (Enter = keep)" [key_prefix]="key must start with nvapi- (letters, digits, - and _)" [key_saved]="valid – saved"
  [key_rej]="rejected (%s) – old key kept" [checking]="checking … " [key_same]="same key – nothing changed"
  [key_ok]="valid" [key_none]="no key → k" [key_bad]="invalid/expired → k" [key_off]="NVIDIA unreachable" [key_unk]="not checked" [checked]="checked"
  [key_expires]="expires in ~%d days" [key_expire_soon]="key expires in ~%d days – create a new one at %s" [key_expired]="key has probably expired (older than 180 days)"
  [logs_which]="1) LiteLLM  2) Open WebUI  3) Watchdog  4) IDE  5) Web UI  (Enter = back)" [logs_follow]="f follows live (Ctrl+C only leaves the view)" [logs_none]="no log yet: %s"
  [env_hint]="# For other tools (Aider, Continue, Zed, OpenAI SDK …): eval \"\$(nimctl env)\"" [env_proxy_down]="# note: proxy is not running – nimctl start"
  [inst_title]="Installation" [inst_missing]="missing" [inst_menu]="1) install everything missing  2) PATH/aliases  3) autostart (systemd) on  4) autostart off  5) shell completion%s  (Enter = back)"
  [inst_alias]="Commands available: nimctl, nimctl code" [inst_npm]="npm missing – install Node.js: %s" [inst_working]="installing %s … (2–5 min)"
  [sudo_jq]="jq/curl missing – install: %s" [tools_missing_ro]="%s missing – please install: nimctl install (or: %s)"
  [proxy_rt]="Proxy round-trip (like Claude Code): %s" [proxy_rt_fail]="Proxy did not answer as expected: %s" [proxy_down]="proxy is not running → nimctl start"
)

slot_line() { # slot_line <slot> [number] → one dashboard/summary row
  local slot="$1" n="${2:-}" m flag txt tools="" age
  m=$(slot_model "$slot"); [[ -z "$m" ]] && { out "  ${B}${n}${R}  $(printf '%-7s' "$slot") ${D}–${R}  $GR ${D}$(t slot_empty)${R}"; return; }
  probe_get "$m"; age=$(age_of "$PROBE_T")
  case "$PROBE_TOOLS" in ok) tools="$OK";; no) tools="$WA";; *) tools="$GR";; esac
  case "$PROBE_RES" in ok) flag="$OK"; txt="${D}$(t answers) · $(printf '%5s' "$PROBE_MS") ms · $age${R}";; "") flag="$GR"; txt="${D}$(t unprobed)${R}";; *) flag="$NO"; txt="${RED}$PROBE_RES${R} ${D}· $age${R}";; esac
  local w=$(( COLS - 40 )); (( w > 46 )) && w=46; (( w < 24 )) && w=24
  out "  ${B}${n:- }${R}  $(printf '%-7s' "$slot") $(printf "%-${w}s" "$(trunc "$m" "$w")") $flag $txt${tools:+  $tools}"
}
key_line() { # → text for the key row; sets KEY_FLAG
  local days; KEY_FLAG="$GR"
  case "$KEY_STATE" in
    ok) KEY_FLAG="$OK"; printf '%s  %s(%s · %s %s' "$(t key_ok)" "$D" "$(key_masked)" "$(t checked)" "$(fmt_time "$KEY_TIME" '+%H:%M')"
        days=$(key_days_left); [[ -n "$days" ]] && { (( days <= 14 )) && printf ' · %s%s%s' "$YEL" "$(tf key_expires "$days")" "$D" || printf ' · %s' "$(tf key_expires "$days")"; }; printf ')%s' "$R";;
    none) KEY_FLAG="$NO"; t key_none;; invalid) KEY_FLAG="$NO"; t key_bad;; offline) KEY_FLAG="$WA"; t key_off;; *) printf '%s%s%s' "$D" "$(t key_unk)" "$R";;
  esac
}
key_warning() { local days; days=$(key_days_left); [[ -n "$days" ]] || return 1; (( days <= 0 )) && { t key_expired; return 0; }; (( days <= 180 - KEY_WARN_DAYS )) && { tf key_expire_soon "$days" "$KEY_URL"; return 0; }; return 1; }

# ── Key ───────────────────────────────────────────────────────────────────────
act_key() {
  sect "$(t key_title)"; info "$(tf key_help "$KEY_URL")"
  if [[ -n "$NVIDIA_API_KEY" ]]; then printf "  %s " "$(t key_cur)"; check_key && printf "%s %s\n" "$OK" "$(t key_ok)" || printf "%s %s\n" "$NO" "$KEY_STATE"; fi
  prompt "$(t key_enter)" hidden || return 1; [[ -z "$REPLY" ]] && return 3
  set_key "$REPLY"
}
set_key() { # set_key <key> → validates against NVIDIA, saves, resets caches only when the key actually changed
  [[ "$1" =~ $RE_KEY ]] || { bad "$(t key_prefix)"; return 1; }
  [[ "$1" == "$NVIDIA_API_KEY" ]] && { info "$(t key_same)"; return 3; }
  local old="$NVIDIA_API_KEY"; NVIDIA_API_KEY="$1"; export NVIDIA_API_KEY; write_hdr
  printf "  %s" "$(t checking)"
  if check_key; then printf "%s %s\n" "$OK" "$(t key_saved)"; KEY_SET_AT=$(date +%s); save_state; save_conf; rm -f "$MODEL_CACHE"; : >"$PROBES"; return 0; fi
  printf "%s %s\n" "$NO" "$(tf key_rej "$KEY_STATE")"; NVIDIA_API_KEY="$old"; export NVIDIA_API_KEY; write_hdr; [[ -n "$old" ]] && check_key >/dev/null; return 1
}

# ── Probe / find / pick / test ────────────────────────────────────────────────
configured_models() { local s m; for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); [[ -n "$m" ]] && printf '%s\n' "$m"; done | sort -u; }
act_probe() { # probes every configured slot; tool calling for code/review
  local ids=() s m rc=0; sect "$(t k_p)"
  for s in "${SLOTS[@]}"; do m=$(slot_model "$s"); if [[ -n "$m" ]]; then ids+=("$m"); elif [[ "$s" != review ]]; then warn "$(tf slot_unconfigured "$s")"; fi; done
  ((${#ids[@]})) || return 1
  probe_many "${ids[@]}"
  local tools=(); for s in code review; do m=$(slot_model "$s"); [[ -n "$m" && -n "${RUN_OK[$m]:-}" ]] && tools+=("$m"); done
  ((${#tools[@]})) && probe_tools_many "${tools[@]}"
  for m in "${ids[@]}"; do probe_get "$m"; [[ "$PROBE_RES" == ok ]] || rc=4; done; return $rc
}
act_find() {
  sect "$(t k_f)"; local f="${1:-}"; [[ -z "$f" ]] && { prompt "$(t search)" || return 1; f="$REPLY"; }; [[ -z "$f" ]] && return 0
  local list n; list=$(models_cached | grep -iF -- "$f") || { bad "$(t nohit)"; return 1; }; n=$(echo "$list" | wc -l)
  ((n > 12)) && { warn "$(tf toomany "$n" 12)"; echo "$list" | sed 's/^/     /'; return 1; }
  local ids=(); while read -r m; do [[ -n "$m" ]] && ids+=("$m"); done <<<"$list"
  probe_many "${ids[@]}"
  local tools=(); for m in "${ids[@]}"; do [[ -n "${RUN_OK[$m]:-}" ]] && tools+=("$m"); done
  ((${#tools[@]})) && probe_tools_many "${tools[@]}"; return 0
}
act_pick() { # act_pick <slot> [search] – choose a slot's model from a list; probed before it is saved
  local slot="$1" f="${2:-}" list n choice sel id
  sect "$(tf pick_slot "$slot")"
  if [[ -z "$f" ]]; then prompt "$(t pick_hint)" || return 1; f="$REPLY"; fi
  if [[ -z "$f" ]]; then list=$(cut -f1 "$PROBES" | sort -u)
  elif [[ -n "$(pool_of "$f")" ]]; then list="$f"                                                        # a pool model by its namespaced id
  else list=$(models_cached | grep -iF -- "$f"); grep -qxF -- "$f" <<<"$list" && list="$f"; fi          # an exact id needs no list
  [[ -z "$list" ]] && { bad "$(t nohit)"; return 1; }; n=$(echo "$list" | wc -l); ((n > 30)) && { bad "$(tf toomany "$n" 30)"; return 1; }
  local i=1 res note
  while read -r id; do probe_get "$id"; note=""
    case "$PROBE_RES" in ok) res="$OK"; note="${D}${PROBE_MS} ms · $(age_of "$PROBE_T")${R}"; [[ "$PROBE_TOOLS" == ok ]] && note+=" $OK${D}tools${R}"; [[ "$PROBE_TOOLS" == no ]] && note+=" $WA${D}$(t tools_no)${R}";; "") res="$GR";; *) note="${D}– $PROBE_RES${R}"; res="$NO";; esac
    printf "  %s %2d) %-48s %b\n" "$res" "$i" "$(trunc "$id" 48)" "$note"; ((i++)); done <<<"$list"
  if [[ "$n" == 1 && "$list" == "$f" ]]; then choice=1; else prompt "$(t number)" || return 1; choice="$REPLY"; fi; [[ -z "$choice" ]] && { info "$(t unchanged)"; return 1; }
  [[ "$choice" =~ ^[0-9]{1,4}$ ]] && ((choice >= 1 && choice <= n)) || { bad "$(t invalid): $choice"; return 1; }
  sel=$(echo "$list" | sed -n "${choice}p"); probe_get "$sel"
  if [[ "$PROBE_RES" != ok ]]; then probe_many "$sel"; probe_get "$sel"; fi
  if [[ "$PROBE_RES" == ok && "$TOOL_SLOTS" == *" $slot "* && "$PROBE_TOOLS" != ok ]]; then probe_tools_many "$sel"; probe_get "$sel"; [[ "$PROBE_TOOLS" == ok ]] || warn "$(tf auto_notools "$sel" "$slot")"; fi
  if [[ "$PROBE_RES" != ok ]]; then ask "$(t force)" n || { info "$(t unchanged)"; return 1; }; fi
  set_slot "$slot" "$sel"; save_conf; write_litellm_yaml; ok "$(tf set_ok "$slot" "$sel")"; restart_if_running
}
act_test() { # act_test [model-or-slot] [prompt]
  local model="${1:-}" prm="${2:-}" json t0 out; sect "$(t k_t)"
  case "$model" in code|fast|chat|review) model=$(slot_model "$model");; esac
  if [[ -z "$model" ]]; then prompt "$(t test_which)" || return 1
    case "$REPLY" in 1) model="$MODEL_CODE";; 2) model="$MODEL_FAST";; 3) model="$MODEL_CHAT";; 4) model="$MODEL_REVIEW";; 5) prompt "ID" || return 1; model="$REPLY";; "") return 0;; *) bad "$(t invalid): $REPLY"; return 1;; esac
    [[ -z "$model" ]] && { bad "$(t slot_empty)"; return 1; }; fi
  valid_model "$model" || { bad "$(t invalid): $model"; return 1; }
  if [[ -z "$prm" ]]; then prompt "$(t test_prompt)" || return 1; prm="$REPLY"; fi; [[ -z "$prm" ]] && prm="$(t test_default)"
  json=$(jq -n --arg m "$(plain_id "$model")" --arg p "$prm" '{model:$m,messages:[{role:"user",content:$p}],max_tokens:300}')
  info "$(tf test_run "$model")"; t0=$(now_ms); out=$(model_api "$model" POST /chat/completions 180 "$json")
  if echo "$out" | jq -e '.choices[0]' >/dev/null 2>&1; then
    local ms=$(( $(now_ms) - t0 )); probe_set "$model" ok "$ms"
    local content; content=$(echo "$out" | jq -r '.choices[0].message.content // ""'); [[ -z "$content" ]] && content="$(echo "$out" | jq -r '.choices[0].message.reasoning_content // ""' | head -c 500) [reasoning]"
    printf "\n${GRN}┌ %s${R}\n" "$(t reply)"; echo "$content" | fold -s -w $(( COLS - 8 )) | sed "s/^/${GRN}│${R} /"
    printf "${GRN}└${R} %s %s · %s ms\n" "$(t tokens)" "$(echo "$out" | jq -r '.usage.total_tokens // "?"')" "$ms"; return 0
  fi
  local err; err=$(probe_err_text "$out" 180); probe_set "$model" "$err"; bad "$model: $err"; return 1
}

# ── Claude Code ───────────────────────────────────────────────────────────────
proxy_roundtrip() { # proxy_roundtrip <model-name> [tools] – Anthropic-format request through LiteLLM, like Claude Code
  local name="${1:-nim-code}" mode="${2:-plain}" out t0 body; t0=$(now_ms)
  if [[ "$mode" == tools ]]; then
    body=$(jq -n --arg m "$name" '{model:$m,max_tokens:80,system:"You are a coding agent.",metadata:{user_id:"nimctl-check"},
      tools:[{name:"read_file",description:"Read a file",input_schema:{type:"object",properties:{path:{type:"string"}},required:["path"]}}],
      messages:[{role:"user",content:"Read README.md"}]}')
  else body=$(jq -n --arg m "$name" '{model:$m,max_tokens:40,messages:[{role:"user",content:"Hi"}]}'); fi
  out=$(curl -s -m 120 "http://127.0.0.1:$PROXY_PORT/v1/messages" -H "x-api-key: $MASTER_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" --data-binary @- <<<"$body")
  if echo "$out" | jq -e '.content[0]' >/dev/null 2>&1; then ok "$(tf proxy_rt "$name ($mode) → $(( $(now_ms) - t0 )) ms")"; return 0; fi
  bad "$(tf proxy_rt_fail "$(echo "$out" | jq -r '.error.message // .detail // .' 2>/dev/null | tr '\n' ' ' | head -c 300)")"; return 1
}
act_proxy() { local rc=0 s; proxy_roundtrip nim-code || rc=1; proxy_roundtrip nim-code tools || rc=1; proxy_roundtrip nim-fast || rc=1; proxy_roundtrip nim-chat || rc=1; [[ -n "$MODEL_REVIEW" ]] && { proxy_roundtrip nim-review || rc=1; }; return $rc; }
act_code() { # act_code [--model <slot|id>] [--think] [--no-check] [claude args…]
  local model="" think="" check=1 maxout="${NIMCTL_MAX_OUTPUT_TOKENS:-8192}" name
  load_profile; [[ -n "$PROFILE_MODEL" ]] && { model="$PROFILE_MODEL"; info "$(tf code_profile "MODEL=$PROFILE_MODEL")"; }
  [[ "$PROFILE_THINK" == 1 ]] && think=1; [[ "$PROFILE_MAXOUT" =~ ^[0-9]+$ ]] && maxout="$PROFILE_MAXOUT"
  while (( $# )); do case "$1" in --model|-m) model="${2:-}"; shift 2;; --model=*) model="${1#*=}"; shift;; --think) think=1; shift;; --no-check) check=0; shift;; --) shift; break;; *) break;; esac; done
  has claude || { bad "$(t claude_missing)"; return 1; }
  case "$model" in ""|code) name="nim-code"; model="$MODEL_CODE";; fast|chat|review) name="nim-$model"; model=$(slot_model "$model"); [[ -n "$model" ]] || { bad "$(tf slot_unconfigured "$name")"; return 1; };;
    *) valid_model "$model" || { bad "$(t invalid): $model"; return 1; }; name="$model";; esac
  if [[ "$name" != nim-* ]] && ! yaml_has_model "$name"; then # an id that is not in the proxy yet: probe, add, restart
    probe_get "$model"; [[ "$PROBE_RES" == ok ]] || { info "$(tf code_model_unknown "$model")"; probe_many "$model" >/dev/null; probe_get "$model"; }
    [[ "$PROBE_RES" == ok ]] || { bad "$(tf code_model_bad "$model" "$PROBE_RES")"; return 1; }
    EXTRA_MODELS="$EXTRA_MODELS $model"; save_conf; write_litellm_yaml; ok "$(tf code_model_added "$model")"
    svc_running proxy && restart_svc proxy
  fi
  if [[ "$PWD" == "$HOME" ]] && (( INTERACTIVE )); then ask "$(t code_home)" n && return 1; fi
  svc_state proxy && [[ "$SVC_BY" == foreign ]] && { refuse_foreign proxy; return 1; }
  svc_running proxy || { info "$(t proxy_starting)"; start_proxy || return 1; }
  if config_newer_than_proxy; then info "$(t restart_hint)"; fi
  (( check )) && { proxy_roundtrip "$name" || { info "→ nimctl logs proxy"; return 1; }; }
  ok "$(tf claude_start "$model" "$MODEL_FAST")"; info "$(tf code_cwd "$PWD")"; [[ -n "$think" ]] && info "$(t code_think)"
  # Open models behind an OpenAI-compatible endpoint reject Anthropic-only features with 400: extended thinking
  # and very large max_tokens. Off by default; --think or THINK=1 in .nimctl switches thinking back on.
  ANTHROPIC_BASE_URL="http://127.0.0.1:$PROXY_PORT" ANTHROPIC_AUTH_TOKEN="$MASTER_KEY" ANTHROPIC_MODEL="$name" \
  ANTHROPIC_SMALL_FAST_MODEL="nim-fast" CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  MAX_THINKING_TOKENS="${think:+16000}${think:-0}" CLAUDE_CODE_MAX_OUTPUT_TOKENS="$maxout" \
  claude "$@"
}
act_env() { # prints export lines for other tools; eval "$(nimctl env)"
  local base="http://127.0.0.1:$PROXY_PORT"
  echo "$(t env_hint)"; svc_running proxy || echo "$(t env_proxy_down)"
  printf 'export ANTHROPIC_BASE_URL=%q\nexport ANTHROPIC_AUTH_TOKEN=%q\nexport ANTHROPIC_MODEL=nim-code\nexport ANTHROPIC_SMALL_FAST_MODEL=nim-fast\n' "$base" "$MASTER_KEY"
  printf 'export OPENAI_BASE_URL=%q\nexport OPENAI_API_KEY=%q\nexport OPENAI_MODEL=nim-code\n' "$base/v1" "$MASTER_KEY"
  printf 'export NIMCTL_MODEL_CODE=%q NIMCTL_MODEL_FAST=%q NIMCTL_MODEL_CHAT=%q NIMCTL_MODEL_REVIEW=%q\n' "$MODEL_CODE" "$MODEL_FAST" "$MODEL_CHAT" "$MODEL_REVIEW"
}

# ── Chat & logs ───────────────────────────────────────────────────────────────
act_chat_open() { svc_running chat || start_chat || return 1; ok "$(tf browser "$CHAT_PORT")"; open_url "http://localhost:$CHAT_PORT" || info "→ http://localhost:$CHAT_PORT"; }
log_file() { case "$1" in proxy|litellm|1) echo "$LOG_DIR/litellm.log";; chat|webui|open-webui|2) echo "$LOG_DIR/open-webui.log";; watch|3) echo "$LOG_DIR/watch.log";; ide|code-server|4) echo "$LOG_DIR/code-server.log";; web|5) echo "$LOG_DIR/web.log";; *) return 1;; esac; }
act_logs() { # act_logs [proxy|chat|watch|ide] [-f|f]
  local which="${1:-}" follow="${2:-}" f
  [[ "$which" == -f ]] && { follow=-f; which="${2:-}"; }
  if [[ -z "$which" ]]; then sect "$(t k_l)"; prompt "$(t logs_which)" || return 1; which="$REPLY"; [[ -z "$which" ]] && return 0; fi
  f=$(log_file "$which") || { bad "$(t invalid): $which"; return 1; }
  [[ -s "$f" ]] || { info "$(tf logs_none "$f")"; return 0; }
  if [[ -z "$follow" ]] && (( INTERACTIVE )) && [[ -z "$LAST_OUT" ]]; then tail -n 40 "$f"; return 0; fi
  # shellcheck disable=SC2064
  if [[ "$follow" == -f || "$follow" == f ]]; then info "$(t logs_follow)"; trap : INT; tail -n 40 -f "$f"; trap "$INT_TRAP" INT; printf '\n'; return 0; fi
  tail -n 40 "$f"; info "$(t logs_follow)"
  # shellcheck disable=SC2064
  if (( INTERACTIVE )) && [[ -t 0 ]]; then local a; read -rsn1 a || true; [[ "$a" == f ]] && { trap : INT; tail -n 0 -f "$f"; trap "$INT_TRAP" INT; printf '\n'; }; fi
}

# ── Installation ──────────────────────────────────────────────────────────────
inst_base()    { has jq && has curl && return 0; info "$(tf sudo_jq "$(pkg_hint jq curl)")"; pkg_install jq curl || { bad "$(tf inst_fail "$(pkg_hint jq curl)")"; return 1; }; }
inst_uv()      { has uv && return; info "$(tf inst_working uv)"; curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 && ok "uv" || bad "$(tf inst_fail uv)"; }
inst_litellm() { has litellm && return; inst_uv; info "$(tf inst_working litellm)"; uv tool install 'litellm[proxy]' >/dev/null 2>&1 && ok "litellm" || bad "$(tf inst_fail litellm)"; }
inst_webui()   { has open-webui && return; inst_uv; info "$(tf inst_working open-webui)"; uv tool install open-webui --python 3.11 >/dev/null 2>&1 && ok "open-webui" || bad "$(tf inst_fail open-webui)"; }
inst_claude()  { has claude && return; has npm || { bad "$(tf inst_npm "$(pkg_hint nodejs npm)")"; return 1; }; info "$(tf inst_working claude)"; npm install -g @anthropic-ai/claude-code >/dev/null 2>&1 && ok "claude" || bad "$(tf inst_fail claude)"; }
inst_all()     { inst_base; inst_uv; inst_litellm; inst_webui; inst_claude; }
inst_alias() { # PATH entry for bash and zsh, idempotent; symlink when nimctl lives elsewhere
  local self line='export PATH="$HOME/.local/bin:$PATH"' rc; self=$(realpath_ "$0")
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do [[ -f "$rc" ]] || { [[ "$rc" == *bashrc ]] || continue; }; grep -qF '.local/bin' "$rc" 2>/dev/null || echo "$line" >>"$rc"; done
  [[ "$self" == "$HOME/.local/bin/nimctl" ]] || { mkdir -p "$HOME/.local/bin"; ln -sf "$self" "$HOME/.local/bin/nimctl"; }
  ok "$(t inst_alias)"
}
act_install() {
  sect "$(t inst_title)"; local x extra=""; for x in uv jq litellm open-webui claude; do has "$x" && ok "$x" || bad "$x $(t inst_missing)"; done
  declare -F inst_watch_timer >/dev/null && extra="  6) $(t k_watch_timer)"
  prompt "$(tf inst_menu "$extra")" || return 1
  case "$REPLY" in 1) inst_all; inst_alias;; 2) inst_alias;; 3) inst_systemd;; 4) uninst_systemd;; 5) declare -F inst_completion >/dev/null && inst_completion || bad "$(t invalid)";;
    6) declare -F inst_watch_timer >/dev/null && inst_watch_timer || bad "$(t invalid): $REPLY";; "") return 0;; *) bad "$(t invalid): $REPLY"; return 1;; esac
}
