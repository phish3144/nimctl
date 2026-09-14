# nimctl

**Free frontier-class models for Claude Code and a local chat – set up in one command.**

[![CI](https://github.com/phish3144/nimctl/actions/workflows/ci.yml/badge.svg)](https://github.com/phish3144/nimctl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![bash](https://img.shields.io/badge/bash-4.3%2B-blue)
![shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen)

NVIDIA's [NIM API catalog](https://build.nvidia.com) hosts 100+ open models (DeepSeek V4, Nemotron 3, Kimi, GLM, Llama …) with a free tier. Using it for real work means wiring up a proxy for Claude Code, a chat UI, and – the annoying part – figuring out which of the listed models actually respond for your account today.

`nimctl` does all of that for you.

```
$ nimctl
╔══════════════════════════════════════════════════════════════╗
║  NVIDIA NIM · Control Center               13.09.2026 20:15  ║
╚══════════════════════════════════════════════════════════════╝
  API key   ● valid  (nvapi-k3f9x… · checked 20:14)
  Proxy     ● up     :4000     Chat   ● up     :3000
  Tools     ● litellm  ● open-webui  ● claude

Models
──────────────────────────────────────────────────────────────
  1  code  deepseek-ai/deepseek-v4-pro-0813     ● responds · 655 ms · 20:14
  2  fast  deepseek-ai/deepseek-v4-flash-0731   ● responds · 95 ms · 20:14
  3  chat  nvidia/nemotron-3-super-120b         ● responds · 92 ms · 20:14
  code = Claude Code · fast = side tasks & fallback · chat = browser chat

──────────────────────────────────────────────────────────────
  s Start  x Stop  r Restart  a Auto-select models  p Probe models
  1/2/3 pick slot manually  f Find model  t Test model
  c Claude Code  w Open chat  k Key  d Doctor  i Install  l Logs  q Quit
──────────────────────────────────────────────────────────────
  >
```

## Why nimctl

| Problem with doing it by hand | What nimctl does |
|---|---|
| The catalog lists models that return `Function … Not found for account` | Every model is verified with a **real request** before it is used |
| New flagship models (kimi-k3, nemotron-3-ultra) can take 60 s+ per reply on the free tier | Candidates are probed **in parallel with latency measurement**; the fastest responding one wins |
| Model IDs change (`deepseek-v4-pro` → `deepseek-v4-pro-0813`) | Selection uses **patterns matched against the live catalog**, not hard-coded IDs |
| Claude Code speaks the Anthropic API, NIM speaks OpenAI | A local **LiteLLM proxy** is configured, started and supervised for you |
| Five tools, three config files, env vars in the right places | **One wizard**, one dashboard, one config directory (`~/.nimctl`) |
| "Is it the key, the model, the proxy or the port?" | `nimctl doctor` **diagnoses and repairs** |

## Quick start

Ubuntu/Debian (also WSL2 on Windows). Requires `curl`, `jq`, `bash ≥ 4.3`; the installer adds `jq` if missing.

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

The wizard then walks through five steps:

1. **API key** – paste it (input hidden); it is validated against NVIDIA immediately. No key yet? The wizard opens <https://build.nvidia.com/settings/api-keys>. Free account, no credit card, SMS verification.
2. **Tools** – installs what is missing: `uv`, `litellm`, `open-webui`, `claude` (Claude Code). 2–5 minutes.
3. **Models** – probes candidates for each slot and picks the fastest one that responds.
4. **Services** – starts the proxy and the chat.
5. **Done** – prints what to type next.

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
| `nimctl setup` | Re-run the wizard |
| `nimctl start` / `stop` / `restart` | Proxy (LiteLLM, :4000) and chat (Open WebUI, :3000) |
| `nimctl status` | Dashboard once, non-interactive (for scripts) |
| `nimctl auto` | Re-select models automatically (e.g. after catalog changes) |
| `nimctl check` | Probe the three configured models with a real request |
| `nimctl find <text>` | Probe every catalog entry matching `<text>` – shows what really answers |
| `nimctl test [model-id]` | Send a prompt, see reply, tokens and time |
| `nimctl code [args]` | Launch Claude Code against the proxy (`claude` args pass through) |
| `nimctl chat` | Start chat if needed and open it in the browser |
| `nimctl doctor` | Diagnose tools, key, network, ports, models – offers to fix |
| `nimctl update` | Self-update from this repository |
| `nimctl logs` | Tail proxy or chat logs |

## The three model slots

| Slot | Used for | Default candidates (first that responds wins) |
|---|---|---|
| `code` | Claude Code main model | deepseek-v4-pro · laguna-xs · glm-5 · qwen3-coder · kimi-k3 · nemotron-3-ultra |
| `fast` | Claude Code side tasks (`ANTHROPIC_SMALL_FAST_MODEL`) and LiteLLM fallback on 429 | deepseek-v4-flash · nemotron-3.5-lightning · nemotron-3-nano |
| `chat` | Browser chat default model | nemotron-3-super · nemotron-3-ultra · deepseek-v4-flash · llama-4-maverick |

Rationale: NVIDIA's free tier limits **~40 requests/minute per model**, so spreading slots over different models multiplies your effective throughput. Nemotron is NVIDIA's own model family and the least likely to be throttled or removed. Override anytime with `1`/`2`/`3` in the dashboard – your pick is probed before it is saved.

## How it works

```
 nimctl code ──► Claude Code ──(Anthropic API)──► LiteLLM proxy :4000 ──(OpenAI API)──► integrate.api.nvidia.com
 nimctl chat ──► Open WebUI :3000 ───────────────────────────────────────(OpenAI API)──► integrate.api.nvidia.com
```

Everything lives in `~/.nimctl`:

```
config          API key + chosen models (chmod 600)
litellm.yaml    generated proxy config – do not edit, use the dashboard
probes          last probe result per model (ok/error, latency, time)
models.cache    catalog snapshot (refreshed hourly)
logs/           litellm.log, open-webui.log
webui-data/     chat history, uploaded documents, users
```

## Configuration

All optional, via environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `NIMCTL_LANG` | from `$LANG` (`de` / `en`) | UI language |
| `NIMCTL_PROXY_PORT` | `4000` | LiteLLM port |
| `NIMCTL_CHAT_PORT` | `3000` | Open WebUI port |
| `NIMCTL_PROBE_TIMEOUT` | `45` | Seconds a model may take to answer a probe |
| `NIMCTL_HOME` | `~/.nimctl` | Data directory |
| `NIMCTL_API_BASE` | NVIDIA endpoint | Point at a self-hosted NIM container instead |

Autostart at login: dashboard → `i` → `3` (creates `systemd --user` units `nimctl-proxy` and `nimctl-chat`).

## Claude Code on open models – what to expect

Works well: explaining code, boilerplate, tests, refactoring single files, shell tasks.
Less reliable: long tool chains, multi-file rewrites, extended thinking. Keep `claude` (real Claude) for those; `nimctl code` is the free second lane. When the proxy hits a 429, LiteLLM automatically falls back from `code` to `fast`.

## Troubleshooting

| Symptom | Meaning | Fix |
|---|---|---|
| `● no endpoint for this account` | Model is listed but has no hosted endpoint (deprecated or restricted) | `a` (auto-select) or pick another with `f` |
| `● timeout after 45s` | Model overloaded on the free tier | Usually temporary; `p` later, or choose a faster one |
| `● rate limit (429)` | ~40 req/min per model exceeded | Wait a minute; fallback to `fast` kicks in automatically |
| Key `invalid/expired` | Keys expire after 6 months | `k`, paste a new one |
| Proxy `failed to start` | See `l` → LiteLLM log | Often a port clash: `NIMCTL_PROXY_PORT=4100 nimctl` |
| Anything else | | `nimctl doctor` |

## FAQ

**Is this really free?** Yes for prototyping and personal use: no credit card, rate-limited per model, no token quota. Not suitable as a production backend – for that, deploy NIM containers or pay for hosted endpoints.

**Where does my data go?** To NVIDIA's US infrastructure. Do not send confidential customer data without a data-processing agreement. `NIMCTL_API_BASE` lets you point nimctl at a self-hosted NIM instead.

**Does this replace my Claude subscription?** No. It gives you a free lane for routine work so your Claude quota lasts for the hard problems.

**Why bash?** One file, no runtime to install, readable, easy to audit before piping to `bash`.

## Development

```bash
git clone https://github.com/phish3144/nimctl && cd nimctl
shellcheck -S warning nimctl install.sh tests/run.sh
bash tests/run.sh          # offline: mock API + fake services, ~1 min
```

The test suite simulates a valid/invalid key, a listed-but-dead model, a 40-second model, and the full wizard. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Deutsch – Kurzfassung

`nimctl` richtet in einem Durchlauf alles ein, um NVIDIAs kostenlose NIM-Modelle mit **Claude Code** und einem **lokalen Browser-Chat** zu nutzen: Key prüfen, Werkzeuge installieren, funktionierende Modelle automatisch finden und nach Antwortzeit auswählen, Dienste starten.

```bash
curl -fsSL https://raw.githubusercontent.com/phish3144/nimctl/main/install.sh | bash
```

Danach: `nimctl` (Dashboard), `nimctl code` (Claude Code im Projektordner), `nimctl chat` (Browser). Bei Problemen: `nimctl doctor`. Die Oberfläche ist auf Deutsch, wenn `$LANG` deutsch ist, sonst `NIMCTL_LANG=de nimctl`.

## License

[MIT](LICENSE)
