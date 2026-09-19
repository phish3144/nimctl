# nimctl

**Claude Code, a browser IDE and a private chat UI on free, frontier-class open models. One command to set up; a watchdog keeps it running as the model catalog changes.**

[![CI](https://github.com/phish3144/nimctl/actions/workflows/ci.yml/badge.svg)](https://github.com/phish3144/nimctl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![free tier](https://img.shields.io/badge/NVIDIA_NIM-free_tier-76B900)
![no credit card](https://img.shields.io/badge/credit_card-not_needed-blue)
![bash](https://img.shields.io/badge/bash-4.4%2B-blue)
![shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen)

NVIDIA hosts 100+ open models on its [NIM API](https://build.nvidia.com) – DeepSeek V4, Nemotron 3, Kimi K3, GLM 5,
Llama 4 – with a free tier: no credit card, no token quota, rate-limited per model. `nimctl` turns that free tier into
a working **Claude Code backend**, **VS Code in the browser with an AI assistant** and a **local chat with document
upload** in a few minutes, then keeps them running while the catalog changes underneath.

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

Then `nimctl code` inside a project, `nimctl ide` for VS Code in the browser, `nimctl chat` for the chat, `nimctl` for the
dashboard. That is the whole workflow.

### The dashboard

```
$ nimctl
 nimctl · NVIDIA NIM 1.7.0                                            2026-09-14 20:15
────────────────────────────────────────────────────────────────────────────────────
  Key      ✓ valid  (nvapi-…k3f9 · checked 20:14 · expires in ~150 days)
  Proxy    ✓ up     :4000  nimctl · pid 41205
  Chat     ✓ up     :3000  systemd
  IDE      ✓ up     :8080  nimctl · pid 41377
  Search   ✓ up     :8888  nimctl · pid 41402
  Web UI   ✓ up     :4040  nimctl · pid 41410
  Tools    ✓ litellm  ✓ open-webui  ✓ claude  ✓ uv  ✓ code-server
  Pool     ✓ Groq (4)  ✓ Cerebras (3)
  Today    since 09:14 · 212 requests · 3× 429 · 9 fallbacks
  Budget   36/min · 29 free · 0 waiting · 7 throttled (avg 1.1 s)

Models
────────────────────────────────────────────────────────────────────────────────────
  1  code    deepseek-ai/deepseek-v4-pro-0813         ✓ responds ·   655 ms · 3 min ago  ✓
  2  fast    deepseek-ai/deepseek-v4-flash-0731       ✓ responds ·    95 ms · 3 min ago  ·
  3  chat    nvidia/nemotron-3-super-120b             ✓ responds ·    92 ms · 3 min ago  ·
  4  review  nvidia/nemotron-3-ultra-550b-a55b        ✓ responds ·  1520 ms · 3 min ago  ✓
  code = Claude Code · fast = side tasks & fallback · chat = browser chat · review = big model for nimctl code --model review

┄┄ Last action ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  ✓ Proxy up  http://localhost:4000
  ✓ Chat up   http://localhost:3000

────────────────────────────────────────────────────────────────────────────────────
  Services s Start  x Stop  r Restart
  Models   a Auto  p Probe  1-4 pick slot  f Find  t Test  b Bench
  Use      c Claude Code  w Chat  e Env  g Stats  m Pool  n Accounts  o Search  v IDE  z Web UI
  System   k Key  d Doctor  i Install  l Logs  u Update  ? Help  q Quit
  ›
```

One key per action, no Enter. The result of the last action stays on screen, notices appear when something needs
you (configuration changed → `r`, key about to expire, a systemd unit failed), `?` explains every key, and
everything is also a command for scripts. Colours are optional: the glyphs `✓ ✗ ! ·` carry the state on their own.

### What you get

- **Claude Code on free models.** `nimctl code` launches Claude Code against a local proxy. Before you type a prompt,
  the model has answered a real request and a real tool call, so "there's an issue with the selected model" becomes a
  readable error instead of a mystery.
- **VS Code in the browser.** `nimctl ide` installs code-server with the Continue extension, preconfigured with the
  `code`, `fast` and `review` models on the proxy: chat, inline edits and agent mode in a full IDE on `localhost:8080`,
  password-protected, no desktop VS Code needed.
- **A private chat UI.** Open WebUI on `localhost:3000` with document upload, pointed at the same models. Lost the admin
  password? `nimctl chat passwd`.
- **Models that keep working.** The catalog lists models that do not answer for every account, get renamed, or vanish
  over night. nimctl matches patterns against the live catalog, probes candidates in parallel with latency measurement
  and requires function calling for the code slots. The wizard offers an hourly watchdog timer that swaps dead models
  out and restarts the proxy (`nimctl watch`, `systemd --user`).
- **One dashboard, one key per action.** Key, proxy, chat, four model slots with latency and age, a request counter,
  notices when something needs you, `?` for help. Every action is also a plain command with exit codes and JSON for scripts.
- **Nothing you have to trust blindly.** One readable bash file, checksummed downloads, services bound to `localhost`,
  a master key generated per installation, the API key never on a command line, config parsed instead of executed.

### Who it is for

Developers who want a **free second lane** next to a Claude subscription for routine work, anyone who wants to try open
models **without a GPU or another API account**, and teams prototyping on NIM before deploying containers.
Not for production backends (the free tier allows roughly 40 requests per minute per model) and not for confidential
customer data (requests go to NVIDIA's US infrastructure, see [FAQ](#faq)).

## Contents

[Why nimctl](#why-nimctl) · [Quick start](#quick-start) · [Commands](#commands) · [Model slots](#the-four-model-slots) ·
[Claude Code](#claude-code) · [Chat accounts](#chat-accounts) · [How it works](#how-it-works) · [Provider pool](#provider-pool) · [Web UI](#web-ui) · [Configuration](#configuration) ·
[Requirements](#requirements-and-compatibility) · [Uninstall](#uninstall) · [What to expect](#claude-code-on-open-models--what-to-expect) ·
[Troubleshooting](#troubleshooting) · [FAQ](#faq) · [Development](#development) · [Deutsch](#deutsch--kurzfassung) · [License](#license)

## Why nimctl

Doing this by hand means a LiteLLM config, an Open WebUI install, five environment variables and a weekly hunt for
models that still answer. The detail behind the bullets above:

| Problem with doing it by hand | What nimctl does |
|---|---|
| Model IDs change (`deepseek-v4-pro` → `deepseek-v4-pro-0813`) | Selection uses **patterns matched against the live catalog**, not hard-coded IDs |
| Claude Code speaks the Anthropic API, NIM speaks OpenAI | A local **LiteLLM proxy** is configured, started and supervised for you; the browser IDE and other tools (`nimctl env`) use the same proxy |
| New flagship models (kimi-k3, nemotron-3-ultra) can take 60 s+ per reply on the free tier | `bench` measures time to first token and tokens/s; the `review` slot keeps the slow giant for when it is worth it |
| Five tools, three config files, env vars in the right places | **One wizard**, one dashboard, one config directory (`~/.nimctl`) |
| "Is it the key, the model, the proxy or the port?" | `nimctl doctor` **diagnoses and repairs**, `nimctl stats` shows what the proxy is doing |

## Quick start

Requires `bash ≥ 4.4`, `curl` and `jq`; the installer adds `jq`/`curl` with your package manager if they are missing
(see [Requirements and compatibility](#requirements-and-compatibility)).

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

The wizard then walks through five steps:

1. **API key** – paste it (input hidden); it is validated against NVIDIA immediately. No key yet? The wizard opens
   <https://build.nvidia.com/settings/api-keys>. Free account, no credit card, SMS verification.
2. **Tools** – installs what is missing: `uv`, `litellm`, `open-webui`, `claude` (Claude Code), and offers the browser IDE
   (`code-server` + Continue, ~150 MB). 2–5 minutes.
3. **Models** – probes all candidates in parallel, checks tool calling for the code models, picks per slot.
4. **Services** – starts the proxy, the chat and the IDE, and offers the hourly watchdog timer (`systemd --user`).
5. **Done** – prints what to type next.

Unattended: `NIMCTL_API_KEY=nvapi-… nimctl setup --yes`.

From then on:

```bash
nimctl            # dashboard
nimctl code       # Claude Code on NIM, run inside a project folder
nimctl ide        # VS Code in the browser, http://localhost:8080
nimctl chat       # opens http://localhost:3000
```

## Commands

| Command | What it does |
|---|---|
| `nimctl` | Dashboard (runs the wizard on first start) |
| `nimctl setup [--yes]` | Re-run the wizard; `--yes` answers every question with its safe default |
| `nimctl start` | Start the proxy (LiteLLM, :4000), the chat (Open WebUI, :3000) and, once enabled, the IDE (code-server, :8080) |
| `nimctl stop` / `nimctl restart` | Stop or restart both services (systemd-managed services stay under systemd) |
| `nimctl status [--json]` | Dashboard once, non-interactive; JSON for scripts; exit code reflects the state |
| `nimctl check` | Probe the configured models with a real request (tool calls for `code`/`review`) |
| `nimctl auto [slot…]` | Re-select models automatically, all slots or e.g. `nimctl auto code` |
| `nimctl pick <slot> [text\|id]` | Set a slot manually from a list, or directly with an exact id (also a pool model's `provider:id`); the pick is probed before it is saved |
| `nimctl find <text>` | Probe every catalog entry matching `<text>` – shows what really answers, and whether it makes tool calls |
| `nimctl test [model\|slot] [prompt]` | Send a prompt, see reply, tokens and time |
| `nimctl bench [--last] [model\|slot…]` | Time to first token, tokens/s and tool calling per model (streamed request) |
| `nimctl proxy` | Anthropic-format round-trip through the proxy for all slots (what Claude Code sees) |
| `nimctl code [--model <slot\|id>] [--think] [args]` | Launch Claude Code against the proxy (`claude` args pass through) |
| `nimctl chat` | Start chat if needed and open it in the browser |
| `nimctl chat users` / `nimctl chat passwd [email] [--admin]` / `nimctl chat reset` | List accounts, reset a password (the admin's, for example), or wipe all accounts so the next signup becomes admin |
| `nimctl accounts` | The same three account actions as an interactive menu (dashboard key `n`) |
| `nimctl ide [folder]` | Start the browser IDE if needed and open it (the folder, else the git project in the current directory, else the last one); `install`, `start`, `stop`, `disable`, `password [--reset]`, `config [--force]`, `autocomplete on\|off` |
| `nimctl search ["query"]` | Local web search (SearXNG) for the chat and the IDE: start it, or search from the terminal; `install`, `start`, `stop`, `disable`, `test` |
| `nimctl pool [add <provider> [key]\|remove <provider>\|auto [provider]\|test\|models <provider>]` | Fallback providers with free quotas (Groq, Google AI Studio, Cerebras, OpenRouter, Mistral): the proxy hands a request to them when NVIDIA fails it |
| `nimctl web` | Web UI in the browser (dashboard, models, pool, services, statistics, settings): start it and open it; `start`, `stop`, `disable`, `url`, `candidates` |
| `nimctl env` | Export lines for other tools: `eval "$(nimctl env)"` |
| `nimctl stats [--json]` | Requests, status classes, rate limits and fallbacks from the proxy log |
| `nimctl watch [--quiet]` | Probe the slots, replace dead models, restart the proxy, log and notify (for timers) |
| `nimctl key [nvapi-…]` | Check or set the API key |
| `nimctl doctor [--fix]` | Diagnose tools, key, network, ports, permissions, models, proxy – repair with `--fix` or on request |
| `nimctl logs [proxy\|chat\|watch\|ide\|web] [-f]` | Show or follow a log |
| `nimctl install [all\|alias\|systemd\|nosystemd\|completion\|watch_timer]` | Tools, PATH, autostart on/off, shell completion, watchdog timer |
| `nimctl update [--check]` | Self-update from this repository with version compare, changelog excerpt and checksum |
| `nimctl models` | Print the catalog, one id per line |
| `nimctl completion bash\|zsh` | Shell completion script |
| `nimctl help [command]` | Help |
| `nimctl version` | Print the version |

Global options: `--yes` (answer every question with yes, including restarts and account resets; unattended runs without
it take the safe default and never change anything), `--lang=de|en`, `--json` (with `status` and `stats`), `NO_COLOR=1`.

Exit codes: `0` ok · `1` key missing/invalid · `2` proxy not running · `3` prerequisite missing · `4` a selected model
does not respond · `64` usage error (unknown command or argument). `status`, `check` and `watch` report the state codes;
`status` combines `1`, `2` and `4` as bit flags, so `nimctl status >/dev/null || alert` works in cron.

## The four model slots

| Slot | Used for | Default candidates (first pattern with a responding model wins) |
|---|---|---|
| `code` | Claude Code main model – must make tool calls | deepseek-v4-pro · laguna-xs · glm-5 · qwen3-coder · kimi-k3 · nemotron-3-ultra · nemotron-3-super |
| `fast` | Claude Code side tasks (`ANTHROPIC_SMALL_FAST_MODEL`) and LiteLLM fallback on 429 | deepseek-v4-flash · nemotron-3.5-lightning · nemotron-3-nano · glm-5.\*flash · nemotron-3-super |
| `chat` | Browser chat default model | nemotron-3-super · nemotron-3-ultra · deepseek-v4-flash · llama-4-maverick · mistral-medium |
| `review` | Big, slow model for `nimctl code --model review` – must make tool calls | nemotron-3-ultra · kimi-k3 · deepseek-v4-pro · glm-5 · nemotron-3-super |

Selection rule: the candidates are case-insensitive regular expressions matched against the catalog (`glm-5.*flash` also
matches `glm-5.3-flash`); they are tried in order; the first pattern that has a responding model (with tool
calling for `code`/`review`) wins, and latency only decides between several matches of the same pattern. Quality
before speed. The top candidate gets a second attempt with double timeout when it only timed out (cold start).

Rationale: NVIDIA's free tier limits **~40 requests/minute per model**, so spreading slots over different models
multiplies your effective throughput. Nemotron is NVIDIA's own model family and the least likely to be throttled or
removed. Override the candidates with `NIMCTL_CAND_CODE="glm-5 deepseek-v4-pro"` or a `~/.nimctl/candidates` file
(`code: glm-5 deepseek-v4-pro`, one line per slot). Pick manually with `1`–`4` in the dashboard or
`nimctl pick code glm`; your pick is probed before it is saved.

## Claude Code

```bash
cd my-project
nimctl code                      # the code slot
nimctl code --model review       # the review slot (big model)
nimctl code --model zai-org/glm-5.3   # any model that answered a probe – no restart needed
nimctl code --think              # re-enable extended thinking (only for models that support it)
```

A `.nimctl` file in the project folder sets defaults for that project:

```
MODEL=review
THINK=1
MAX_OUTPUT_TOKENS=16384
```

Before launching, nimctl sends the exact request shape Claude Code uses through the proxy, so "There's an issue with
the selected model" becomes a readable error. When the proxy hits a 429, LiteLLM automatically falls back from `code`
to `fast`; `nimctl stats` and the dashboard show how often that happens.

Other tools: `eval "$(nimctl env)"` exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `OPENAI_BASE_URL`,
`OPENAI_API_KEY` and the model names, so Aider, Continue, Zed or your own scripts use the same proxy.

## Browser IDE

```bash
nimctl ide ~/src/myproject     # installs on first use (asks), starts code-server, opens the folder at http://localhost:8080
nimctl ide                     # the git project in the current directory, otherwise the last folder
nimctl ide password            # the login password (generated per installation, stored in ~/.nimctl/config)
nimctl ide autocomplete on     # inline completions from the fast model – off by default, see below
```

What you get is VS Code in the browser (code-server, installed standalone into `~/.local`) with the
[Continue](https://continue.dev) extension from Open VSX. nimctl writes Continue's `~/.continue/config.yaml` with the
`code` model for chat, edit and agent mode, the `fast` model for quick questions and the `review` model when one is
configured, all through the local proxy, so a model change in the dashboard reaches the IDE without any clicking.
A Continue config that nimctl did not write is left alone (`nimctl ide config --force` overwrites it).

Agent mode needs a shell, and Continue's own terminal tool returns no output inside code-server. nimctl therefore ships
one: `~/.nimctl/mcp/shell.py`, an MCP server whose `run` tool executes commands in the open project folder and returns
exit code and output. It is registered in the Continue config together with a rule that tells the model to use it, and the
Python package it needs is fetched once with `uv`. One click stays with you, because Continue keeps tool policies in the
browser: gear → Tools → `shell` → `run` → *Automatic* (and `RunTerminalCommand` → *Excluded*). From then on the agent
reads, edits, runs and tests without asking.

Autocomplete is off by default on purpose: inline completions fire on almost every keystroke, and the free tier allows
roughly 40 requests per minute per model. Switch it on when you want it and keep an eye on `nimctl stats`.

The IDE listens on `127.0.0.1:8080` (`NIMCTL_IDE_PORT`) with password login and without the workspace-trust prompt;
`nimctl start`, `stop`, `restart` and the
systemd units include it once it is enabled, `nimctl ide disable` takes it out again (the installation stays, `nimctl ide`
puts it back). More extensions: `NIMCTL_IDE_EXTENSIONS="RooVeterinaryInc.roo-cline" nimctl ide install`.

## Web search

```bash
nimctl search                  # installs on first use (asks), starts SearXNG on http://localhost:8888
nimctl search "nvidia nim"     # search from the terminal
```

The chat can search the web without any cloud search API: nimctl installs [SearXNG](https://docs.searxng.org), a
metasearch engine that queries Brave, Google, DuckDuckGo, Bing, Wikipedia and others, as a local service. It is not on
PyPI, so `nimctl search install` clones it into `~/.nimctl/searxng/src` and builds a venv with `uv` (about 60 MB).
The generated `settings.yml` binds to `127.0.0.1:8888` (`NIMCTL_SEARCH_PORT`), enables the JSON format Open WebUI
needs, and turns the bot limiter off, so no Redis is required.

Open WebUI gets the search through its start environment (`ENABLE_WEB_SEARCH`, `WEB_SEARCH_ENGINE=searxng`,
`SEARXNG_QUERY_URL`, `NIMCTL_SEARCH_RESULTS` results per query). Pages go straight into the model's context instead of
through a local embedding model, which keeps the first search from downloading one. In the chat, the globe icon next
to the message box switches web search on per message. One thing to know: Open WebUI stores settings changed in its
admin panel in its database, and those win over the environment afterwards.

The IDE gets the same search as a `web_search` tool in its MCP server, so Continue's agent can look things up too.
`nimctl start`, `stop`, `restart` and the systemd units include the search once it is enabled; `nimctl search disable`
takes it out again.

## Chat accounts

Open WebUI keeps its own accounts. The first account registered at <http://localhost:3000> becomes admin. If you lose
that password, or want to start over:

```bash
nimctl chat users                  # who is there
nimctl chat passwd                 # new password for the (only) admin – prompts twice, hidden
nimctl chat passwd me@example.com --admin
nimctl chat reset                  # wipe all accounts; the next signup becomes admin again
```

`reset` asks for confirmation and then requires typing `RESET`; `--yes` skips both. Writes stop the chat briefly
(SQLite) and start it again. Unattended: `NIMCTL_CHAT_PASSWORD=… nimctl chat passwd me@example.com --yes`.

## How it works

```
 nimctl code ──► Claude Code ──(Anthropic API)──► LiteLLM proxy 127.0.0.1:4000 ──(OpenAI API)──► integrate.api.nvidia.com
 nimctl ide  ──► code-server 127.0.0.1:8080 + Continue ──(OpenAI API)──► LiteLLM proxy ─────────────────────► integrate.api.nvidia.com
 nimctl chat ──► Open WebUI 127.0.0.1:3000 ───────────────────────────────────────(OpenAI API)──► integrate.api.nvidia.com
                                          (NIMCTL_CHAT_VIA_PROXY=0: directly to NVIDIA instead)
 inside the proxy: nim-<slot> = NVIDIA first ──(no byte for 90 s, 429, 5xx)──► pool-<slot> = Groq · Gemini · Cerebras · OpenRouter · Mistral
 nimctl web  ──► browser 127.0.0.1:4040 ──► web/server.py (Python stdlib) ──► nimctl commands and the files below
```

Everything lives in `~/.nimctl` (mode 700):

```
config          API key, chosen models, extra models added via --model, proxy master key, IDE password, pool keys and models (chmod 600)
state           key state (ok/invalid/offline/none), time of the last check, date the key was entered
settings        NIMCTL_* values chosen in the web UI, read at start (a variable set in the environment wins)
litellm.yaml    generated proxy config – do not edit, use the dashboard
probes          last probe result per model (ok/error, latency, time, tool calling); pool models as <provider>:<id>
bench           bench results
models.cache    catalog snapshot (refreshed hourly, used as fallback when NVIDIA is unreachable)
models.<provider>.cache  catalog snapshot per pool provider
candidates      optional: your own candidate patterns per slot
code-server.yaml  generated code-server config (bind address, password)
ide-data/       code-server user data, settings and extensions (Continue's own config lives in ~/.continue/config.yaml)
mcp/shell.py    shell tool for Continue's agent mode (MCP server, returns command output)
ide-workspace   the project folder the IDE opens and the shell tool runs in
searxng/        SearXNG source, venv and settings.yml (nimctl search)
web/            web UI: index.html, server.py, token, history.json (nimctl web)
logs/           litellm.log, open-webui.log, code-server.log, searxng.log, web.log, watch.log
run/            pid files and start times
webui-data/     chat history, uploaded documents, users
.lock           internal write lock for the probe and bench files
```

Security notes: the proxy's master key is generated per installation and both services listen on `127.0.0.1` only
(`NIMCTL_BIND=0.0.0.0` to expose them deliberately). The API key never appears on a command line. Model ids from the
catalog are validated before they touch any file; the config is parsed, never sourced. `install.sh` and `nimctl update`
verify the downloaded script against `SHA256SUMS` from this repository before installing it. The installer is one short
file; read it before piping it into `bash`.

## Rate limiting

NVIDIA's free tier allows roughly 40 requests per minute per key, across all models, and does not publish the exact
number. Everything that goes through the proxy (Claude Code, the IDE, the chat, the search's query generation) shares
one budget: a LiteLLM pre-call hook nimctl writes to `~/.nimctl/nimctl_hooks.py` keeps a token bucket of `NIMCTL_RPM`
requests per minute (36 by default, leaving room for probes and the watchdog, which talk to NVIDIA directly). A
request that would exceed the budget waits for the next free slot, usually a second or two, instead of failing; only
after `NIMCTL_RPM_MAX_WAIT` seconds does the proxy answer 429 with `Retry-After`, so the clients' own backoff takes
over. If NVIDIA still answers 429, the budget shrinks by a fifth for five minutes and grows back afterwards.

The dashboard shows the budget line (free slots, waiting requests, throttled requests and the average wait),
`nimctl stats` counts throttled requests, and the proxy log carries one `nimctl throttle:` line per wait. The chat
goes through the proxy by default so it is counted too; `NIMCTL_CHAT_VIA_PROXY=0` restores the direct connection.
Requests that end up in the provider pool are counted as well – the budget errs on the safe side.

## Provider pool

NVIDIA's free tier is shared infrastructure: under load a model answers slowly, queues a request for minutes without
sending a byte, or refuses with 429. Retries and the `fast` fallback cover the occasional case, but when the whole
endpoint is busy every slot suffers at once. `nimctl pool add <provider> <key>` puts other free tiers behind it:

| Provider | Free tier (as of 2026-09; unpublished, changes) | Key |
|---|---|---|
| `groq` | ~30 requests/min, ~1,000/day, no card; llama-3.3-70b, gpt-oss-120b, kimi-k2, qwen3-32b | https://console.groq.com/keys |
| `gemini` | 10–15 requests/min, 250–1,000/day; Gemini Flash, Flash-Lite, Pro. Google may train on free-tier data | https://aistudio.google.com/apikey |
| `cerebras` | ~30 requests/min, 1M tokens/day, very fast; gpt-oss-120b, qwen-3-235b, llama-3.3-70b | https://cloud.cerebras.ai |
| `openrouter` | 20 requests/min, 50/day (1,000 with $10 credit); `:free` models only, which may train on your data | https://openrouter.ai/settings/keys |
| `mistral` | experiment tier, ~1 request/s, 1B tokens/month; data may be used for training | https://console.mistral.ai/api-keys |

The key is checked at the provider before it is saved (`~/.nimctl/config`, mode 600, never on a command line). Then
nimctl picks one model per slot from the provider's catalog with the same probe NVIDIA gets – a real request, tool
calling for `code` and `review`, latency – and writes them into the proxy config as `pool-code`, `pool-fast`,
`pool-chat` and `pool-review`. NVIDIA stays first: the proxy sends every request to `nim-<slot>` and only when that
fails (no byte for `NIMCTL_STALL_TIMEOUT` seconds, 429, 5xx) hands it to `pool-<slot>`, where the providers are
tried in the order of the table and one that fails is cooled down for 30 seconds. Nothing goes to a pool provider
while NVIDIA answers, so on a good day your answers do not change – on a bad day you get an answer instead of an
error. The handover only works before the first token: a stream that breaks mid-answer is reported to the client,
which retries by itself (Claude Code does).

Pool models are also reachable by their own id, e.g. `nimctl code --model groq:openai/gpt-oss-120b` or
`nimctl test cerebras:gpt-oss-120b`. `nimctl pool` shows the table with the chosen models, `nimctl pool auto` picks
them again, `nimctl pool test` runs an Anthropic-format round trip through every `pool-<slot>`,
`nimctl pool remove <provider>` takes a provider out. The dashboard has the `Pool` row (key `m`),
`nimctl status --json` a `pool` object, `nimctl doctor` checks keys and models. The setup wizard offers the pool
right after the NVIDIA key; unattended setups take keys from `GROQ_API_KEY`, `GEMINI_API_KEY`, `CEREBRAS_API_KEY`,
`OPENROUTER_API_KEY` and `MISTRAL_API_KEY`. Candidate patterns per provider and slot: `NIMCTL_CAND_<PROVIDER>_<SLOT>`
or a line like `groq.code: gpt-oss-120b llama-3.3-70b` in `~/.nimctl/candidates`.

## Web UI

`nimctl web` opens http://localhost:4040: the dashboard in the browser, with everything the CLI can do and the one
thing a terminal cannot show – charts. Six pages: **Overview** (key, services, tools, budget meter, the four slots
with latency bars, request rate), **Models** (slot cards with auto/probe/bench/test, the catalog with one-click
assignment to a slot – the model is probed first –, the candidate-pattern editor, a prompt box, bench results),
**Pool** (one card per provider: key, chosen models, add/remove/re-select), **Services** (start/stop/restart/install/
disable per service, IDE project folder and autocomplete, chat accounts, systemd autostart and the watchdog timer, a
live log viewer), **Statistics** (requests per minute, 429/fallback/throttle events, free budget over time, status
classes, top paths, model latency and bench charts – each with a table view and a hover readout, 1/6/24 h) and
**Settings** (the NVIDIA key, budget and stall timeout, ports and bind address, probing, IDE and search, language and
theme, update and maintenance). Every action runs through nimctl itself; its output streams into a console drawer.

How it works: nimctl writes `~/.nimctl/web/index.html` and `server.py` (both embedded in the script; Python standard
library only, no packages) and starts the server on `127.0.0.1:4040` (`NIMCTL_WEB_PORT`). The page carries a
per-installation token (`~/.nimctl/web/token`, mode 600); every API call must present it together with a `Host`
header naming this machine, so another site open in your browser can neither read your state nor run commands. Keys
and passwords reach nimctl through stdin or its environment, never a command line. Values changed under Settings
land in `~/.nimctl/settings` (`NIMCTL_*` names nimctl reads at start – a variable set in the environment still wins)
and apply after a restart; the page says so and offers the button. The server samples the proxy statistics every
30 s into `web/history.json` (24 hours) for the charts. `nimctl web disable` takes the service out of
start/stop/restart and systemd; the wizard offers the web UI after the IDE and the search.

## Configuration

All optional, via environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `NIMCTL_LANG` | from `$LANG` (`de` → German, everything else English) | UI language (`--lang` per call) |
| `NIMCTL_PROXY_PORT` | `4000` | LiteLLM port |
| `NIMCTL_CHAT_PORT` | `3000` | Open WebUI port |
| `NIMCTL_IDE_PORT` | `8080` | code-server port |
| `NIMCTL_IDE_EXTENSIONS` | | Extra Open VSX extensions `nimctl ide install` adds next to Continue |
| `NIMCTL_IDE_CONTEXT` | `32768` | Context length Continue assumes for the models |
| `NIMCTL_SEARCH_PORT` | `8888` | SearXNG port (`nimctl search`) |
| `NIMCTL_SEARCH_RESULTS` | `5` | Web search results Open WebUI feeds to the model per query |
| `NIMCTL_WEB_PORT` | `4040` | Web UI port (`nimctl web`) |
| `NIMCTL_BIND` | `127.0.0.1` | Address the services listen on |
| `NIMCTL_PROBE_TIMEOUT` | `45` | Seconds a model may take to answer a probe |
| `NIMCTL_REPROBE_HOURS` | `6` | Dashboard re-probes slots whose last probe is older |
| `NIMCTL_HOME` | `~/.nimctl` | Data directory |
| `NIMCTL_API_BASE` | NVIDIA endpoint | Point at a self-hosted NIM container instead |
| `NIMCTL_API_KEY` | | Key for unattended `setup --yes` (also `NVIDIA_API_KEY`) |
| `GROQ_API_KEY` etc. | | Pool keys from the environment (`GEMINI_API_KEY`, `CEREBRAS_API_KEY`, `OPENROUTER_API_KEY`, `MISTRAL_API_KEY`): win over the config file, taken over by `nimctl setup --yes` |
| `NIMCTL_POOL_BASE_<PROVIDER>` | provider endpoint | Endpoint of a pool provider, e.g. `NIMCTL_POOL_BASE_GROQ` (tests, mirrors) |
| `NIMCTL_CAND_CODE` etc. | built-in lists | Candidate patterns per slot, space separated; `NIMCTL_CAND_GROQ_CODE` etc. for the pool providers |
| `NIMCTL_CHAT_VIA_PROXY` | `1` | Open WebUI talks to the proxy (throttle, retries, fallbacks, curated model list); `0` = directly to NVIDIA |
| `NIMCTL_CHAT_PASSWORD` | | New password for `nimctl chat passwd` in unattended runs |
| `NIMCTL_MAX_OUTPUT_TOKENS` | `8192` | Output cap for Claude Code |
| `NIMCTL_RPM` | `36` | Request budget per minute for the whole key; the proxy delays requests beyond it instead of forwarding them (see Rate limiting) |
| `NIMCTL_RPM_MAX_WAIT` | `30` | Seconds a request may wait for a free slot before the proxy answers 429 with `Retry-After` |
| `NIMCTL_STALL_TIMEOUT` | `90` | Seconds the proxy waits for a model to send anything – the next byte of a streamed answer, a whole non-streamed one – before it hands the request to the fallback (fast model or pool) |
| `NIMCTL_PROVIDER` | `custom_openai` | LiteLLM provider prefix. Do not use `openai` – LiteLLM would send Claude Code's requests to a Responses API NVIDIA lacks |
| `NIMCTL_KEY_WARN_DAYS` | `165` | Key age in days after which the dashboard warns (NVIDIA keys last ~180 days) |
| `NIMCTL_WEBUI_PYTHON` | auto | Python interpreter with `bcrypt` for `nimctl chat passwd` (default: the Open WebUI environment) |
| `NIMCTL_REPO` | `phish3144/nimctl` | GitHub repository used by the installer and `nimctl update` (forks) |
| `NIMCTL_UPDATE_URL` | GitHub raw URL | Base URL for `nimctl update` (mirrors, tests) |
| `NIMCTL_INTERACTIVE` | auto | `1` forces prompts when stdin is not a terminal (expect scripts, tests); `0` forces the non-interactive path |
| `NIMCTL_YES` | `0` | `1` = like `--yes` everywhere |
| `NO_COLOR` | | Disable colours (status glyphs stay distinguishable) |

Autostart at login: `nimctl install systemd` (or dashboard → `i` → `3`) creates `systemd --user` units `nimctl-proxy`
and `nimctl-chat`; the dashboard and `nimctl restart` keep them under systemd. The watchdog timer (`i` → `6`) runs
`nimctl watch` hourly.

## Requirements and compatibility

| | |
|---|---|
| Shell | bash ≥ 4.4 (the script refuses older versions with a clear message) |
| Tools | `curl`, `jq`, `awk`; `python3` for the web UI and `nimctl chat passwd`; optional: `ss`/`lsof` (port owner), `flock`, `notify-send`, `systemctl` |
| Installed by the wizard | `uv`, `litellm[proxy]`, `open-webui` (Python 3.11 via uv), `@anthropic-ai/claude-code` (needs `npm`), optionally `code-server` + Continue |
| Tested | Ubuntu 24.04 (CI runs the full suite on every push and pull request) |
| Expected to work | Debian, Fedora, Arch, Alpine, WSL2 (package managers `apt`, `dnf`, `pacman`, `apk`; browser via `wslview`/`explorer.exe`) |
| Untested | macOS with `brew install bash jq` (all GNU-only calls have BSD fallbacks; autostart needs systemd and is Linux-only) |

Nothing else runs at install time: the script is one file you can read before piping it into `bash`.

## Uninstall

```bash
nimctl stop                                   # stop proxy, chat, IDE and search
nimctl install                                # → 4 removes the systemd units and the watchdog timer, if you enabled them
rm -rf ~/.nimctl ~/.local/bin/nimctl          # config, logs, chat data (chats and uploads live in ~/.nimctl/webui-data)
rm -rf ~/.local/lib/code-server-* ~/.local/bin/code-server ~/.continue   # the browser IDE, if you enabled it
uv tool uninstall litellm open-webui          # the tools the wizard installed, if you no longer need them
npm uninstall -g @anthropic-ai/claude-code    # only if nimctl installed it for you
```

Remove the `PATH` and `completion` lines the installer added to `~/.bashrc` / `~/.zshrc` if you like; they are harmless.

## Claude Code on open models – what to expect

Works well: explaining code, boilerplate, tests, refactoring single files, shell tasks.
Less reliable: long tool chains, multi-file rewrites, extended thinking. Keep `claude` (real Claude) for those;
`nimctl code` is the free second lane, `nimctl code --model review` the slow-but-strong one.

## Troubleshooting

| Symptom | Meaning | Fix |
|---|---|---|
| `✗ no endpoint for this account` | Model is listed but has no hosted endpoint (deprecated or restricted) | `a` (auto-select) or pick another with `f` |
| `✗ timeout after 45s` | Model overloaded on the free tier | Usually temporary; `p` later, or choose a faster one |
| `✗ rate limit (429)` | ~40 req/min per model exceeded | Wait a minute; fallback to `fast` kicks in automatically |
| `✗ overloaded (worker limit)` | NVIDIA's workers for that model are full | Try later or another model |
| Answers break off; `Timeout on reading data from socket` in `nimctl logs proxy` | NVIDIA queued the request and sent nothing for `NIMCTL_STALL_TIMEOUT` seconds (90) | The proxy hands such requests to the fast model; add a provider pool so they land on another endpoint: `nimctl pool add groq <key>` |
| `! no tool calls` | Model answers but cannot call functions | Not usable for `code`/`review`; fine for `chat` |
| Key `invalid/expired` | Keys expire after 6 months (the dashboard warns two weeks ahead) | `k`, paste a new one |
| `port 4000 is taken by …` | Another program listens there; nimctl never touches it | `NIMCTL_PROXY_PORT=4100 nimctl` |
| `configuration changed – r restarts the proxy` | Models changed while the proxy runs | `r` |
| Anything else | | `nimctl doctor` |

## FAQ

**Is this really free?** Yes for prototyping and personal use: no credit card, rate-limited per model, no token quota.
Not suitable as a production backend – for that, deploy NIM containers or pay for hosted endpoints.

**Where does my data go?** To NVIDIA's US infrastructure. Do not send confidential customer data without a
data-processing agreement. `NIMCTL_API_BASE` lets you point nimctl at a self-hosted NIM instead.

**Does this replace my Claude subscription?** No. It gives you a free lane for routine work so your Claude quota
lasts for the hard problems.

**Why bash?** One file, no runtime to install, readable, easy to audit before piping to `bash`. The sources are
split into `src/` for maintenance; `build.sh` produces the single file you install.

## Development

```bash
git clone https://github.com/phish3144/nimctl && cd nimctl
./build.sh                                     # src/*.sh → nimctl + SHA256SUMS
shellcheck -S warning nimctl build.sh install.sh tests/run.sh tests/cases/*.sh   # CI uses shellcheck 0.9.0
bash tests/run.sh                              # offline: mock API + fake services, ~3 min
```

The test suite simulates a valid/invalid key, a listed-but-dead model, a 40-second model, a cold model, an overloaded
model, models without tool calling, streaming, config injection, stale pid files, foreign listeners, headless setup,
two pool providers with their own keys and catalogs, the web UI's server and API, self-update and the installer. See [CONTRIBUTING.md](CONTRIBUTING.md) for the module layout and how a release is cut
(the *Release* workflow publishes `nimctl` and `SHA256SUMS` under [Releases](https://github.com/phish3144/nimctl/releases)).

---

## Deutsch – Kurzfassung

**Claude Code und ein privater Browser-Chat auf kostenlosen Open-Source-Modellen der Spitzenklasse, mit einem Befehl
eingerichtet.** NVIDIA stellt über 100 Modelle (DeepSeek V4, Nemotron 3, Kimi K3, GLM 5, Llama 4) mit einem kostenlosen
Kontingent bereit, ohne Kreditkarte. `nimctl` prüft den Key, installiert die Werkzeuge, findet automatisch Modelle, die
für dein Konto wirklich antworten und Tool-Calls beherrschen, startet Proxy und Chat und ersetzt abgeschaltete Modelle
von selbst.

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

Danach: `nimctl` (Dashboard, eine Taste pro Aktion, `?` erklärt alles), `nimctl code` (Claude Code im Projektordner),
`nimctl ide` (VS Code im Browser mit Continue auf denselben Modellen), `nimctl web` (Web-Oberfläche mit Einstellungen
und Statistik), `nimctl chat` (Browser-Chat), `nimctl chat passwd` (Chat-Admin-Passwort zurücksetzen), `nimctl bench` (Modelle
vergleichen), `nimctl stats` (was der Proxy tut), `nimctl pool add groq <key>` (kostenlose Ausweich-Anbieter, die
übernehmen, wenn NVIDIA hängt oder 429 liefert). Bei Problemen: `nimctl doctor`. Die Oberfläche ist auf Deutsch,
wenn `$LANG` deutsch ist, sonst `NIMCTL_LANG=de nimctl` oder `nimctl --lang=de`.

## License

[MIT](LICENSE)
