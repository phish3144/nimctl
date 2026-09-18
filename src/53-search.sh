# ── Web search: a local SearXNG for Open WebUI and the IDE ────────────────────────────────────────────────
# SearXNG is not on PyPI: `nimctl search install` clones it into $SEARX_DIR/src, builds a venv with uv and
# installs it there. Files: $SEARX_DIR/settings.yml (loopback, json format, no limiter), $SEARX_DIR/secret.
# Open WebUI gets the search through its environment (chat_env in src/30-services.sh); the IDE's MCP server
# gets a `web_search` tool (src/52-ide.sh). Service name: search, port $SEARCH_PORT (NIMCTL_SEARCH_PORT).
T_de+=(
  [k_o]="Suche" [h_search]="Websuche (SearXNG) für Chat und IDE: nimctl search [\"Suchbegriff\"|start|stop|disable|install|test]"
  [search_installing]="installiere SearXNG (Git-Klon + Python-Umgebung, ~60 MB) … " [search_enabled]="Websuche aktiviert – im Chat über das Weltkugel-Symbol; nimctl start startet sie mit"
  [search_disabled]="Websuche deaktiviert – start/stop/restart lassen sie aus; wieder an: nimctl search start"
  [search_git_missing]="git fehlt – nötig, um SearXNG zu holen" [search_settings]="SearXNG-Konfiguration: %s" [search_url]="Suche: http://localhost:%s  · nimctl search \"Suchbegriff\""
  [search_none]="keine Treffer" [search_chat_hint]="Chat neu starten, damit die Websuche dort erscheint: nimctl restart"
  [search_persist]="Open WebUI merkt sich Änderungen aus dem Admin-Panel; die Umgebung setzt nur den Anfangswert"
)
T_en+=(
  [k_o]="Search" [h_search]="web search (SearXNG) for the chat and the IDE: nimctl search [\"query\"|start|stop|disable|install|test]"
  [search_installing]="installing SearXNG (git clone + Python environment, ~60 MB) … " [search_enabled]="web search enabled – globe icon in the chat; nimctl start starts it too"
  [search_disabled]="web search disabled – start/stop/restart leave it out; back on: nimctl search start"
  [search_git_missing]="git missing – needed to fetch SearXNG" [search_settings]="SearXNG configuration: %s" [search_url]="search: http://localhost:%s  · nimctl search \"query\""
  [search_none]="no results" [search_chat_hint]="restart the chat so web search shows up there: nimctl restart"
  [search_persist]="Open WebUI remembers changes made in its admin panel; the environment only sets the initial value"
)
search_python() { local p="$SEARX_DIR/venv/bin/python"; [[ -x "$p" ]] && printf '%s' "$p"; }
search_secret() { # one secret per installation, kept out of settings.yml diffs
  local f="$SEARX_DIR/secret"; [[ -s "$f" ]] || { mkdir -p "$SEARX_DIR"; gen_secret >"$f.tmp"; chmod 600 "$f.tmp"; mv "$f.tmp" "$f"; }; cat "$f"
}
search_write_settings() { # settings.yml: loopback only, html+json (Open WebUI needs json), no limiter, no valkey
  mkdir -p "$SEARX_DIR"
  printf 'use_default_settings: true\ngeneral: { debug: false, instance_name: "nimctl search", enable_metrics: false }\nsearch: { formats: [html, json], safe_search: 0 }\nserver: { secret_key: "%s", bind_address: "%s", port: %s, limiter: false, image_proxy: false, public_instance: false }\nvalkey: { url: false }\noutgoing: { request_timeout: 6.0, max_request_timeout: 15.0 }\n' \
    "$(search_secret)" "$BIND" "$SEARCH_PORT" >"$SEARX_DIR/settings.yml.tmp"
  chmod 600 "$SEARX_DIR/settings.yml.tmp"; mv "$SEARX_DIR/settings.yml.tmp" "$SEARX_DIR/settings.yml"
}
inst_searxng() { # git clone (or pull) + uv venv + requirements + editable install; sets SEARCH_ENABLED
  has git || { bad "$(t search_git_missing)"; return 1; }
  declare -F inst_uv >/dev/null && ! has uv && inst_uv; has uv || { bad "$(tf inst_fail uv)"; return 1; }
  local repo="${NIMCTL_SEARXNG_REPO:-https://github.com/searxng/searxng}" log="$LOG_DIR/searxng-install.log" py="$SEARX_DIR/venv/bin/python"
  mkdir -p "$SEARX_DIR"; printf "  %s" "$(t search_installing)"
  if { if [[ -d "$SEARX_DIR/src/.git" ]]; then git -C "$SEARX_DIR/src" pull --ff-only; else git clone --depth 1 "$repo" "$SEARX_DIR/src"; fi &&
       uv venv --python '>=3.11' "$SEARX_DIR/venv" &&
       uv pip install --python "$py" setuptools wheel -r "$SEARX_DIR/src/requirements.txt" &&
       uv pip install --python "$py" --no-build-isolation -e "$SEARX_DIR/src"; } >"$log" 2>&1 && [[ -x "$py" ]]; then printf "%s\n" "$OK"
  else printf "%s\n" "$NO"; bad "$(tf inst_fail SearXNG) → $log"; return 1; fi
  search_write_settings
  [[ "$SEARCH_ENABLED" == 1 ]] || { SEARCH_ENABLED=1; save_conf; svc_running chat && info "$(t search_chat_hint)"; }
  ok "$(t search_enabled)"
}
search_ensure() { # installed, running, enabled
  search_python >/dev/null || { bad "$(tf svc_missing SearXNG)"; info "→ nimctl search install"; return 1; }
  svc_running search || start_search || return 1
  [[ "$SEARCH_ENABLED" == 1 ]] || { SEARCH_ENABLED=1; save_conf; ok "$(t search_enabled)"; svc_running chat && info "$(t search_chat_hint)"; }
}
search_query() { # search_query <query> [count] → title and url per result
  local n="${2:-${NIMCTL_SEARCH_RESULTS:-5}}" out
  out=$(curl -sS -m 25 --get --data-urlencode "q=$1" "http://127.0.0.1:$SEARCH_PORT/search?format=json" | jq -r --argjson n "$n" '.results[:$n][] | "\(.title)\n  \(.url)"' 2>/dev/null)
  [[ -n "$out" ]] && printf '%s\n' "$out" || info "$(t search_none)"
}
search_disable() { # stop it, take it out of start/stop/restart and systemd; installation and settings stay
  if has systemctl && [[ -f "$(unit_dir)/nimctl-search.service" ]]; then systemctl --user disable --now nimctl-search 2>/dev/null; rm -f "$(unit_dir)/nimctl-search.service"; systemctl --user daemon-reload 2>/dev/null; fi
  stop_svc search; SEARCH_ENABLED=0; save_conf; ok "$(t search_disabled)"
}
cmd_search() { # cmd_search ["query"|start|stop|disable|install|test]
  local sub="${1:-start}"; (( $# )) && shift
  case "$sub" in
    install) inst_searxng;;
    start)   search_ensure || return 1; ok "$(tf search_url "$SEARCH_PORT")"; info "$(t search_persist)";;
    stop)    stop_svc search;;
    disable) search_disable;;
    test)    search_ensure || return 1; search_query "nvidia nim" 3;;
    *)       search_ensure >/dev/null || return 1; search_query "$sub${*:+ $*}";;
  esac
}
dash_register o cmd_search k_o use
