# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [1.5.0] – 2026-09-18

### Added
- **Rate limiting**: a LiteLLM pre-call hook (`~/.nimctl/nimctl_hooks.py`, registered as `callbacks` in the generated
  config) keeps one token bucket of `NIMCTL_RPM` requests per minute (36) for everything that goes through the proxy.
  Requests beyond the budget wait for the next free slot instead of failing; after `NIMCTL_RPM_MAX_WAIT` seconds (30)
  the proxy answers 429 with `Retry-After`. An upstream 429 shrinks the budget by a fifth for five minutes, then it
  grows back. State in `~/.nimctl/rpm.json`: the dashboard shows a budget line, `nimctl stats` counts throttled
  requests (`throttled` in `--json`).

### Changed
- The chat talks to the proxy by default (`NIMCTL_CHAT_VIA_PROXY=1`), so it shares the budget, retries and fallbacks;
  `NIMCTL_CHAT_VIA_PROXY=0` restores the direct connection.
- `NIMCTL_RPM` no longer sets LiteLLM's per-deployment `rpm` (which refused requests); it is the budget above.

### Fixed
- Without a `review` model the generated LiteLLM config was invalid YAML (a `}` inside a `${var:+…}` expansion ended
  the expansion early), so the proxy failed to start. Found by running the real proxy against the test mock.

## [1.4.0] – 2026-09-18

### Added
- **Web search**: `nimctl search` installs [SearXNG](https://docs.searxng.org) as a local service (git clone into
  `~/.nimctl/searxng`, venv built with `uv`, loopback only, JSON format on, bot limiter and Valkey off) and wires it
  into Open WebUI through its start environment (`ENABLE_WEB_SEARCH`, `WEB_SEARCH_ENGINE=searxng`, `SEARXNG_QUERY_URL`,
  pages bypass the embedding step). `nimctl search "query"` searches from the terminal, `install|start|stop|disable|test`
  manage it, `nimctl start|stop|restart`, the systemd units, `status`, `status --json`, `doctor` and the dashboard
  (key `o`) know the service. The wizard offers it. `NIMCTL_SEARCH_PORT` (8888), `NIMCTL_SEARCH_RESULTS` (5).
- The IDE's MCP server gains a `web_search` tool on the same SearXNG, and the Continue rule mentions it.

## [1.3.0] – 2026-09-15

### Added
- **IDE agent mode works out of the box**: `nimctl ide` writes a shell tool for Continue (`~/.nimctl/mcp/shell.py`, an
  MCP server whose `run` tool returns exit code and output – Continue's own terminal tool returns nothing inside
  code-server), registers it with a rule in `~/.continue/config.yaml`, prepares the Python package `mcp` with `uv`, writes
  code-server user settings once (no welcome page, bash terminal, telemetry off) and starts code-server with workspace
  trust disabled. One click remains per browser: Continue's tool policy for `run`, which the browser stores.
- `nimctl ide <folder>` and `nimctl ide open <folder>` open the folder in the IDE and make it the shell tool's working
  directory; without an argument the git project in the current directory is used, otherwise the last folder.

## [1.2.0] – 2026-09-14

### Added
- **Browser IDE**: `nimctl ide` installs code-server (VS Code in the browser, standalone into `~/.local`) with the
  Continue extension from Open VSX, writes `~/.continue/config.yaml` with the `code`, `fast` and `review` slots on the
  proxy, generates a password, binds to `127.0.0.1:8080` (`NIMCTL_IDE_PORT`) and opens the browser. `nimctl ide
  password [--reset]`, `nimctl ide config [--force]` (a foreign Continue config is never overwritten without
  `--force`), `nimctl ide autocomplete on|off` (off by default: autocomplete would burn the free tier's requests per
  minute), `nimctl ide install`, `nimctl ide start|stop|disable`, `nimctl logs ide`. Dashboard key `v`, IDE row, `status --json` block, third
  systemd unit `nimctl-ide`, `nimctl start|stop|restart` include the IDE once it is enabled. The wizard offers it.
- `NIMCTL_IDE_EXTENSIONS` installs additional Open VSX extensions (e.g. `RooVeterinaryInc.roo-cline`),
  `NIMCTL_IDE_CONTEXT` sets the context length Continue assumes for the models.
- Release workflow (`.github/workflows/release.yml`): a tag push or a manual run publishes the GitHub release with
  `nimctl` and `SHA256SUMS` attached and the changelog section as notes.

## [1.1.0] – 2026-09-14

### Added
- **New dashboard**: single-key navigation (no Enter), grouped key bar, a "last action" panel that keeps the result
  of the previous action on screen, notices (configuration changed → restart, key expiry, failed systemd units),
  `?` for in-dashboard help, four model slots, probe age per slot, automatic re-probe when the last probe is older than
  `NIMCTL_REPROBE_HOURS` (6). Width-aware layout, distinct glyphs (`✓ ✗ ! ·`) that stay readable without colour,
  ASCII fallback without UTF-8, `NO_COLOR` honoured.
- **Tool-calling probe**: models for the `code` and `review` slots must answer a function-calling request; models
  that only answer in prose are skipped (Claude Code cannot work with them). `find`, `check` and the dashboard show it.
- **`review` slot** (big, slow model) for `nimctl code --model review`; candidates and selection like the other slots.
- `nimctl code --model <slot|id>`, `--think` (re-enables extended thinking), `.nimctl` project profiles
  (`MODEL=`, `THINK=`, `MAX_OUTPUT_TOKENS=`), a warning when started in `$HOME`. Every model that answered a probe is
  reachable through the proxy by its own id, so switching models needs no restart.
- `nimctl env`: export lines for other tools (`eval "$(nimctl env)"` → Aider, Continue, Zed, OpenAI SDK).
- `nimctl stats`: requests, status classes, rate limits and fallbacks from the proxy log; one summary line in the dashboard.
- `nimctl bench`: time to first token, tokens/s and tool-calling per model from a streamed request.
- `nimctl chat users | passwd [email] | reset`: manage Open WebUI accounts from the CLI, including resetting the
  admin password or wiping all accounts so the next signup becomes admin. Dashboard key `n`.
- `nimctl watch`: probes the slots, replaces dead models, restarts the proxy, logs and notifies; the wizard offers the
  hourly `systemd --user` timer for it, `nimctl install` can add it later.
- `nimctl completion bash|zsh`, installable from the install menu.
- `nimctl status --json` and documented exit codes (0 ok, 1 key, 2 proxy down, 3 prerequisite, 4 dead model, 64 usage error);
  `nimctl doctor --fix`; `nimctl setup --yes` with `NIMCTL_API_KEY` for unattended setups; `nimctl key <key>`;
  `nimctl pick <slot> [search]`; `nimctl auto [slot…]`; `nimctl logs [proxy|chat|watch] [-f]`; `nimctl models`;
  `nimctl help <command>`; `--lang de|en`.
- Key expiry warning (NVIDIA keys last ~6 months; the date of entry is recorded).
- `nimctl update` compares versions, shows the changelog excerpt, verifies `SHA256SUMS`, keeps a `.bak`; `--check`.
- Candidate lists can be overridden with `NIMCTL_CAND_<SLOT>` or `~/.nimctl/candidates`.
- `NIMCTL_CHAT_VIA_PROXY=1` routes Open WebUI through the LiteLLM proxy (retries, fallbacks, curated model list).
- Optional `NIMCTL_RPM` per-deployment rate limit in the generated LiteLLM config.
- Package-manager detection (apt, dnf, pacman, apk, brew) and browser detection (xdg-open, WSL, macOS).
- Test suite restructured into `tests/cases/`, mock API with tool calls and streaming, tests for config injection,
  stale pid files, foreign listeners, headless setup, self-update, installer and every fixed bug below.

### Changed
- Sources now live in `src/*.sh`; `build.sh` produces the single-file `nimctl` and `SHA256SUMS` (both committed).
  CI fails on a stale build, a missing changelog entry for `VERSION`, or a placeholder URL.
- Minimum bash version is 4.4.
- The date in the banner is ISO (`YYYY-MM-DD`), the masked key shows its last four characters.
- The dashboard restart question requires an explicit yes; unattended runs never restart or install anything
  unless `--yes` / `NIMCTL_YES=1` is given. `--yes` answers every question with yes, in a terminal as well.
- The default UI language is English; German only when `LANG`/`NIMCTL_LANG` starts with `de`.

### Fixed
- Repository URL placeholders (`YOUR-GITHUB-USER`) that broke `nimctl update`, the install one-liner and the CI badge.
- The wizard spun at 100 % CPU when stdin was closed (containers, CI, `curl | bash` without a terminal).
- `Ctrl+C` in the log view ended nimctl instead of returning to the dashboard.
- Read-only commands (`status`, `check`, …) could start `sudo apt-get` when `jq` was missing.
- `nimctl auto` from the command line left a running proxy on the previous models without any hint.
- `nimctl test` measured latency in whole seconds and, on failure, fired a second request whose success could be
  stored as the error text "ok 123".
- Browser opening on WSL2 and macOS.
- Re-entering the same API key no longer wipes the probe cache; invalid menu input is reported instead of ignored;
  unconfigured slots are reported instead of probing a model named "x"; doctor summarises the issues before asking.
- The catalog cache is used when a refresh fails instead of aborting model selection.
- systemd units start with the same checks as `nimctl start` and have a restart limit; restarts of systemd-managed
  services stay under systemd.

### Security
- The LiteLLM master key is generated per installation (was the same public string everywhere); proxy and chat
  bind to `127.0.0.1` (`NIMCTL_BIND` to change).
- The API key is passed to curl through a private config file, never on the command line.
- `~/.nimctl/config` is parsed, not sourced; model ids from the catalog are validated before they reach the config,
  the LiteLLM YAML or the probe file. The data directory is `chmod 700`, the generated YAML `600`.
- Processes are identified before they are signalled; stale pid files are discarded; foreign listeners on the ports
  are reported, never killed.
- Self-update verifies the download against `SHA256SUMS`.

## [1.0.6] – 2026-09-14

(1.0.7 and 1.0.8 were internal builds without a changelog entry.)

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
