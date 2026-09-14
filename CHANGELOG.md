# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [1.0.6] – 2026-09-14

### Fixed
- `400 Unsupported parameter(s): prompt_cache_key` from NVIDIA: LiteLLM adds OpenAI-only parameters while
  translating Claude Code requests. The generated config now drops them per deployment
  (`additional_drop_params`). Removed `DISABLE_PROMPT_CACHING` (noise; cache blocks are dropped anyway).
- `nimctl proxy` tools check now sends session metadata like Claude Code, so this class of error is caught.

## [1.0.5] – 2026-09-14

### Fixed
- Claude Code got `404 page not found` from the proxy for every request: LiteLLM routes Anthropic-format
  requests for `openai/` deployments through OpenAI's Responses API, which NVIDIA does not serve. The
  generated config now uses the `custom_openai/` prefix, which translates via `/chat/completions`.
  Override with `NIMCTL_PROVIDER` (e.g. `hosted_vllm`) for older LiteLLM versions.

## [1.0.4] – 2026-09-14

### Fixed
- `nimctl code` now disables extended thinking and prompt caching and caps output tokens at 8192
  (`NIMCTL_MAX_OUTPUT_TOKENS` to change) – open models behind an OpenAI-compatible endpoint reject
  these Anthropic-only request features with HTTP 400, which Claude Code reports as "issue with the model".

### Added
- `nimctl proxy` additionally sends a request with a tool definition and system prompt to `nim-code`,
  the shape Claude Code actually uses.

## [1.0.3] – 2026-09-14

### Added
- `nimctl proxy`: sends an Anthropic-format request through the LiteLLM proxy for each slot – the exact
  path Claude Code uses – and prints the real error text if it fails.
- `nimctl code` runs that round-trip before launching Claude Code, so "There's an issue with the selected
  model" becomes a readable error instead. `nimctl doctor` includes it too.

## [1.0.2] – 2026-09-14

### Fixed
- Claude Code showed `429 No deployments available for selected model … cooldown_list` after a single slow
  or rate-limited NVIDIA response: LiteLLM's default cooldown removed the only deployment of a slot for 60 s.
  Cooldowns are now disabled; the proxy retries with backoff and falls back to the `fast` model instead.

## [1.0.1] – 2026-09-14

### Fixed
- A model that answered in one slot could later be shown as "timeout" after being re-probed under load for
  another slot. Probe results are now cached per run; a successful result is never downgraded within a run.
- The top-priority candidate (e.g. deepseek-v4-pro) got a single attempt and lost to weaker models on a
  cold start. It now gets a second attempt with double timeout before the next pattern is considered.
- `ResourceExhausted … request limit reached` from NVIDIA is shown as "overloaded (worker limit)".

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
