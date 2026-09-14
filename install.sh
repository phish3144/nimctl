#!/usr/bin/env bash
# nimctl installer – https://github.com/phish3144/nimctl
#   curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
set -euo pipefail
REPO="${NIMCTL_REPO:-phish3144/nimctl}"
BIN="$HOME/.local/bin"; mkdir -p "$BIN"
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/nimctl" ]]; then
  cp "$(dirname "${BASH_SOURCE[0]}")/nimctl" "$BIN/nimctl"            # local clone
else
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/nimctl" -o "$BIN/nimctl"
fi
chmod +x "$BIN/nimctl"
case ":$PATH:" in *":$BIN:"*) ;; *)
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"; export PATH="$BIN:$PATH"
  echo "→ added ~/.local/bin to PATH (in ~/.bashrc)";;
esac
if ! command -v jq >/dev/null || ! command -v curl >/dev/null; then
  echo "→ installing jq/curl (sudo)"; sudo apt-get install -y jq curl bc
fi
echo "✓ nimctl installed: $BIN/nimctl"
if [[ -t 0 ]]; then exec "$BIN/nimctl" setup; else exec "$BIN/nimctl" setup </dev/tty; fi
