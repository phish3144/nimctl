# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [1.10.0] – 2026-09-19

### Added
- **`nimctl scan [provider…|all] [--sizes] [--use|--clear]`**: probes every chat model of every provider with a key –
  NVIDIA and the pool – at the pace each free tier tolerates (`NIMCTL_SCAN_RPM` overrides: NVIDIA 30, Groq 25,
  Gemini 8, Cerebras 25, OpenRouter 15, Mistral 40 requests/min; embeddings, rerankers, guards, speech and image
  entries are skipped), then tool calling for the responders and, with `--sizes`, the request sizes. One table per
  provider, results in `~/.nimctl/probes` for the dashboard, `find`, the web UI catalog and the next `auto`. Models
  that qualify for a slot (tool calling where needed, no models below 30B for `code`/`review`) but that no ranking
  names are listed; `--use` appends them to the slot's ranking (`~/.nimctl/discovered`, after the patterns) and
  rebuilds the chains, `--clear` removes them. OpenRouter is scanned only when named (50 requests a day). Web UI:
  scan buttons on the models and pool pages.

### Changed
- **Every provider with a key gets its ranks.** The chain is filled in two passes: at most `NIMCTL_CHAIN_PER_PROVIDER`
  ranks (2) per provider first, in ranking order, then the ranks skipped for that. Mistral, OpenRouter and Cerebras
  used to sit behind NVIDIA's third and fourth model and never made it into a chain of six; now NVIDIA's third-best
  comes after the other providers' best, and a provider that is down as a whole costs one or two ranks. Chains have
  8 ranks by default (`NIMCTL_CHAIN_LEN`), the setting is on the web UI's Settings page.

## [1.9.0] – 2026-09-19

### Fixed
- **The chat talked to NVIDIA directly and searched through a public SearXNG.** Open WebUI keeps its connection,
  default model and web-search settings in its database once it has started; the environment only seeds them.
  Installations set up before 1.1.0 (chat straight to NVIDIA) or with another search URL saved never reached the
  chain: `Service temporarily overloaded` came straight from NVIDIA, the search got HTML instead of JSON. nimctl now
  aligns the connection (URL and key), the default model (`nim-chat`) and the search engine and URL in Open WebUI's
  database before every chat start and when the search is switched on – both storage schemas, other connections and
  settings untouched, printed when something changed (this replaces 1.8.1's search-only sync and carries its result
  count, concurrency, bypass and confirmation settings). `nimctl doctor` reports a chat that still talks past the proxy,
  `--fix` restarts it.
- **Groq ranked first for `code` and rejected every request.** Groq's free tier caps a single request at its per-minute
  token limit (6–12k tokens); a Claude Code request carries 20k+. Every rank now has to take a request of the slot's
  size before it enters the chain – `code`/`review` 32k tokens, `fast` 12k, `chat` 8k – sent once per model and size
  by `nimctl auto` and kept for a day in `~/.nimctl/sizes`; probe rows and the web UI show `32k ✓`/`✗` with the
  provider's reason. Groq is a chat candidate only, a model with a small context window drops out the same way, and
  `nimctl pick` warns. A rank that still fails with `Request too large` pauses for 30 minutes instead of 2; the proxy
  log line carries the provider's message.
- `nimctl search install` on an existing installation skipped the dependency update after `git pull` when `uv venv`
  refused the existing environment; the environment is now kept and updated in place (1.8.1 recreated it with
  `--clear`). SearXNG's version is frozen at install time (no `not a git repository` errors at start) and the limiter
  config file exists (no warning).
- A tool-calling check that failed for a transient reason (timeout, 429) marked the model `no tool calls` for good.
  It is retried once with double timeout and otherwise left undecided for this run.

### Changed
- Rankings: `deepseek-v4-pro` and NVIDIA's `kimi-k2` lead `code`; Gemini Flash, Groq's `kimi-k2` and `llama-3.3-70b`
  and Cerebras lead `chat` ahead of `nemotron-3-super`; Groq is gone from `code`, `fast` and `review`.
- The web UI's Settings page has `NIMCTL_COOLDOWN_RATELIMIT` and `NIMCTL_SEARCH_CONCURRENT`.

## [1.8.2] – 2026-09-19

### Changed
- **Stronger out-of-the-box defaults** (every install, not only local tweaks):
  - Web search: `NIMCTL_SEARCH_RESULTS` default **10**, concurrent requests **8** (`NIMCTL_SEARCH_CONCURRENT`); Open WebUI DB sync also sets result count, concurrency, bypass-embedding, and turns search confirmation **off**.
  - SearXNG outgoing timeouts **10 s / 20 s** (was 6 / 15).
  - Proxy: `NIMCTL_RPM` **40**, `NIMCTL_RPM_MAX_WAIT` **45**, stall timeout **120 s**, cooldown **90 s**, rate-limit cooldown **15 s**.
  - Chat deployments and Claude Code: default `NIMCTL_MAX_OUTPUT_TOKENS` **16384** so reasoning models are less likely to return empty `finish_reason: length` answers.
- `NIMCTL_SEARCH_CONCURRENT` is a first-class settings key (web UI / `~/.nimctl/settings`).

### Notes
- Existing installs pick up the new defaults after `nimctl update` and `nimctl restart` (chat start re-syncs the Open WebUI DB). Values already set in `~/.nimctl/settings` or the environment still win.

## [1.8.1] – 2026-09-19

### Fixed
- **SearXNG reinstall**: `nimctl search install` creates the venv with `uv venv --clear`, so a second install no longer
  fails when `~/.nimctl/searxng/venv` already exists.
- **Open WebUI search URL**: when search is enabled, `start_chat` / `nimctl search start` write the local SearXNG JSON
  URL into `~/.nimctl/webui-data/webui.db` (`web.search.searxng_query_url`, engine `searxng`, enable true). Open WebUI
  prefers the DB over env after the first admin save, so a previously persisted public instance (often HTML/Turnstile)
  no longer overrides the local service.
- **Rate-limit cooldowns**: a `RateLimitError` / 429 starts a short pause (`NIMCTL_COOLDOWN_RATELIMIT`, default 20 s)
  instead of the full `NIMCTL_COOLDOWN` (120 s) used for timeouts and 5xx; still doubles per consecutive failure and is
  registered with LiteLLM's cooldown cache.

### Changed
- **Chat candidate ranking**: `CAND_CHAT` puts Gemini Flash and Groq ahead of `nemotron-3-super` so `nimctl auto` builds
  healthier chat chains when those free tiers are configured (NVIDIA free-tier mid-stream 503s were common with
  nemotron first). Tool-capable rankings for `code` / `review` are unchanged.

### Notes
- Full-page reloads in the **Open WebUI** chat come from Open WebUI's own `/_app/version.json` update checker, not from
  nimctl's web UI (which only soft-refreshes every 5 s). There is no clean env flag to disable that checker; leave it
  alone.

## [1.8.0] – 2026-09-19

### Changed
- **Ranking instead of "NVIDIA first"**: every slot is now a chain of ranks built from one candidate ranking that
  spans NVIDIA and every pool provider with a key (`provider:pattern` names a provider's catalog). The best responder
  is rank 1 – with a Groq key that is `groq:kimi-k2` for `code`, not a fallback behind NVIDIA – and the next ranks
  follow in ranking order, up to `NIMCTL_CHAIN_LEN` (6). Config keys `CHAIN_<SLOT>`; `MODEL_<SLOT>` stays rank 1.
  `nimctl pool add` rebuilds the chains, `nimctl pool` shows each provider's ranks, `pick <slot> <id>` makes a model
  rank 1 and moves the rest down, the dashboard shows `+n fallback` per slot, `status --json` the chains and a
  `health` block. The proxy config has one model group per rank (`nim-<slot>`, `nim-<slot>-r2`, …) with fallbacks
  down the chain; `pool-<slot>` groups and the per-provider `POOL_<PROVIDER>` config are gone.
- **Cooldowns by nimctl's hook**: a rank that fails (stall, 429, 5xx – also mid-stream, where LiteLLM never cools a
  single-deployment group down) is paused for `NIMCTL_COOLDOWN` seconds (120), doubling per consecutive failure up to
  30 minutes, cleared by a success; the hook routes every request to the best rank that is not paused and registers
  the pause with LiteLLM so a running request's fallback chain skips it too. State in `~/.nimctl/health.json`:
  dashboard line `Paused`, web UI notices and chain markers. The request budget counts NVIDIA ranks only.
- Config changes (`key`, `pick`, `auto`, `pool …`) restart the proxy only, no longer every service; commands run
  from the web UI never stop or restart the web UI itself (`nimctl pool add` from the page killed the page).
- Web UI: chains on the slot cards and the overview, ranks per provider on the pool page, paused-rank notices, the
  ranking editor, `NIMCTL_COOLDOWN` and `NIMCTL_CHAIN_LEN` under Settings.

### Fixed
- Adding a provider key from the web UI restarted all services including the web UI's own server.

## [1.7.0] – 2026-09-19

### Added
- **Web UI**: `nimctl web` serves a local cockpit on http://localhost:4040 – overview (key, services, tools, budget
  meter, slots, request rate), models (slot cards with auto/probe/bench/test, catalog with one-click assignment,
  candidate-pattern editor, prompt box, bench results), pool (one card per provider), services (per-service actions,
  IDE folder and autocomplete, chat accounts, systemd autostart, watchdog timer, live log viewer), statistics
  (requests per minute, 429/fallback/throttle events, free budget over time, status classes, top paths, model latency
  and bench – each chart with a table view and a hover readout, 1/6/24 h) and settings (NVIDIA key, budget and stall
  timeout, ports and bind address, probing, IDE and search, language, theme, update and maintenance). The backend
  `~/.nimctl/web/server.py` uses the Python standard library only and is embedded in the script together with the
  page; every API call needs the per-installation token and a `Host` header naming this machine; commands stream
  their output as server-sent events; keys and passwords go in through stdin or the environment. New service `web`
  (dashboard row, key `z`, `status --json`, doctor, systemd unit, wizard question), `NIMCTL_WEB_PORT` (4040).
- `~/.nimctl/settings`: `NIMCTL_*` values chosen in the web UI, read at start; a variable set in the environment wins.
- `nimctl pick <slot> <exact id>` sets the slot directly, also to a pool model's `provider:id`;
  `nimctl install nosystemd` removes the autostart units; `nimctl logs web`.

## [1.6.0] – 2026-09-18

### Added
- **Provider pool**: `nimctl pool add <provider> <key>` adds Groq, Google AI Studio, Cerebras, OpenRouter (`:free`
  models) or Mistral as a fallback behind NVIDIA. The key is checked at the provider and stored in `~/.nimctl/config`,
  one model per slot is picked from the provider's catalog with the same probe NVIDIA gets (ids namespaced
  `<provider>:<id>` in `probes`, catalogs cached in `models.<provider>.cache`), and the proxy config gets `pool-<slot>`
  deployments (providers in a fixed order, a failing one cools down for 30 s) as the fallback of `nim-<slot>`. Pool
  models are also reachable by their namespaced id (`nimctl code --model groq:openai/gpt-oss-120b`, `nimctl test
  cerebras:gpt-oss-120b`). Dashboard row `Pool` (key `m`), `pool` in `nimctl status --json`, `nimctl doctor` checks
  keys and chosen models, the wizard offers the pool after the key step and takes keys from the environment
  (`GROQ_API_KEY`, `GEMINI_API_KEY`, `CEREBRAS_API_KEY`, `OPENROUTER_API_KEY`, `MISTRAL_API_KEY`) in unattended
  setups. Candidate patterns per provider: `NIMCTL_CAND_<PROVIDER>_<SLOT>` or `groq.code: …` in `~/.nimctl/candidates`.
- `NIMCTL_STALL_TIMEOUT` (90): a model that sends nothing for this long (the next byte of a stream, a whole non-streamed
  answer) is given up and the request handed to the fallback. Set as `timeout` on every deployment, the only place
  LiteLLM honours it on the Anthropic route Claude Code uses (`router_settings.stream_timeout` is ignored there).

### Changed
- With a pool the proxy no longer retries a stalled or failed request on the same NVIDIA model: a stall, 429 or 5xx
  goes to `pool-<slot>` at once (LiteLLM `retry_policy`), deployments that fail are cooled down for 30 s.
  Without a pool the previous settings stay (no cooldowns, four retries), plus the stream timeout.

### Fixed
- Streams that stalled before the first token (`Timeout on reading data from socket` in the proxy log, seen as
  aborted answers in Claude Code, the IDE and the chat) waited for LiteLLM's five-minute request timeout before the
  fast model took over; the handover now happens after `NIMCTL_STALL_TIMEOUT` seconds.

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
