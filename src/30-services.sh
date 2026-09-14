# ── Services: LiteLLM proxy and Open WebUI ───────────────────────────────────
T_de+=(
  [proxy]="Proxy" [chat]="Chat" [up]="läuft" [down]="aus" [by_systemd]="systemd" [by_nimctl]="nimctl" [by_foreign]="fremd"
  [svc_already]="%s läuft bereits" [svc_missing]="%s fehlt → nimctl install" [svc_nokey]="kein API-Key → nimctl key" [svc_nomodel]="kein Modell gewählt → nimctl auto"
  [svc_up]="%s läuft  http://localhost:%s" [svc_fail]="%s startet nicht → nimctl logs %s" [svc_died]="%s ist direkt nach dem Start beendet worden → nimctl logs %s"
  [svc_stopped]="%s gestoppt" [svc_foreign]="Port %s ist belegt von %s – nicht von nimctl gestartet" [svc_wasdown]="%s lief nicht"
  [port_hint]="Anderen Port wählen: %s=%s nimctl" [waiting]="warte auf Port %s … %ss" [browser]="Chat: http://localhost:%s"
  [restart_q]="Dienste neu starten, damit die Änderung wirkt?" [restart_hint]="Änderung wirkt nach Neustart: nimctl restart"
  [claude_attached]="Hinweis: Eine laufende Claude-Code-Sitzung verliert beim Neustart die Verbindung."
  [inst_sysd]="Autostart aktiv (systemd --user: nimctl-proxy, nimctl-chat)" [inst_sysd_off]="Autostart entfernt" [inst_fail]="%s fehlgeschlagen" [no_systemd]="systemd nicht verfügbar – Autostart nur unter Linux mit systemd"
  [unit_failed]="systemd-Unit %s ist im Zustand failed → journalctl --user -u %s"
)
T_en+=(
  [proxy]="Proxy" [chat]="Chat" [up]="up" [down]="down" [by_systemd]="systemd" [by_nimctl]="nimctl" [by_foreign]="foreign"
  [svc_already]="%s already running" [svc_missing]="%s missing → nimctl install" [svc_nokey]="no API key → nimctl key" [svc_nomodel]="no model selected → nimctl auto"
  [svc_up]="%s up  http://localhost:%s" [svc_fail]="%s failed to start → nimctl logs %s" [svc_died]="%s exited right after starting → nimctl logs %s"
  [svc_stopped]="%s stopped" [svc_foreign]="port %s is taken by %s – not started by nimctl" [svc_wasdown]="%s was not running"
  [port_hint]="pick another port: %s=%s nimctl" [waiting]="waiting for port %s … %ss" [browser]="Chat: http://localhost:%s"
  [restart_q]="Restart services to apply the change?" [restart_hint]="the change applies after a restart: nimctl restart"
  [claude_attached]="Note: a running Claude Code session loses its connection during the restart."
  [inst_sysd]="autostart enabled (systemd --user: nimctl-proxy, nimctl-chat)" [inst_sysd_off]="autostart removed" [inst_fail]="%s failed" [no_systemd]="systemd not available – autostart only on Linux with systemd"
  [unit_failed]="systemd unit %s is in state failed → journalctl --user -u %s"
)
svc_bin()  { case "$1" in proxy) echo litellm;; chat) echo open-webui;; esac; }
svc_port() { case "$1" in proxy) echo "$PROXY_PORT";; chat) echo "$CHAT_PORT";; esac; }
svc_label(){ t "$1"; }
proc_is() { # proc_is <pid> <name> → the process exists and its command line mentions <name>
  [[ "${1:-}" =~ ^[0-9]+$ ]] && kill -0 "$1" 2>/dev/null || return 1
  local cmd; if [[ -r "/proc/$1/cmdline" ]]; then cmd=$(tr '\0' ' ' <"/proc/$1/cmdline"); else cmd=$(ps -p "$1" -o args= 2>/dev/null); fi
  [[ "$cmd" == *"$2"* ]]
}
unit_active() { has systemctl && systemctl --user is-active "nimctl-$1" >/dev/null 2>&1; }
unit_failed() { has systemctl && [[ "$(systemctl --user is-failed "nimctl-$1" 2>/dev/null)" == failed ]]; }
SVC_PID=""; SVC_BY=""
svc_state() { # svc_state <proxy|chat> → 0 if something listens; SVC_BY = nimctl | systemd | foreign
  local s="$1" pid; SVC_PID=""; SVC_BY=""
  pid=$(cat "$PID_DIR/$s.pid" 2>/dev/null)
  if proc_is "$pid" "$(svc_bin "$s")"; then SVC_PID="$pid"; SVC_BY=nimctl; return 0; fi
  [[ -n "$pid" ]] && rm -f "$PID_DIR/$s.pid"                   # stale pid file: never trust it again
  if unit_active "$s"; then SVC_BY=systemd; SVC_PID=$(systemctl --user show -p MainPID --value "nimctl-$s" 2>/dev/null); return 0; fi
  if port_open "$(svc_port "$s")"; then SVC_BY=foreign; SVC_PID=$(port_owner "$(svc_port "$s")"); return 0; fi
  return 1
}
svc_running() { svc_state "$1" && [[ "$SVC_BY" != foreign ]]; }
svc_started_at() { cat "$PID_DIR/$1.started" 2>/dev/null || echo 0; }
config_newer_than_proxy() { svc_running proxy && (( $(mtime "$LITELLM_YAML") > $(svc_started_at proxy) + 1 )); }
wait_port() { # wait_port <port> <seconds> [pid] → 0 up, 1 timeout, 2 process died
  local i=0 sp='|/-\' max=$(( $2 * 2 ))
  while (( i < max )); do
    port_open "$1" && { printf "\r%60s\r" ""; return 0; }
    [[ -n "${3:-}" ]] && ! kill -0 "$3" 2>/dev/null && { printf "\r%60s\r" ""; return 2; }
    (( INTERACTIVE )) && printf "\r  %s %s " "${sp:i%4:1}" "$(tf waiting "$1" "$((i/2))")"; sleep 0.5; ((i++))
  done; printf "\r%60s\r" ""; return 1
}
refuse_foreign() { bad "$(tf svc_foreign "$(svc_port "$1")" "${SVC_PID:-?}")"; info "$(tf port_hint "NIMCTL_$( [[ $1 == proxy ]] && echo PROXY || echo CHAT)_PORT" "$(( $(svc_port "$1") + 100 ))")"; }
_start_result() { # _start_result <svc> <pid>
  local rc; wait_port "$(svc_port "$1")" "$3" "$2"; rc=$?
  case $rc in 0) ok "$(tf svc_up "$(svc_label "$1")" "$(svc_port "$1")")"; return 0;;
    2) bad "$(tf svc_died "$(svc_label "$1")" "$1")";; *) bad "$(tf svc_fail "$(svc_label "$1")" "$1")";; esac
  tail -n 8 "$LOG_DIR/$(svc_bin "$1").log" 2>/dev/null | sed 's/^/      /'; rm -f "$PID_DIR/$1.pid"; return 1
}
start_proxy() {
  if svc_state proxy; then [[ "$SVC_BY" == foreign ]] && { refuse_foreign proxy; return 1; }; info "$(tf svc_already "$(t proxy)")"; return 0; fi
  has litellm || { bad "$(tf svc_missing litellm)"; return 1; }
  [[ -n "$NVIDIA_API_KEY" ]] || { bad "$(t svc_nokey)"; return 1; }; [[ -n "$MODEL_CODE" ]] || { bad "$(t svc_nomodel)"; return 1; }
  write_litellm_yaml
  NVIDIA_API_KEY="$NVIDIA_API_KEY" nohup litellm --config "$LITELLM_YAML" --host "$BIND" --port "$PROXY_PORT" >"$LOG_DIR/litellm.log" 2>&1 &
  echo $! >"$PID_DIR/proxy.pid"; date +%s >"$PID_DIR/proxy.started"
  _start_result proxy $! 90
}
chat_env() { # exports the Open WebUI environment; NIMCTL_CHAT_VIA_PROXY=1 routes the chat through LiteLLM (retries, fallbacks, curated model list)
  if [[ "${NIMCTL_CHAT_VIA_PROXY:-0}" == 1 ]]; then export OPENAI_API_BASE_URL="http://127.0.0.1:$PROXY_PORT/v1" OPENAI_API_KEY="$MASTER_KEY" DEFAULT_MODELS="nim-chat"
  else export OPENAI_API_BASE_URL="$API_BASE" OPENAI_API_KEY="$NVIDIA_API_KEY" DEFAULT_MODELS="$MODEL_CHAT"; fi
  export ENABLE_OLLAMA_API=false DATA_DIR="$NIM_DIR/webui-data" WEBUI_AUTH=true
}
start_chat() {
  if svc_state chat; then [[ "$SVC_BY" == foreign ]] && { refuse_foreign chat; return 1; }; info "$(tf svc_already "$(t chat)")"; return 0; fi
  has open-webui || { bad "$(tf svc_missing open-webui)"; return 1; }; [[ -n "$NVIDIA_API_KEY" ]] || { bad "$(t svc_nokey)"; return 1; }
  [[ "${NIMCTL_CHAT_VIA_PROXY:-0}" == 1 ]] && { svc_running proxy || start_proxy || return 1; }
  ( chat_env; nohup open-webui serve --host "$BIND" --port "$CHAT_PORT" >"$LOG_DIR/open-webui.log" 2>&1 & echo $! >"$PID_DIR/chat.pid" )
  date +%s >"$PID_DIR/chat.started"
  _start_result chat "$(cat "$PID_DIR/chat.pid")" 150
}
stop_svc() {
  local s="$1"
  if ! svc_state "$s"; then info "$(tf svc_wasdown "$(svc_label "$s")")"; rm -f "$PID_DIR/$s.pid"; return 0; fi
  case "$SVC_BY" in
    systemd) systemctl --user stop "nimctl-$s" && ok "$(tf svc_stopped "$(svc_label "$s")")";;
    nimctl)  kill "$SVC_PID" 2>/dev/null; local i=0; while (( i < 20 )) && kill -0 "$SVC_PID" 2>/dev/null; do sleep 0.25; ((i++)); done
             kill -0 "$SVC_PID" 2>/dev/null && kill -9 "$SVC_PID" 2>/dev/null; ok "$(tf svc_stopped "$(svc_label "$s")")"; rm -f "$PID_DIR/$s.pid";;
    *)       warn "$(tf svc_foreign "$(svc_port "$s")" "${SVC_PID:-?}")";;
  esac
}
start_all() { local rc=0; start_proxy || rc=1; start_chat || rc=1; return $rc; }
stop_all()  { stop_svc proxy; stop_svc chat; }
restart_svc() { # keeps a systemd-managed service under systemd
  if svc_state "$1" && [[ "$SVC_BY" == systemd ]]; then write_litellm_yaml; systemctl --user restart "nimctl-$1" && ok "$(tf svc_up "$(svc_label "$1")" "$(svc_port "$1")")"; return; fi
  stop_svc "$1"; "start_$1"
}
restart_all() { restart_svc proxy; restart_svc chat; }
restart_if_running() { # after a config change; explicit yes only, because a Claude Code session may be attached
  svc_running proxy || svc_running chat || return 0
  (( INTERACTIVE )) || { info "$(t restart_hint)"; return 0; }
  svc_running proxy && info "$(t claude_attached)"
  if ask "$(t restart_q)" n; then restart_all; else info "$(t restart_hint)"; fi
}

# ── systemd (user units) ──────────────────────────────────────────────────────
fg_service() { # fg_service <proxy|chat> – ExecStart target of the units; same guards as start_*, then exec
  case "$1" in
    proxy) has litellm || { echo "nimctl: litellm missing" >&2; exit 1; }; [[ -n "$NVIDIA_API_KEY" && -n "$MODEL_CODE" ]] || { echo "nimctl: not configured – run nimctl setup" >&2; exit 1; }
           write_litellm_yaml; date +%s >"$PID_DIR/proxy.started"; exec litellm --config "$LITELLM_YAML" --host "$BIND" --port "$PROXY_PORT";;
    chat)  has open-webui || { echo "nimctl: open-webui missing" >&2; exit 1; }; [[ -n "$NVIDIA_API_KEY" ]] || { echo "nimctl: no API key – run nimctl setup" >&2; exit 1; }
           chat_env; date +%s >"$PID_DIR/chat.started"; exec open-webui serve --host "$BIND" --port "$CHAT_PORT";;
    *) exit 64;;
  esac
}
unit_dir() { echo "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"; }
inst_systemd() {
  has systemctl || { bad "$(t no_systemd)"; return 1; }
  local d n self; d=$(unit_dir); mkdir -p "$d"; self=$(realpath_ "$0")
  for n in proxy chat; do printf '[Unit]\nDescription=nimctl %s\nStartLimitIntervalSec=300\nStartLimitBurst=5\n\n[Service]\nExecStart=%s _fg %s\nRestart=on-failure\nRestartSec=10\nEnvironment=NIMCTL_HOME=%s\n\n[Install]\nWantedBy=default.target\n' "$n" "$self" "$n" "$NIM_DIR" >"$d/nimctl-$n.service"; done
  stop_svc proxy >/dev/null; stop_svc chat >/dev/null   # hand the ports over to the units
  systemctl --user daemon-reload && systemctl --user enable --now nimctl-proxy nimctl-chat && ok "$(t inst_sysd)" || { bad "$(tf inst_fail systemd)"; return 1; }
}
uninst_systemd() {
  has systemctl || return 0; systemctl --user disable --now nimctl-proxy nimctl-chat nimctl-watch.timer 2>/dev/null
  rm -f "$(unit_dir)"/nimctl-{proxy,chat}.service "$(unit_dir)"/nimctl-watch.{service,timer}; systemctl --user daemon-reload 2>/dev/null; ok "$(t inst_sysd_off)"
}
