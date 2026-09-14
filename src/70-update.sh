# ── Self update ───────────────────────────────────────────────────────────────
T_de+=(
  [update_ok]="nimctl aktualisiert: %s → %s" [update_fail]="Update fehlgeschlagen (%s)" [update_current]="nimctl %s ist aktuell" [update_avail]="Update verfügbar: %s → %s"
  [update_newer]="lokale Version %s ist neuer als %s auf GitHub – nichts zu tun" [update_q]="Jetzt aktualisieren?" [update_backup]="Vorherige Version: %s"
  [update_sum_ok]="Prüfsumme stimmt" [update_sum_bad]="Prüfsumme stimmt nicht – Download verworfen" [update_sum_none]="keine SHA256SUMS auf GitHub – Prüfsumme nicht verifiziert" [update_changes]="Änderungen:"
)
T_en+=(
  [update_ok]="nimctl updated: %s → %s" [update_fail]="update failed (%s)" [update_current]="nimctl %s is up to date" [update_avail]="update available: %s → %s"
  [update_newer]="local version %s is newer than %s on GitHub – nothing to do" [update_q]="Update now?" [update_backup]="previous version: %s"
  [update_sum_ok]="checksum matches" [update_sum_bad]="checksum mismatch – download discarded" [update_sum_none]="no SHA256SUMS on GitHub – checksum not verified" [update_changes]="Changes:"
)
sha256() { if has sha256sum; then sha256sum "$1" | cut -d' ' -f1; elif has shasum; then shasum -a 256 "$1" | cut -d' ' -f1; else echo ""; fi; }
newest_version() { printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1; }
changelog_between() { # changelog_between <text> <from-version> <to-version> → entries newer than <from>, up to <to>
  awk -v from="$2" -v to="$3" '/^## \[/{ v=$0; sub(/^## \[/,"",v); sub(/\].*/,"",v); if (v==from) exit; p=1 } p' <<<"$1"
}
self_update() { # self_update [--check]
  local self tmp remote base="${NIMCTL_UPDATE_URL:-https://raw.githubusercontent.com/$NIMCTL_REPO/main}"
  self=$(realpath_ "$0"); tmp="$TMP_ROOT/nimctl.new"
  curl -fsSL -m 60 "$base/nimctl" -o "$tmp" || { bad "$(tf update_fail "$base/nimctl")"; return 1; }
  remote=$(grep -m1 '^VERSION=' "$tmp" | cut -d'"' -f2); [[ "$remote" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] || { bad "$(tf update_fail VERSION)"; return 1; }
  [[ "$remote" == "$VERSION" ]] && { ok "$(tf update_current "$VERSION")"; return 0; }
  [[ "$(newest_version "$VERSION" "$remote")" == "$VERSION" ]] && { info "$(tf update_newer "$VERSION" "$remote")"; return 0; }
  warn "$(tf update_avail "$VERSION" "$remote")"
  local cl; if cl=$(curl -fsSL -m 30 "$base/CHANGELOG.md" 2>/dev/null); then info "$(t update_changes)"; changelog_between "$cl" "$VERSION" "$remote" | sed 's/^/    /'; fi
  [[ "${1:-}" == --check ]] && return 0
  local sums expected actual
  if sums=$(curl -fsSL -m 30 "$base/SHA256SUMS" 2>/dev/null); then
    expected=$(echo "$sums" | awk '$2=="nimctl"{print $1}'); actual=$(sha256 "$tmp")
    [[ -n "$expected" && "$expected" == "$actual" ]] && ok "$(t update_sum_ok)" || { bad "$(t update_sum_bad)"; return 1; }
  else warn "$(t update_sum_none)"; fi
  bash -n "$tmp" || { bad "$(tf update_fail "bash -n")"; return 1; }
  ask "$(t update_q)" y || return 0
  cp -p "$self" "$self.bak" 2>/dev/null; chmod +x "$tmp"; mv "$tmp" "$self" || { bad "$(tf update_fail "$self")"; return 1; }
  ok "$(tf update_ok "$VERSION" "$remote")"; info "$(tf update_backup "$self.bak")"
}
