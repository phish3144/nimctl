#!/usr/bin/env bash
# nimctl – NVIDIA NIM for Claude Code and a local chat, without the hassle.
# https://github.com/phish3144/nimctl   ·   MIT License
#
# This file is generated from src/*.sh by build.sh. Edit the sources, then run ./build.sh.
set -u
VERSION="1.8.1"
NIMCTL_REPO="${NIMCTL_REPO:-phish3144/nimctl}"

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
  echo "nimctl needs bash 4.4 or newer (this is bash $BASH_VERSION). On macOS: brew install bash" >&2; exit 3
fi
