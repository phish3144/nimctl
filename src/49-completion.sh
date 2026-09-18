# ── Shell completion ──────────────────────────────────────────────────────────
T_de+=( [completion_usage]="Nutzung: nimctl completion bash|zsh" [completion_installed]="Shell-Completion installiert (~/.bashrc, ~/.zshrc)" [h_completion]="Shell-Completion ausgeben: nimctl completion bash|zsh" )
T_en+=( [completion_usage]="usage: nimctl completion bash|zsh" [completion_installed]="shell completion installed (~/.bashrc, ~/.zshrc)" [h_completion]="print shell completion: nimctl completion bash|zsh" )
_completion_script() { # prints the bash completion function + registration; commands are baked in at generation time
  local cmds fns=(); mapfile -t fns < <(declare -F | awk '{print $3}' | grep '^cmd_' | sed 's/^cmd_//')
  cmds=$(printf '%s\n' "${COMMANDS[@]}" "${fns[@]}" | sort -u | tr '\n' ' ')
  cat <<BASH
_nimctl() {
  local cur prev cmds="$cmds" slots="code fast chat review"
  COMPREPLY=()
  cur="\${COMP_WORDS[COMP_CWORD]}"; prev="\${COMP_WORDS[COMP_CWORD-1]}"
  local home="\${NIMCTL_HOME:-\$HOME/.nimctl}" models=""
  [[ -s "\$home/models.cache" ]] && models=\$(cat "\$home/models.cache")
  if (( COMP_CWORD == 1 )); then COMPREPLY=(\$(compgen -W "\$cmds" -- "\$cur")); return; fi
  case "\${COMP_WORDS[1]}" in
    pick|auto) COMPREPLY=(\$(compgen -W "\$slots" -- "\$cur"));;
    test|bench) COMPREPLY=(\$(compgen -W "\$slots \$models" -- "\$cur"));;
    code) [[ "\$prev" == --model || "\$prev" == -m ]] && COMPREPLY=(\$(compgen -W "\$slots \$models" -- "\$cur"));;
    logs) COMPREPLY=(\$(compgen -W "proxy chat watch ide" -- "\$cur"));;
    pool) COMPREPLY=(\$(compgen -W "add remove auto test models groq gemini cerebras openrouter mistral" -- "\$cur"));;
    chat) COMPREPLY=(\$(compgen -W "open users passwd reset" -- "\$cur"));;
    install) COMPREPLY=(\$(compgen -W "all alias systemd completion" -- "\$cur"));;
    update) COMPREPLY=(\$(compgen -W "--check" -- "\$cur"));;
    doctor) COMPREPLY=(\$(compgen -W "--fix" -- "\$cur"));;
    status) COMPREPLY=(\$(compgen -W "--json" -- "\$cur"));;
    completion) COMPREPLY=(\$(compgen -W "bash zsh" -- "\$cur"));;
  esac
}
complete -F _nimctl nimctl
BASH
}
cmd_completion() { # cmd_completion <bash|zsh>
  case "${1:-}" in
    bash) _completion_script;;
    zsh)  printf 'autoload -U +X bashcompinit && bashcompinit\n'; _completion_script;;
    *) bad "$(t completion_usage)"; return 64;;
  esac
}
inst_completion() {
  local bline='eval "$(nimctl completion bash)"' zline='eval "$(nimctl completion zsh)"'
  grep -qF "$bline" "$HOME/.bashrc" 2>/dev/null || echo "$bline" >>"$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]] && { grep -qF "$zline" "$HOME/.zshrc" 2>/dev/null || echo "$zline" >>"$HOME/.zshrc"; }
  ok "$(t completion_installed)"
}
