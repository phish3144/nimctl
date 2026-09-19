#!/usr/bin/env bash
# Builds ./nimctl (one self-contained file) from src/*.sh, concatenated in filename order,
# and refreshes SHA256SUMS (verified by `nimctl update`). Run after every change in src/.
set -euo pipefail
cd "$(dirname "$0")"
out="nimctl.build.tmp"
{
  cat src/00-header.sh
  for f in src/*.sh; do [[ "$f" == src/00-header.sh ]] && continue; printf '\n# ══════ %s ══════\n' "${f#src/}"; cat "$f"; done
  # web UI assets: each file in src/web/ becomes a function web_asset_<name> that prints it (a quoted heredoc, nothing expands)
  for a in src/web/*; do [[ -f "$a" ]] || continue
    n=$(basename "$a"); fn="web_asset_${n//[.-]/_}"; d="ASSET_EOF_${n//[.-]/_}"
    grep -qxF "$d" "$a" && { echo "build: $a contains the heredoc delimiter $d" >&2; exit 1; }
    printf '\n# ══════ %s (embedded) ══════\n' "$a"
    printf "%s() { cat <<'%s'\n" "$fn" "$d"
    cat "$a"; [[ -n "$(tail -c1 "$a")" ]] && echo
    printf '%s\n}\n' "$d"
  done
  printf '\n[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"\n'
} >"$out"
bash -n "$out"
mv "$out" nimctl; chmod +x nimctl
sha256sum nimctl >SHA256SUMS
printf 'built nimctl %s (%s lines)\n' "$(grep -m1 '^VERSION=' nimctl | cut -d'"' -f2)" "$(wc -l <nimctl)"
