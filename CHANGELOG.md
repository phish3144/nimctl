# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [1.0.0] – 2026-09-13

### Added
- Setup wizard: key validation, tool installation, automatic model selection, service start – in one run.
- Automatic model selection per slot (`code`, `fast`, `chat`): candidates are matched against the live
  catalog, probed in parallel with real requests, and the fastest responding one is chosen.
- Single-screen dashboard with live state (key, services, tools, model health with latency).
- `doctor` command that diagnoses and repairs (missing tools, invalid key, dead models).
- `find` to probe any part of the catalog and see what actually answers for your account.
- Claude Code integration via a local LiteLLM proxy (`nimctl code`).
- Browser chat (Open WebUI) with document upload, pointed at NIM (`nimctl chat`).
- Self-update (`nimctl update`), systemd autostart, German and English UI.
- Offline test suite with a mock NIM API (`tests/run.sh`) and GitHub Actions CI.
