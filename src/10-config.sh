# ── Config & state ────────────────────────────────────────────────────────────
# ~/.nimctl/config and state are plain KEY=VALUE files. They are parsed, never sourced: model ids come from
# a remote catalog and are validated against RE_MODEL before they are written or used anywhere.
read_kv() { # read_kv <file> <VAR…> → assigns known keys only
  local f="$1"; shift; [[ -f "$f" ]] || return 0
  local line k v w
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]] || continue; k="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
    v="${v#\"}"; v="${v%\"}"                             # accept the quoted format of nimctl ≤ 1.0
    for w in "$@"; do [[ "$k" == "$w" ]] && printf -v "$k" '%s' "$v"; done
  done <"$f"
}
valid_model() { [[ -n "$1" && "$1" =~ $RE_MODEL && ${#1} -le 200 ]]; }
gen_secret() { if has openssl; then openssl rand -hex 24; else od -An -N24 -tx1 /dev/urandom | tr -d ' \n'; fi; }
load_conf() {
  mkdir -p "$NIM_DIR" "$LOG_DIR" "$PID_DIR"; chmod 700 "$NIM_DIR" 2>/dev/null; touch "$PROBES"
  NVIDIA_API_KEY="${NVIDIA_API_KEY:-${NIMCTL_API_KEY:-}}"
  MODEL_CODE=""; MODEL_FAST=""; MODEL_CHAT=""; MODEL_REVIEW=""; MASTER_KEY=""; EXTRA_MODELS=""
  KEY_STATE="unknown"; KEY_TIME=0; KEY_SET_AT=0
  local envkey="$NVIDIA_API_KEY"
  read_kv "$CONF" NVIDIA_API_KEY MODEL_CODE MODEL_FAST MODEL_CHAT MODEL_REVIEW MASTER_KEY EXTRA_MODELS
  [[ -n "$envkey" ]] && NVIDIA_API_KEY="$envkey"           # an explicit environment key wins over the file
  read_kv "$STATE" KEY_STATE KEY_TIME KEY_SET_AT
  [[ "$NVIDIA_API_KEY" =~ $RE_KEY ]] || NVIDIA_API_KEY=""
  local s v; for s in "${SLOTS[@]}"; do v="MODEL_${s^^}"; valid_model "${!v}" || printf -v "$v" '%s' ""; done
  [[ "$KEY_TIME" =~ ^[0-9]+$ ]] || KEY_TIME=0; [[ "$KEY_SET_AT" =~ ^[0-9]+$ ]] || KEY_SET_AT=0
  [[ "$MASTER_KEY" =~ ^[A-Za-z0-9_-]{16,}$ ]] || { MASTER_KEY="sk-nimctl-$(gen_secret)"; [[ -f "$CONF" ]] && save_conf; }
  export NVIDIA_API_KEY; write_hdr
}
save_conf() {
  local e="" m; for m in $EXTRA_MODELS; do valid_model "$m" && e+="$m "; done; EXTRA_MODELS="${e% }"
  printf 'NVIDIA_API_KEY=%s\nMODEL_CODE=%s\nMODEL_FAST=%s\nMODEL_CHAT=%s\nMODEL_REVIEW=%s\nMASTER_KEY=%s\nEXTRA_MODELS=%s\n' \
    "$NVIDIA_API_KEY" "$MODEL_CODE" "$MODEL_FAST" "$MODEL_CHAT" "$MODEL_REVIEW" "$MASTER_KEY" "$EXTRA_MODELS" >"$CONF.tmp"
  chmod 600 "$CONF.tmp"; mv "$CONF.tmp" "$CONF"
}
save_state() { printf 'KEY_STATE=%s\nKEY_TIME=%s\nKEY_SET_AT=%s\n' "$KEY_STATE" "$KEY_TIME" "$KEY_SET_AT" >"$STATE"; }
configured() { [[ -n "$NVIDIA_API_KEY" && -n "$MODEL_CODE" && -n "$MODEL_CHAT" ]]; }
slot_model() { local v="MODEL_${1^^}"; printf '%s' "${!v}"; }
set_slot() { local v="MODEL_${1^^}"; printf -v "$v" '%s' "$2"; }
key_days_left() { # → days until the key is ~180 days old, or "" when unknown
  (( KEY_SET_AT > 0 )) || { printf ''; return; }
  echo $(( 180 - ( $(date +%s) - KEY_SET_AT ) / 86400 ))
}
key_masked() { local k="$NVIDIA_API_KEY"; (( ${#k} > 10 )) && printf 'nvapi-…%s' "${k: -4}" || printf '%s' "$k"; }
candidates() { # candidates <slot> → patterns, from env NIMCTL_CAND_<SLOT>, ~/.nimctl/candidates ("code: a b c") or defaults
  local slot="$1" ev="NIMCTL_CAND_${1^^}" arr="CAND_${1^^}[@]" line
  if [[ -n "${!ev:-}" ]]; then printf '%s\n' ${!ev}; return; fi
  if [[ -f "$CAND_FILE" ]]; then line=$(grep -E "^${slot}:" "$CAND_FILE" 2>/dev/null | head -n1); [[ -n "$line" ]] && { printf '%s\n' ${line#*:}; return; }; fi
  printf '%s\n' "${!arr}"
}
# Project profile: a .nimctl file in the current directory (KEY=VALUE) for `nimctl code`.
PROFILE_MODEL=""; PROFILE_THINK=""; PROFILE_MAXOUT=""
load_profile() {
  local f="$PWD/.nimctl"; [[ -f "$f" ]] || return 0
  local MODEL="" THINK="" MAX_OUTPUT_TOKENS=""; read_kv "$f" MODEL THINK MAX_OUTPUT_TOKENS
  PROFILE_MODEL="$MODEL"; PROFILE_THINK="$THINK"; PROFILE_MAXOUT="$MAX_OUTPUT_TOKENS"
}
