# Contributing

Thanks for helping! Keep it small and testable.

## Layout

```
src/*.sh        the sources, concatenated in filename order by build.sh
nimctl          the built, self-contained script (committed – install.sh and `nimctl update` fetch it)
SHA256SUMS      checksum of the built script (committed, verified by `nimctl update`)
tests/run.sh    test runner: mock NVIDIA API, fake litellm/open-webui/claude/uv, then tests/cases/*.sh in order
tests/cases/    one file per area; state (config, probes, services) carries over from earlier files
```

Workflow: edit `src/`, run `./build.sh`, then `shellcheck -S warning nimctl tests/cases/*.sh` and `bash tests/run.sh`.
CI fails when `nimctl`/`SHA256SUMS` are stale, when `CHANGELOG.md` has no entry for `VERSION`, or when a placeholder
URL sneaks in. Requirements: bash ≥ 4.4, `curl`, `jq`, `awk`; nothing else at runtime.

## Writing a module

A module is one file `src/NN-name.sh` (NN between 41 and 89 – the core lives in 05–40, dashboard/doctor/wizard/
update/main in 50–90). It contains functions and translation blocks only – no top-level side effects except
registrations:

```bash
T_de+=( [h_stats]="Auswertung des Proxy-Logs" [stats_none]="noch keine Daten" )
T_en+=( [h_stats]="proxy log summary"          [stats_none]="no data yet" )
cmd_stats() { … }                    # becomes `nimctl stats …` and shows up in `nimctl help` via h_stats
dash_register g cmd_stats k_g use    # dashboard key g in group use (svc | models | use | sys); label key k_g
```

Every user-visible string goes through `t key` / `tf key args…` and exists in **both** tables. Output goes
through `out`, `ok`, `bad`, `warn`, `info` (they also feed the dashboard's "last action" panel). Ask with
`ask "question" y|n` (default `n` needs an explicit yes; non-interactive runs take the default, `--yes` says yes)
and read input with `prompt "text" [hidden]` → `$REPLY` (returns 1 on EOF or without a terminal).

Useful helpers (see `src/05-core.sh` … `src/40-actions.sh`):

| Need | Use |
|---|---|
| NVIDIA API call | `api GET /models 15` · `api POST /chat/completions 45 "$json"` → body on stdout, HTTP code in `$API_CODE`; raw curl: `curl -K "$HDR_FILE" …` (never put the key on argv) |
| probe results | `probe_get id` → `$PROBE_RES $PROBE_MS $PROBE_T $PROBE_TOOLS`; `probe_set id ok|error [ms] [ok|no]`; `probe_ok_models` |
| slots | `slot_model code`, `set_slot code id`, `SLOTS=(code fast chat review)`, `auto_select slot…` |
| services | `svc_state proxy|chat` → `$SVC_BY` (nimctl/systemd/foreign) `$SVC_PID`; `svc_running`, `restart_svc`, `start_proxy` |
| files | `$NIM_DIR` (700), `$LOG_DIR`, `$CONF`, `$LITELLM_YAML`, `$MODEL_CACHE`; `with_lock cmd` for shared writes |
| misc | `has cmd`, `age_of epoch`, `fmt_time epoch +%H:%M`, `now_ms`, `trunc text width`, `$COLS`, `open_url`, `pkg_hint jq`, `valid_model id` |

## Tests

Add `tests/cases/NN-name.sh` (sourced by the runner, `# shellcheck shell=bash` on top). Available: `$N` (built
nimctl), `$TMP` (scratch, `$TMP/home` is `NIMCTL_HOME`), `check name regex < <(cmd)`, `nocheck`, `pass`, `fail`,
`assert name cmd…`. The mock API (`tests/mock_api.py`, port 9999) knows valid/invalid keys, dead, slow, cold and
overloaded models, tool calling (`*-notools` models refuse) and streaming. Fake `litellm`, `open-webui`, `claude`
and `uv` live in `$TMP/bin`; the fake services answer any `/v1/messages` POST. Piped input answers prompts one line
per prompt (`NIMCTL_INTERACTIVE=1` is set by the runner; set it to `''` to test the non-interactive path).

Bug reports: please include `nimctl doctor` output and `~/.nimctl/logs/*.log`.
