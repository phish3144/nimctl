# ── Stats: what is the proxy doing? ──────────────────────────────────────────
# $LOG_DIR/litellm.log is truncated on every proxy start (src/30-services.sh), so every number here is
# "since proxy start". LiteLLM's own log format varies between versions, so parsing is pattern-based and
# defensive rather than tied to one exact layout:
#   (a) uvicorn access lines: INFO:     127.0.0.1:51234 - "POST /v1/messages HTTP/1.1" 200 OK
#   (b) any line mentioning "fallback" (case-insensitive)
#   (c) any line with " 429", "RateLimit" or "rate limit" (case-insensitive)
#   (d) any line containing "Error" or "Traceback"
T_de+=(
  [stats_none]="noch keine Daten – nimctl start" [stats_since]="seit %s" [stats_since_unknown]="unbekannter Zeitpunkt"
  [stats_total]="Anfragen gesamt: %d" [stats_class]="2xx: %d · 4xx: %d · 429: %d · 5xx: %d"
  [stats_fallbacks]="Fallbacks: %d" [stats_ratelimited]="Rate-Limits: %d" [stats_errors]="Fehler: %d" [stats_paths]="Häufigste Pfade:"
  [stats_summary_line]="%s · %d Anfragen · %d× 429 · %d Fallbacks"
  [h_stats]="Auswertung des Proxy-Logs: Anfragen, Status-Codes, Fallbacks, Rate-Limits (--json)"
)
T_en+=(
  [stats_none]="no data yet – nimctl start" [stats_since]="since %s" [stats_since_unknown]="unknown time"
  [stats_total]="requests total: %d" [stats_class]="2xx: %d · 4xx: %d · 429: %d · 5xx: %d"
  [stats_fallbacks]="fallbacks: %d" [stats_ratelimited]="rate-limited: %d" [stats_errors]="errors: %d" [stats_paths]="top paths:"
  [stats_summary_line]="%s · %d requests · %d× 429 · %d fallbacks"
  [h_stats]="proxy log summary: requests, status codes, fallbacks, rate limits (--json)"
)

stats_raw() { # stats_raw <logfile> → one awk pass over the log; TSV: "TOTAL c2 c4 c429 c5 FB RL ERR" then "PATH <path> <count>"
  awk '
    {
      n = split($0, q, "\"")                       # quoted uvicorn access segment: "METHOD PATH HTTP/x.y"
      if (n >= 3 && index(q[2], "HTTP/") > 0) {
        split(q[2], rq, " "); split(q[3], sp, " ")
        path = rq[2]; code = sp[1]
        if (code ~ /^[0-9][0-9][0-9]$/) {
          total++; paths[path]++
          if (code == "429") c429++
          else if (substr(code, 1, 1) == "2") c2++
          else if (substr(code, 1, 1) == "4") c4++
          else if (substr(code, 1, 1) == "5") c5++
        }
      }
      low = tolower($0)
      if (index(low, "fallback") > 0) fb++
      if (index($0, " 429") > 0 || index(low, "ratelimit") > 0 || index(low, "rate limit") > 0) rl++
      if (index($0, "Error") > 0 || index($0, "Traceback") > 0) err++
    }
    END {
      printf "TOTAL\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", total+0, c2+0, c4+0, c429+0, c5+0, fb+0, rl+0, err+0
      for (p in paths) printf "PATH\t%s\t%d\n", p, paths[p]
    }
  ' "$1" 2>/dev/null
}
stats_started() { local s; s=$(cat "$PID_DIR/proxy.started" 2>/dev/null); [[ "$s" =~ ^[0-9]+$ ]] && printf '%s' "$s"; }

stats_summary() { # one fast line for the dashboard; prints nothing when there is no data, never fails
  local log="$LOG_DIR/litellm.log"; [[ -s "$log" ]] || return 0
  local line total c429 fb started since_h
  line=$(stats_raw "$log" | awk -F'\t' '$1=="TOTAL"{print; exit}')
  [[ -n "$line" ]] || return 0
  IFS=$'\t' read -r _ total _ _ c429 _ fb _ _ <<<"$line"
  total="${total:-0}"; c429="${c429:-0}"; fb="${fb:-0}"
  started=$(stats_started); [[ -n "$started" ]] && since_h=$(fmt_time "$started" '+%H:%M') || since_h="$(t stats_since_unknown)"
  tf stats_summary_line "$(tf stats_since "$since_h")" "$total" "$c429" "$fb"
}
cmd_stats() { # cmd_stats [--json] – the global --json flag arrives as $JSON (src/90-main.sh)
  local json="${JSON:-0}" a; for a in "$@"; do [[ "$a" == --json ]] && json=1; done
  local log="$LOG_DIR/litellm.log"
  if [[ ! -s "$log" ]]; then
    if (( json )); then jq -n --arg m "$(t stats_none)" '{data:false,message:$m}'; else sect "$(t k_g)"; info "$(t stats_none)"; fi
    return 0
  fi
  local raw line total c2 c4 c429 c5 fb rl err
  raw=$(stats_raw "$log"); line=$(printf '%s\n' "$raw" | awk -F'\t' '$1=="TOTAL"{print; exit}')
  IFS=$'\t' read -r _ total c2 c4 c429 c5 fb rl err <<<"$line"
  total="${total:-0}"; c2="${c2:-0}"; c4="${c4:-0}"; c429="${c429:-0}"; c5="${c5:-0}"; fb="${fb:-0}"; rl="${rl:-0}"; err="${err:-0}"
  local started since_h=""; started=$(stats_started); [[ -n "$started" ]] && since_h=$(fmt_time "$started" '+%H:%M')
  local top=(); mapfile -t top < <(printf '%s\n' "$raw" | awk -F'\t' '$1=="PATH"{print $2"\t"$3}' | sort -t$'\t' -k2,2nr | head -n5)
  if (( json )); then
    local paths_json="[]"
    if ((${#top[@]})); then
      paths_json=$(printf '%s\n' "${top[@]}" | jq -R -s 'split("\n") | map(select(length>0) | split("\t")) | map({path:.[0], count:(.[1]|tonumber)})')
    fi
    jq -n --arg total "$total" --arg c2 "$c2" --arg c4 "$c4" --arg c429 "$c429" --arg c5 "$c5" \
      --arg fb "$fb" --arg rl "$rl" --arg err "$err" --arg started "$started" --arg since_h "$since_h" --argjson paths "$paths_json" \
      '{requests:{total:($total|tonumber),by_status:{"2xx":($c2|tonumber),"4xx":($c4|tonumber),"429":($c429|tonumber),"5xx":($c5|tonumber)}},
        fallbacks:($fb|tonumber), rate_limited:($rl|tonumber), errors:($err|tonumber), paths:$paths,
        since:(if $started=="" then null else ($started|tonumber) end), since_human:(if $since_h=="" then null else $since_h end)}'
    return 0
  fi
  sect "$(t k_g)"
  out "  $(tf stats_since "${since_h:-$(t stats_since_unknown)}")"
  out "  $(tf stats_total "$total")"
  out "  $(tf stats_class "$c2" "$c4" "$c429" "$c5")"
  out "  $(tf stats_fallbacks "$fb")"
  out "  $(tf stats_ratelimited "$rl")"
  out "  $(tf stats_errors "$err")"
  if ((${#top[@]})); then
    out ""; out "  $(t stats_paths)"
    local row path cnt
    for row in "${top[@]}"; do
      IFS=$'\t' read -r path cnt <<<"$row"
      # $path is attacker-controlled (the raw request path from the uvicorn access log, logged regardless of
      # auth outcome); out() prints via `printf '%b'`, which interprets backslash escapes (a path containing
      # literal "\033[31m" would become a real ANSI escape, and "\c" truncates the line). Escape backslashes
      # and strip raw control bytes before handing it to out() so a crafted path can't inject control codes.
      path=${path//\\/\\\\}
      path=$(printf '%s' "$path" | tr -d '\000-\037\177')
      out "    $(printf '%5d' "$cnt")  $path"
    done
  fi
  return 0
}
dash_register g cmd_stats k_g use
