# ── Web UI: the cockpit in the browser ──────────────────────────────────────────────────────────────────────
# `nimctl web` serves http://127.0.0.1:4040 from $WEB_DIR: index.html (the page) and server.py (a stdlib-only Python
# backend). Both live in src/web/, are embedded into this script by build.sh and rewritten on every start. The page
# shows what the dashboard shows, plus charts from a 24-hour sample history, and can change everything the CLI can: it
# runs nimctl commands (output streamed live) and writes $NIM_DIR/settings, the NIMCTL_* values nimctl reads at start
# (an explicit environment variable still wins). Every API call needs the per-installation token the page carries and
# a Host header naming this machine, so no other site open in the browser can reach it.
T_de+=(
  [k_z]="Web-UI" [h_web]="Web-Oberfläche im Browser (Dashboard, Einstellungen, Statistik): nimctl web [open|start|stop|disable|url|candidates]"
  [web_url]="Web-UI: http://localhost:%s" [web_enabled]="Web-UI aktiviert – nimctl start startet sie mit" [web_disabled]="Web-UI deaktiviert – wieder an: nimctl web"
  [web_no_python]="python3 fehlt – für die Web-UI nötig: %s" [web_local]="nur von diesem Rechner erreichbar; Token in %s"
)
T_en+=(
  [k_z]="Web UI" [h_web]="web UI in the browser (dashboard, settings, statistics): nimctl web [open|start|stop|disable|url|candidates]"
  [web_url]="web UI: http://localhost:%s" [web_enabled]="web UI enabled – nimctl start starts it too" [web_disabled]="web UI disabled – back on: nimctl web"
  [web_no_python]="python3 missing – needed for the web UI: %s" [web_local]="reachable from this machine only; token in %s"
)
web_token() { # one secret per installation; the page carries it, every API call must present it
  local f="$WEB_DIR/token"; [[ -s "$f" ]] || { mkdir -p "$WEB_DIR"; gen_secret >"$f.tmp"; chmod 600 "$f.tmp"; mv "$f.tmp" "$f"; }; cat "$f"
}
web_write_files() { # server.py and index.html from the embedded assets (build.sh), rewritten on every start
  mkdir -p "$WEB_DIR"; chmod 700 "$WEB_DIR"
  web_asset_server_py >"$WEB_DIR/server.py.tmp" && mv "$WEB_DIR/server.py.tmp" "$WEB_DIR/server.py" || return 1
  web_asset_index_html >"$WEB_DIR/index.html.tmp" && mv "$WEB_DIR/index.html.tmp" "$WEB_DIR/index.html" || return 1
  web_token >/dev/null
}
web_env() { # what server.py needs: where nimctl and its data are, the port, the language, the settings the UI may write
  local bin; bin=$(realpath_ "$0")
  export NIMCTL_HOME="$NIM_DIR" NIMCTL_WEB_BIN="$bin" NIMCTL_WEB_PORT="$WEB_PORT" NIMCTL_BIND="$BIND" NIMCTL_LANG="$L" NIMCTL_WEB_KEYS="$SETTINGS_KEYS"
}
web_enable() { [[ "$WEB_ENABLED" == 1 ]] || { WEB_ENABLED=1; save_conf; }; ok "$(t web_enabled)"; }
web_ensure() { # python present, files written, server up – and only then enabled for start/stop/restart and systemd
  has python3 || { bad "$(tf web_no_python "$(pkg_hint python3)")"; return 1; }
  svc_running web || start_web || return 1
  [[ "$WEB_ENABLED" == 1 ]] || web_enable
}
web_open() { web_ensure || return 1; ok "$(tf web_url "$WEB_PORT")"; info "$(tf web_local "$WEB_DIR/token")"; open_url "http://localhost:$WEB_PORT" || info "→ http://localhost:$WEB_PORT"; }
web_disable() { # stop it, take it out of start/stop/restart and systemd; the files stay
  if has systemctl && [[ -f "$(unit_dir)/nimctl-web.service" ]]; then systemctl --user disable --now nimctl-web 2>/dev/null; rm -f "$(unit_dir)/nimctl-web.service"; systemctl --user daemon-reload 2>/dev/null; fi
  stop_svc web; WEB_ENABLED=0; save_conf; ok "$(t web_disabled)"
}
web_candidates_json() { # the effective candidate patterns (the ranking) per slot, for the UI's editor
  local j="{}" s v
  for s in "${SLOTS[@]}"; do v=$(candidates "$s" | tr '\n' ' '); j=$(jq -n --argjson a "$j" --arg k "$s" --arg v "${v% }" '$a + {($k): $v}'); done
  printf '%s\n' "$j"
}
cmd_web() { # cmd_web [open|start|stop|disable|url|candidates]
  local sub="${1:-open}"
  case "$sub" in
    open)       web_open;;
    start)      web_ensure || return 1; ok "$(tf web_url "$WEB_PORT")";;
    stop)       stop_svc web;;
    disable)    web_disable;;
    url)        printf 'http://localhost:%s\n' "$WEB_PORT";;
    candidates) web_candidates_json;;
    *)          bad "$(t invalid): $sub"; return 64;;
  esac
}
dash_register z cmd_web k_z use
