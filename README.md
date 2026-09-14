# nimctl

**Free frontier-class models for Claude Code and a local chat – set up in one command.**

[![CI](https://github.com/phish3144/nimctl/actions/workflows/ci.yml/badge.svg)](https://github.com/phish3144/nimctl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![bash](https://img.shields.io/badge/bash-4.4%2B-blue)
![shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen)

NVIDIA's [NIM API catalog](https://build.nvidia.com) hosts 100+ open models (DeepSeek V4, Nemotron 3, Kimi, GLM, Llama …)
with a free tier. Using it for real work means wiring up a proxy for Claude Code, a chat UI, and – the annoying part –
figuring out which of the listed models actually respond for your account today, and which of those can make the
tool calls Claude Code depends on.

`nimctl` does all of that for you.

```
$ nimctl
 nimctl · NVIDIA NIM 1.1.0                                            2026-09-14 20:15
────────────────────────────────────────────────────────────────────────────────────
  Key      ✓ valid  (nvapi-…k3f9 · checked 20:14 · expires in ~150 days)
  Proxy    ✓ up     :4000  nimctl · pid 41205
  Chat     ✓ up     :3000  systemd
  Tools    ✓ litellm  ✓ open-webui  ✓ claude  ✓ uv
  Today    since 09:14 · 212 requests · 3× 429 · 9 fallbacks

Models
────────────────────────────────────────────────────────────────────────────────────
  1  code    deepseek-ai/deepseek-v4-pro-0813         ✓ responds ·   655 ms · 3 min ago  ✓
  2  fast    deepseek-ai/deepseek-v4-flash-0731       ✓ responds ·    95 ms · 3 min ago
  3  chat    nvidia/nemotron-3-super-120b             ✓ responds ·    92 ms · 3 min ago
  4  review  nvidia/nemotron-3-ultra-550b-a55b        ✓ responds ·  1520 ms · 3 min ago  ✓
  code = Claude Code · fast = side tasks & fallback · chat = browser chat · review = big model for nimctl code --model review

┄┄ Last action ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
  ✓ Proxy up  http://localhost:4000
  ✓ Chat up   http://localhost:3000

────────────────────────────────────────────────────────────────────────────────────
  Services s Start  x Stop  r Restart
  Models   a Auto  p Probe  1-4 pick slot  f Find  t Test  b Bench
  Use      c Claude Code  w Chat  e Env  g Stats  n Accounts
  System   k Key  d Doctor  i Install  l Logs  u Update  ? Help  q Quit
  ›
```

One key per action, no Enter. The result of the last action stays on screen, notices appear when something needs
you (configuration changed → `r`, key about to expire, a systemd unit failed), `?` explains every key, and
everything is also a command for scripts.

## Why nimctl

| Problem with doing it by hand | What nimctl does |
|---|---|
| The catalog lists models that return `Function … Not found for account` | Every model is verified with a **real request** before it is used |
| A model that chats fine may not support function calling – Claude Code then fails on the first tool use | Models for the `code` and `review` slots must pass a **tool-calling probe** |
| New flagship models (kimi-k3, nemotron-3-ultra) can take 60 s+ per reply on the free tier | Candidates are probed **in parallel with latency measurement**; `bench` measures tokens/s |
| Model IDs change (`deepseek-v4-pro` → `deepseek-v4-pro-0813`) | Selection uses **patterns matched against the live catalog**, not hard-coded IDs |
| Claude Code speaks the Anthropic API, NIM speaks OpenAI | A local **LiteLLM proxy** is configured, started and supervised for you |
| Models get switched off over night | `nimctl watch` (hourly timer) replaces dead models and restarts the proxy |
| Five tools, three config files, env vars in the right places | **One wizard**, one dashboard, one config directory (`~/.nimctl`) |
| "Is it the key, the model, the proxy or the port?" | `nimctl doctor` **diagnoses and repairs** |

## Quick start

Linux (Ubuntu/Debian, Fedora, Arch, Alpine) and WSL2; macOS with `brew install bash jq`. Requires `bash ≥ 4.4`,
`curl`, `jq`; the installer adds `jq`/`curl` with your package manager if they are missing.

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

The wizard then walks through five steps:

1. **API key** – paste it (input hidden); it is validated against NVIDIA immediately. No key yet? The wizard opens
   <https://build.nvidia.com/settings/api-keys>. Free account, no credit card, SMS verification.
2. **Tools** – installs what is missing: `uv`, `litellm`, `open-webui`, `claude` (Claude Code). 2–5 minutes.
3. **Models** – probes all candidates in parallel, checks tool calling for the code models, picks per slot.
4. **Services** – starts the proxy and the chat.
5. **Done** – prints what to type next.

Unattended: `NIMCTL_API_KEY=nvapi-… nimctl setup --yes`.

From then on:

```bash
nimctl            # dashboard
nimctl code       # Claude Code on NIM, run inside a project folder
nimctl chat       # opens http://localhost:3000
```

## Commands

| Command | What it does |
|---|---|
| `nimctl` | Dashboard (runs the wizard on first start) |
| `nimctl setup [--yes]` | Re-run the wizard; `--yes` answers every question with its safe default |
| `nimctl start` / `stop` / `restart` | Proxy (LiteLLM, :4000) and chat (Open WebUI, :3000) |
| `nimctl status [--json]` | Dashboard once, non-interactive; JSON for scripts; exit code reflects the state |
| `nimctl check` | Probe the configured models with a real request (tool calls for `code`/`review`) |
| `nimctl auto [slot…]` | Re-select models automatically, all slots or e.g. `nimctl auto code` |
| `nimctl pick <slot> [text]` | Set a slot manually from a list; the pick is probed before it is saved |
| `nimctl find <text>` | Probe every catalog entry matching `<text>` – shows what really answers, and whether it makes tool calls |
| `nimctl test [model\|slot] [prompt]` | Send a prompt, see reply, tokens and time |
| `nimctl bench [--last] [model\|slot…]` | Time to first token, tokens/s and tool calling per model (streamed request) |
| `nimctl proxy` | Anthropic-format round-trip through the proxy for all slots (what Claude Code sees) |
| `nimctl code [--model <slot\|id>] [--think] [args]` | Launch Claude Code against the proxy (`claude` args pass through) |
| `nimctl chat` | Start chat if needed and open it in the browser |
| `nimctl chat users` / `passwd [email]` / `reset` | List accounts, reset a password (the admin's, for example), or wipe all accounts so the next signup becomes admin |
| `nimctl env` | Export lines for other tools: `eval "$(nimctl env)"` |
| `nimctl stats [--json]` | Requests, status classes, rate limits and fallbacks from the proxy log |
| `nimctl watch [--quiet]` | Probe the slots, replace dead models, restart the proxy, log and notify (for timers) |
| `nimctl key [nvapi-…]` | Check or set the API key |
| `nimctl doctor [--fix]` | Diagnose tools, key, network, ports, permissions, models, proxy – repair with `--fix` or on request |
| `nimctl logs [proxy\|chat\|watch] [-f]` | Show or follow a log |
| `nimctl install [all\|alias\|systemd\|completion]` | Tools, PATH, autostart, shell completion, watchdog timer |
| `nimctl update [--check]` | Self-update from this repository with version compare, changelog excerpt and checksum |
| `nimctl models` | Print the catalog, one id per line |
| `nimctl completion bash\|zsh` | Shell completion script |
| `nimctl help [command]` | Help |

Global options: `--yes` (never ask; safe defaults), `--lang de|en`, `--json` (with `status`), `NO_COLOR=1`.

Exit codes: `0` ok · `1` key missing/invalid · `2` proxy not running · `3` prerequisite missing · `4` a selected model
does not respond. `status` combines them as bit flags, so `nimctl status >/dev/null || alert` works in cron.

## The four model slots

| Slot | Used for | Default candidates (first pattern with a responding model wins) |
|---|---|---|
| `code` | Claude Code main model – must make tool calls | deepseek-v4-pro · laguna-xs · glm-5 · qwen3-coder · kimi-k3 · nemotron-3-ultra · nemotron-3-super |
| `fast` | Claude Code side tasks (`ANTHROPIC_SMALL_FAST_MODEL`) and LiteLLM fallback on 429 | deepseek-v4-flash · nemotron-3.5-lightning · nemotron-3-nano · glm-5-flash · nemotron-3-super |
| `chat` | Browser chat default model | nemotron-3-super · nemotron-3-ultra · deepseek-v4-flash · llama-4-maverick · mistral-medium |
| `review` | Big, slow model for `nimctl code --model review` – must make tool calls | nemotron-3-ultra · kimi-k3 · deepseek-v4-pro · glm-5 · nemotron-3-super |

Selection rule: the candidate patterns are tried in order; the first pattern that has a responding model (with tool
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

## Chat accounts

Open WebUI keeps its own accounts. The first account registered at <http://localhost:3000> becomes admin. If you lose
that password, or want to start over:

```bash
nimctl chat users                  # who is there
nimctl chat passwd                 # new password for the (only) admin – prompts twice, hidden
nimctl chat passwd me@example.com --admin
nimctl chat reset                  # wipe all accounts; the next signup becomes admin again
```

Writes stop the chat briefly (SQLite) and start it again. Unattended: `NIMCTL_CHAT_PASSWORD=… nimctl chat passwd
me@example.com --yes`.

## How it works

```
 nimctl code ──► Claude Code ──(Anthropic API)──► LiteLLM proxy 127.0.0.1:4000 ──(OpenAI API)──► integrate.api.nvidia.com
 nimctl chat ──► Open WebUI 127.0.0.1:3000 ───────────────────────────────────────(OpenAI API)──► integrate.api.nvidia.com
                                          (NIMCTL_CHAT_VIA_PROXY=1: through the proxy instead)
```

Everything lives in `~/.nimctl` (mode 700):

```
config          API key, chosen models, proxy master key (chmod 600)
state           key check time, key entry date
litellm.yaml    generated proxy config – do not edit, use the dashboard
probes          last probe result per model (ok/error, latency, time, tool calling)
bench           bench results
models.cache    catalog snapshot (refreshed hourly, used as fallback when NVIDIA is unreachable)
candidates      optional: your own candidate patterns per slot
logs/           litellm.log, open-webui.log, watch.log
run/            pid files and start times
webui-data/     chat history, uploaded documents, users
```

Security notes: the proxy's master key is generated per installation and both services listen on `127.0.0.1` only
(`NIMCTL_BIND=0.0.0.0` to expose them deliberately). The API key never appears on a command line. Model ids from the
catalog are validated before they touch any file; the config is parsed, never sourced. `nimctl update` verifies the
download against `SHA256SUMS`.

## Configuration

All optional, via environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `NIMCTL_LANG` | from `$LANG` (`de` → German, everything else English) | UI language (`--lang` per call) |
| `NIMCTL_PROXY_PORT` | `4000` | LiteLLM port |
| `NIMCTL_CHAT_PORT` | `3000` | Open WebUI port |
| `NIMCTL_BIND` | `127.0.0.1` | Address the services listen on |
| `NIMCTL_PROBE_TIMEOUT` | `45` | Seconds a model may take to answer a probe |
| `NIMCTL_REPROBE_HOURS` | `6` | Dashboard re-probes slots whose last probe is older |
| `NIMCTL_HOME` | `~/.nimctl` | Data directory |
| `NIMCTL_API_BASE` | NVIDIA endpoint | Point at a self-hosted NIM container instead |
| `NIMCTL_API_KEY` | | Key for unattended `setup --yes` (also `NVIDIA_API_KEY`) |
| `NIMCTL_CAND_CODE` etc. | built-in lists | Candidate patterns per slot, space separated |
| `NIMCTL_CHAT_VIA_PROXY` | `0` | `1` = Open WebUI talks to the proxy (retries, fallbacks, curated model list) |
| `NIMCTL_MAX_OUTPUT_TOKENS` | `8192` | Output cap for Claude Code |
| `NIMCTL_RPM` | unset | Per-model requests/minute in the LiteLLM config (LiteLLM then refuses excess requests locally instead of forwarding them) |
| `NIMCTL_PROVIDER` | `custom_openai` | LiteLLM provider prefix. Do not use `openai` – LiteLLM would send Claude Code's requests to a Responses API NVIDIA lacks |
| `NIMCTL_YES` | `0` | `1` = like `--yes` everywhere |
| `NO_COLOR` | | Disable colours (status glyphs stay distinguishable) |

Autostart at login: `nimctl install systemd` (or dashboard → `i` → `3`) creates `systemd --user` units `nimctl-proxy`
and `nimctl-chat`; the dashboard and `nimctl restart` keep them under systemd. The watchdog timer (`i` → `6`) runs
`nimctl watch` hourly.

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
shellcheck -S warning nimctl install.sh tests/run.sh tests/cases/*.sh
bash tests/run.sh                              # offline: mock API + fake services, ~3 min
```

The test suite simulates a valid/invalid key, a listed-but-dead model, a 40-second model, a cold model, an overloaded
model, models without tool calling, streaming, config injection, stale pid files, foreign listeners, headless setup,
self-update and the installer. See [CONTRIBUTING.md](CONTRIBUTING.md) for the module layout.

---

## Deutsch – Kurzfassung

`nimctl` richtet in einem Durchlauf alles ein, um NVIDIAs kostenlose NIM-Modelle mit **Claude Code** und einem
**lokalen Browser-Chat** zu nutzen: Key prüfen, Werkzeuge installieren, funktionierende Modelle automatisch finden
(inklusive Tool-Calling-Prüfung für die Code-Modelle), Dienste starten.

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

Danach: `nimctl` (Dashboard, eine Taste pro Aktion, `?` erklärt alles), `nimctl code` (Claude Code im Projektordner),
`nimctl chat` (Browser), `nimctl chat passwd` (Chat-Admin-Passwort zurücksetzen), `nimctl bench` (Modelle
vergleichen), `nimctl stats` (was der Proxy tut). Bei Problemen: `nimctl doctor`. Die Oberfläche ist auf Deutsch,
wenn `$LANG` deutsch ist, sonst `NIMCTL_LANG=de nimctl` oder `nimctl --lang=de`.

## License

[MIT](LICENSE)
