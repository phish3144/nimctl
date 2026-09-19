# ── Paths & constants ─────────────────────────────────────────────────────────
NIM_DIR="${NIMCTL_HOME:-$HOME/.nimctl}"
# $NIM_DIR/settings: NIMCTL_* values chosen in the web UI (KEY=VALUE, parsed, never sourced). Only the names below are
# read, values are limited to plain characters, and a variable already present in the environment wins.
SETTINGS_FILE="$NIM_DIR/settings"
SETTINGS_KEYS="NIMCTL_LANG NIMCTL_PROXY_PORT NIMCTL_CHAT_PORT NIMCTL_IDE_PORT NIMCTL_SEARCH_PORT NIMCTL_WEB_PORT NIMCTL_BIND NIMCTL_PROBE_TIMEOUT NIMCTL_REPROBE_HOURS NIMCTL_KEY_WARN_DAYS NIMCTL_RPM NIMCTL_RPM_MAX_WAIT NIMCTL_STALL_TIMEOUT NIMCTL_CHAT_VIA_PROXY NIMCTL_SEARCH_RESULTS NIMCTL_MAX_OUTPUT_TOKENS NIMCTL_IDE_CONTEXT NIMCTL_IDE_EXTENSIONS"
load_settings() {
  [[ -f "$SETTINGS_FILE" ]] || return 0
  local line k v
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^(NIMCTL_[A-Z_]+)=([A-Za-z0-9._:/,+\ -]*)$ ]] || continue; k="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
    [[ " $SETTINGS_KEYS " == *" $k "* && -z "${!k+x}" ]] && export "$k=$v"
  done <"$SETTINGS_FILE"
}
load_settings
CONF="$NIM_DIR/config"; STATE="$NIM_DIR/state"; PROBES="$NIM_DIR/probes"
LITELLM_YAML="$NIM_DIR/litellm.yaml"; LOG_DIR="$NIM_DIR/logs"; PID_DIR="$NIM_DIR/run"; SEARX_DIR="$NIM_DIR/searxng"; WEB_DIR="$NIM_DIR/web"
MODEL_CACHE="$NIM_DIR/models.cache"; CAND_FILE="$NIM_DIR/candidates"; LOCK_FILE="$NIM_DIR/.lock"
API_BASE="${NIMCTL_API_BASE:-https://integrate.api.nvidia.com/v1}"
PROXY_PORT="${NIMCTL_PROXY_PORT:-4000}"; CHAT_PORT="${NIMCTL_CHAT_PORT:-3000}"; IDE_PORT="${NIMCTL_IDE_PORT:-8080}"; SEARCH_PORT="${NIMCTL_SEARCH_PORT:-8888}"; WEB_PORT="${NIMCTL_WEB_PORT:-4040}"
BIND="${NIMCTL_BIND:-127.0.0.1}"                      # services listen here only (LiteLLM would default to 0.0.0.0)
PROBE_TIMEOUT="${NIMCTL_PROBE_TIMEOUT:-45}"
REPROBE_HOURS="${NIMCTL_REPROBE_HOURS:-6}"            # dashboard re-probes slots older than this
KEY_WARN_DAYS="${NIMCTL_KEY_WARN_DAYS:-165}"          # NVIDIA keys expire after ~180 days
STALL_TIMEOUT="${NIMCTL_STALL_TIMEOUT:-90}"          # seconds without a byte from the model (next chunk, or a whole non-streamed answer) before the proxy hands the request to the fallback
# LiteLLM provider prefix. "openai/" would route Anthropic-format requests (Claude Code) to OpenAI's
# Responses API, which NVIDIA does not serve (404). "custom_openai/" translates via /chat/completions.
PROVIDER="${NIMCTL_PROVIDER:-custom_openai}"
KEY_URL="https://build.nvidia.com/settings/api-keys"
RE_MODEL='^[A-Za-z0-9._/:-]+$'                        # the only shape a model id may have before it touches config/yaml/probes
RE_KEY='^nvapi-[A-Za-z0-9_-]+$'
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Candidate patterns per slot, in order of preference. Matched against the live catalog, so renamed/
# dated IDs (…-0813) keep working. The first pattern with a responding model wins; latency only decides
# between several matches of the same pattern. Override with NIMCTL_CAND_<SLOT> or ~/.nimctl/candidates.
# shellcheck disable=SC2034
CAND_CODE=(deepseek-v4-pro laguna-xs glm-5 qwen3-coder kimi-k3 nemotron-3-ultra nemotron-3-super)
# shellcheck disable=SC2034
CAND_FAST=(deepseek-v4-flash nemotron-3.5-lightning nemotron-3-nano glm-5.*flash nemotron-3-super)
# shellcheck disable=SC2034
CAND_CHAT=(nemotron-3-super nemotron-3-ultra deepseek-v4-flash llama-4-maverick mistral-medium)
# shellcheck disable=SC2034
CAND_REVIEW=(nemotron-3-ultra kimi-k3 deepseek-v4-pro glm-5 nemotron-3-super)
SLOTS=(code fast chat review)
TOOL_SLOTS=" code review "                            # slots whose model must support function calling

# ── Temp files & signals ──────────────────────────────────────────────────────
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nimctl.XXXXXX"); chmod 700 "$TMP_ROOT"
HDR_FILE="$TMP_ROOT/hdr"                              # curl config with the Authorization header – never on argv
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT
INTERRUPTED=0; INT_TRAP="-"
on_int() { INTERRUPTED=1; printf '\n'; }               # dashboard mode: Ctrl+C aborts the action, not nimctl

# ── Language ──────────────────────────────────────────────────────────────────
L="en"; [[ "${NIMCTL_LANG:-${LANG:-}}" == de* ]] && L="de"
declare -A T_de=() T_en=()
t()  { local -n _tab="T_$L"; printf '%s' "${_tab[$1]:-${T_en[$1]:-$1}}"; }
tf() { local k="$1"; shift; local fmt; fmt=$(t "$k"); printf "$fmt" "$@"; } # with format args
yes_re='^[jJyY]'; no_re='^[nN]'
T_de+=(
  [yn_Y]="[J/n]" [yn_N]="[j/N]" [enter]="[Enter]" [unknown]="unbekannte Taste" [invalid]="ungültige Eingabe"
  [noninteractive]="keine interaktive Eingabe möglich (stdin ist kein Terminal) – nutze Argumente oder --yes"
  [aborted]="abgebrochen" [ago_s]="vor %ss" [ago_m]="vor %s min" [ago_h]="vor %s h" [ago_d]="vor %s d" [ago_unknown]="Zeit unbekannt"
  [need_tool]="%s fehlt – Installation: %s"
)
T_en+=(
  [yn_Y]="[Y/n]" [yn_N]="[y/N]" [enter]="[Enter]" [unknown]="unknown key" [invalid]="invalid input"
  [noninteractive]="no interactive input possible (stdin is not a terminal) – use arguments or --yes"
  [aborted]="aborted" [ago_s]="%ss ago" [ago_m]="%s min ago" [ago_h]="%s h ago" [ago_d]="%s d ago" [ago_unknown]="time unknown"
  [need_tool]="%s missing – install: %s"
)

# ── Platform helpers ──────────────────────────────────────────────────────────
has() { command -v "$1" >/dev/null 2>&1; }
is_utf8() { local l="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"; [[ "$l" == *[Uu][Tt][Ff]-8* || "$l" == *[Uu][Tt][Ff]8* ]]; }
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }
fmt_time() { date -d "@$1" "$2" 2>/dev/null || date -r "$1" "$2" 2>/dev/null || echo "?"; }  # fmt_time <epoch> <+fmt>
now_ms() { local n; n=$(date +%s%N); [[ "$n" == *N ]] && n=$(( $(date +%s) * 1000000000 )); echo $(( n / 1000000 )); }
realpath_() { readlink -f "$1" 2>/dev/null || { cd "$(dirname "$1")" && printf '%s/%s\n' "$(pwd -P)" "$(basename "$1")"; }; }
port_open() { if has timeout; then timeout 1 bash -c "</dev/tcp/127.0.0.1/$1" >/dev/null 2>&1; else bash -c "</dev/tcp/127.0.0.1/$1" >/dev/null 2>&1; fi; }
port_owner() { # port_owner <port> → "pid/name" of the listener, if we can tell
  if has ss; then ss -ltnpH "sport = :$1" 2>/dev/null | grep -oE 'pid=[0-9]+,fd' | head -n1 | sed 's/pid=//;s/,fd//' | while read -r p; do printf '%s/%s' "$p" "$(ps -p "$p" -o comm= 2>/dev/null)"; done
  elif has lsof; then lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $2"/"$1}'; fi
}
age_of() { # age_of <epoch> → "vor 3 min" / "3 min ago"; non-numeric → unknown
  [[ "$1" =~ ^[0-9]+$ ]] || { t ago_unknown; return; }
  local d=$(( $(date +%s) - $1 )); (( d < 0 )) && d=0
  if (( d < 60 )); then tf ago_s "$d"; elif (( d < 3600 )); then tf ago_m "$((d/60))"; elif (( d < 86400 )); then tf ago_h "$((d/3600))"; else tf ago_d "$((d/86400))"; fi
}
open_url() { # open_url <url> → tries the desktop, WSL, macOS; returns 1 if nothing worked
  local u="$1"
  if has xdg-open && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then (xdg-open "$u" >/dev/null 2>&1 &); return 0; fi
  if has wslview; then (wslview "$u" >/dev/null 2>&1 &); return 0; fi
  if [[ -x /mnt/c/Windows/explorer.exe ]] || has explorer.exe; then (explorer.exe "$u" >/dev/null 2>&1 &); return 0; fi
  if [[ "$(uname -s)" == Darwin ]] && has open; then (open "$u" >/dev/null 2>&1 &); return 0; fi
  if has xdg-open; then (xdg-open "$u" >/dev/null 2>&1 &); return 0; fi
  return 1
}
run_tty() { if ( : </dev/tty ) 2>/dev/null; then "$@" </dev/tty; else "$@"; fi; }   # give sudo/apt a terminal even under curl | bash
pkg_install() { # pkg_install <pkg…> → uses the platform's package manager, asks via sudo where needed
  local sudo=""; (( EUID != 0 )) && has sudo && sudo="sudo"
  if has apt-get; then run_tty $sudo apt-get install -y "$@"
  elif has dnf; then run_tty $sudo dnf install -y "$@"
  elif has pacman; then run_tty $sudo pacman -S --noconfirm "$@"
  elif has apk; then run_tty $sudo apk add "$@"
  elif has brew; then brew install "$@"
  else return 1; fi
}
pkg_hint() { if has apt-get; then echo "sudo apt-get install $*"; elif has dnf; then echo "sudo dnf install $*"; elif has pacman; then echo "sudo pacman -S $*"; elif has apk; then echo "sudo apk add $*"; elif has brew; then echo "brew install $*"; else echo "$*"; fi; }
with_lock() { if has flock; then ( flock 9; "$@" ) 9>"$LOCK_FILE"; else "$@"; fi; }

# ── Colors & UI ───────────────────────────────────────────────────────────────
B=""; D=""; R=""; GRN=""; RED=""; YEL=""; BLU=""; CYN=""
if [[ -t 1 && -z "${NO_COLOR:-}" ]] && has tput && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  B=$(tput bold); D=$(tput dim); R=$(tput sgr0); GRN=$(tput setaf 2); RED=$(tput setaf 1); YEL=$(tput setaf 3); BLU=$(tput setaf 4); CYN=$(tput setaf 6)
fi
# Status glyphs differ in shape, not only in color: readable in pipes, logs and for color-blind users.
if is_utf8; then G_OK="✓"; G_NO="✗"; G_WA="!"; G_GR="·"; G_BOX="─"; G_SOFT="┄"; G_ELL="…"; else G_OK="+"; G_NO="x"; G_WA="!"; G_GR="-"; G_BOX="-"; G_SOFT="."; G_ELL="~"; fi
OK="${GRN}${G_OK}${R}"; NO="${RED}${G_NO}${R}"; WA="${YEL}${G_WA}${R}"; GR="${D}${G_GR}${R}"
COLS=80; term_cols() { local c; c=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}"); [[ "$c" =~ ^[0-9]+$ ]] || c=80; (( c < 60 )) && c=60; (( c > 140 )) && c=140; COLS=$c; }
term_cols
LAST_OUT=""                                            # dashboard mode: every out/ok/bad line is also written here
out()  { printf '%b\n' "$*"; [[ -n "$LAST_OUT" ]] && printf '%b\n' "$*" >>"$LAST_OUT"; return 0; }
ok()   { out "  $OK $*"; }
bad()  { out "  $NO $*"; }
warn() { out "  $WA $*"; }
info() { out "  ${D}$*${R}"; }
rule() { local s; s=$(printf '%*s' "$COLS" ''); printf '%s%s%s\n' "$D" "${s// /$G_BOX}" "$R"; }
sect() { printf "\n${B}${CYN}%s${R}\n" "$*"; rule; }
strip_ansi() { sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }
trunc() { local s="$1" n="$2"; (( ${#s} > n )) && s="${s:0:n-1}$G_ELL"; printf '%s' "$s"; }   # trunc <text> <width>
# Module registry for the dashboard: dash_register <key> <function> <label-i18n-key> [svc|models|use|sys].
# Lives here (not in 50-dashboard.sh) so modules numbered below 50 can register at top level.
declare -A DASH_FN=() DASH_LABEL=() DASH_GROUP=()
dash_register() { DASH_FN[$1]="$2"; DASH_LABEL[$1]="$3"; DASH_GROUP[$1]="${4:-use}"; }
banner() { # banner <title> [right text]
  [[ -t 1 && "${NO_CLEAR:-0}" == 0 ]] && clear
  local right="${2:-$(date '+%Y-%m-%d %H:%M')}"
  printf "${B}${BLU}%s%*s%s${R}\n" " $1" $(( COLS - ${#1} - ${#right} - 2 )) '' "$right"
  rule
}

# ── Interaction ───────────────────────────────────────────────────────────────
# NIMCTL_INTERACTIVE=1 forces prompts even when stdin is a pipe (tests, expect). --yes / NIMCTL_YES=1 answers every
# question with yes; without it, runs without a terminal take the safe default (yes for benign, no for destructive).
INTERACTIVE="${NIMCTL_INTERACTIVE:-}"; [[ -z "$INTERACTIVE" ]] && { [[ -t 0 ]] && INTERACTIVE=1 || INTERACTIVE=0; }
YES="${NIMCTL_YES:-0}"
ask() { # ask <question> [y|n] → 0 = yes. Default "n" needs an explicit yes (used for anything destructive).
  local q="$1" def="${2:-n}" a
  (( YES )) && return 0                                    # --yes / NIMCTL_YES: assume yes everywhere, terminal or not
  if (( ! INTERACTIVE )); then [[ "$def" == y ]] && return 0; return 1; fi
  if [[ "$def" == y ]]; then printf "  %s %s " "$q" "$(t yn_Y)"; else printf "  %s %s " "$q" "$(t yn_N)"; fi
  read -r a || { printf '\n'; return 1; }
  if [[ "$def" == y ]]; then [[ "$a" =~ $no_re ]] && return 1 || return 0; else [[ "$a" =~ $yes_re ]]; fi
}
prompt() { # prompt <text> [hidden] → REPLY; returns 1 on EOF / non-interactive
  REPLY=""; (( INTERACTIVE )) || { bad "$(t noninteractive)"; return 1; }
  printf "  %s: " "$1"
  if [[ "${2:-}" == hidden ]]; then read -rs REPLY || { printf '\n'; return 1; }; printf '\n'; else read -r REPLY || { printf '\n'; return 1; }; fi
}
pause() { (( INTERACTIVE )) || return 0; printf "\n  ${D}%s${R}" "$(t enter)"; read -r _ || true; }
