#!/usr/bin/env bash
# nimctl installer – https://github.com/phish3144/nimctl
#   curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
# Installs ~/.local/bin/nimctl, puts it on PATH (bash and zsh), makes sure curl and jq exist, then starts the wizard.
set -euo pipefail
REPO="${NIMCTL_REPO:-phish3144/nimctl}"
BIN="$HOME/.local/bin"; mkdir -p "$BIN"; orig_path="$PATH"

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
  echo "nimctl needs bash 4.4 or newer (this is $BASH_VERSION). macOS: brew install bash, then run this script with the new bash." >&2; exit 3
fi

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/nimctl" ]]; then
  [[ -L "$BIN/nimctl" ]] && rm -f "$BIN/nimctl"                            # a symlink into a clone would make cp copy the file onto itself
  cp "$(dirname "${BASH_SOURCE[0]}")/nimctl" "$BIN/nimctl"            # local clone
else
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/nimctl" -o "$BIN/nimctl.tmp"
  if sums=$(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/SHA256SUMS" 2>/dev/null); then
    expected=$(echo "$sums" | awk '$2=="nimctl"{print $1}')
    actual=$( (sha256sum "$BIN/nimctl.tmp" 2>/dev/null || shasum -a 256 "$BIN/nimctl.tmp") | cut -d' ' -f1)
    [[ -n "$expected" && "$expected" == "$actual" ]] || { echo "✗ checksum mismatch – download discarded" >&2; rm -f "$BIN/nimctl.tmp"; exit 1; }
  fi
  bash -n "$BIN/nimctl.tmp"; mv "$BIN/nimctl.tmp" "$BIN/nimctl"
fi
chmod +x "$BIN/nimctl"

# PATH for bash and zsh, idempotent (checks the rc file, not the current PATH)
line='export PATH="$HOME/.local/bin:$PATH"'; touched=()
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [[ -f "$rc" ]] || { [[ "$rc" == *bashrc ]] || continue; }
  grep -qF '.local/bin' "$rc" 2>/dev/null || { echo "$line" >>"$rc"; touched+=("${rc/#$HOME/~}"); }
done
export PATH="$BIN:$PATH"
((${#touched[@]})) && echo "→ added ~/.local/bin to PATH in ${touched[*]}"

# curl + jq: use the platform's package manager; ask before sudo
if ! command -v jq >/dev/null || ! command -v curl >/dev/null; then
  sudo=""; (( EUID != 0 )) && command -v sudo >/dev/null && sudo="sudo"
  if command -v apt-get >/dev/null; then cmd="$sudo apt-get install -y jq curl"
  elif command -v dnf >/dev/null; then cmd="$sudo dnf install -y jq curl"
  elif command -v pacman >/dev/null; then cmd="$sudo pacman -S --noconfirm jq curl"
  elif command -v apk >/dev/null; then cmd="$sudo apk add jq curl"
  elif command -v brew >/dev/null; then cmd="brew install jq curl"
  else echo "✗ jq/curl missing and no known package manager found – install them, then run: nimctl setup" >&2; exit 3; fi
  echo "→ jq/curl missing – running: $cmd"
  if ( : </dev/tty ) 2>/dev/null; then $cmd </dev/tty; else $cmd; fi
fi
echo "✓ nimctl installed: $BIN/nimctl"

# Wizard: needs a terminal. Under `curl | bash` stdin is the pipe, so use /dev/tty; without any terminal, explain.
if [[ -t 0 ]]; then NIMCTL_PATH_ORIG="$orig_path" exec "$BIN/nimctl" setup
elif ( : </dev/tty ) 2>/dev/null; then NIMCTL_PATH_ORIG="$orig_path" exec "$BIN/nimctl" setup </dev/tty
else echo "→ no terminal: run  nimctl setup  (or  NIMCTL_API_KEY=nvapi-… nimctl setup --yes  for unattended setups)"; fi
