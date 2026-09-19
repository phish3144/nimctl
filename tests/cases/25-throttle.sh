# shellcheck shell=bash
# Request throttle: the LiteLLM hook nimctl writes, its registration, the proxy environment, the chat through the
# proxy, the dashboard line and the stats counter. The hook itself runs against a stub of litellm's CustomLogger.
timeout 60 "$N" start >/dev/null 2>&1
grep -q 'callbacks: nimctl_hooks.throttle' "$TMP/home/litellm.yaml" && pass "throttle: hook registered in litellm.yaml" || fail "throttle: hook registered in litellm.yaml"
python3 -m py_compile "$TMP/home/nimctl_hooks.py" 2>/dev/null && [[ $(stat -c %a "$TMP/home/nimctl_hooks.py") == 600 ]] && pass "throttle: hook file written, compiles, 600" || fail "throttle: hook file written, compiles, 600"
check "throttle: proxy gets budget and PYTHONPATH" "rpm=36 pythonpath=$TMP/home" < "$TMP/home/logs/litellm.log"
check "chat: through the proxy by default" "default=nim-chat base=http://127.0.0.1:$PP/v1" < "$TMP/home/logs/open-webui.log"
nocheck "litellm.yaml: no per-deployment rpm any more" "rpm:" < "$TMP/home/litellm.yaml"
check "litellm.yaml: every rank falls down its chain, then to the fast model" 'fallbacks: \[ \{ nim-code: \["nim-code-r2", .*"nim-fast"\] \}, \{ nim-code-r2: \[.*"nim-fast"\] \}' < "$TMP/home/litellm.yaml"
mkdir -p "$TMP/pystub/litellm/integrations"; touch "$TMP/pystub/litellm/__init__.py" "$TMP/pystub/litellm/integrations/__init__.py"
printf 'class CustomLogger:\n    def __init__(self, *a, **k): pass\n' >"$TMP/pystub/litellm/integrations/custom_logger.py"
cat >"$TMP/throttle_test.py" <<'PY'
import asyncio, json, os, time
import nimctl_hooks as h
t = h.throttle
async def call(): return await t.async_pre_call_hook(None, None, {"model": "nim-fast"}, "completion")
async def main():
    t0 = time.monotonic(); await call(); assert time.monotonic() - t0 < 0.2, "full bucket must not wait"
    t.tokens = 0.0; t.last = time.monotonic()
    t0 = time.monotonic(); await call(); d = time.monotonic() - t0; assert 0.4 <= d <= 1.2, f"empty bucket at 120/min should wait ~0.5s, waited {d:.2f}s"
    t.tokens = -5.0; t.last = time.monotonic()
    try:
        await call(); raise SystemExit("expected a 429 beyond the maximum wait")
    except h.HTTPException as e:
        assert e.status_code == 429 and e.headers.get("Retry-After"), e
    class RL(Exception): status_code = 429
    await t.async_post_call_failure_hook({}, RL("rate"), None)
    assert t.limit == 96.0, t.limit
    s = json.load(open(os.environ["NIMCTL_RPM_STATE"]))
    assert s["budget"] == 96 and s["throttled"] == 1 and s["rejected"] == 1 and s["upstream_429"] == 1 and s["penalty_until"] > 0, s
    print("throttle ok", json.dumps(s))
asyncio.run(main())
PY
check "throttle: bucket waits, refuses beyond max wait, shrinks after 429, writes state" "throttle ok" < <(PYTHONPATH="$TMP/pystub:$TMP/home" NIMCTL_RPM=120 NIMCTL_RPM_MAX_WAIT=0.6 NIMCTL_RPM_STATE="$TMP/rpm-test.json" timeout 30 python3 "$TMP/throttle_test.py" 2>&1)
printf '{"code":["nim-code","nim-code-r2","nim-code-r3"],"fast":["nim-fast"],"nim":["nim-code","nim-code-r3","nim-fast"],"models":{"nim-code":"a","nim-code-r2":"groq:b","nim-code-r3":"c","nim-fast":"d"}}' >"$TMP/chains-test.json"
cat >"$TMP/chain_test.py" <<'PY'
import asyncio, json, os
import nimctl_hooks as h
t = h.throttle
def kw(group): return {"litellm_params": {"metadata": {"model_group": group}, "model_info": {"id": "dep-" + group}}, "exception": TimeoutError("stall")}
async def main():
    d = await t.async_pre_call_hook(None, None, {"model": "nim-code"}, "completion"); assert d["model"] == "nim-code", d
    await t.async_log_failure_event(kw("nim-code"), None, 0, 0)
    await t.async_log_failure_event(kw("nim-code"), None, 0, 0)          # the same failure reported twice counts once
    assert t.fails["nim-code"] == 1, t.fails
    d = await t.async_pre_call_hook(None, None, {"model": "nim-code"}, "completion"); assert d["model"] == "nim-code-r2", d
    before = t.tokens
    await t.async_pre_call_hook(None, None, {"model": "nim-code"}, "completion"); assert t.tokens == before, "a pool rank must not use NVIDIA's budget"
    await t.async_log_failure_event(kw("nim-code-r2"), None, 0, 0)
    d = await t.async_pre_call_hook(None, None, {"model": "nim-code"}, "completion"); assert d["model"] == "nim-code-r3", d
    assert t.tokens < before, "an NVIDIA rank uses the budget"
    d = await t.async_pre_call_hook(None, None, {"model": "nim-code-r2"}, "completion"); assert d["model"] == "nim-code-r3", d
    await t.async_log_success_event(kw("nim-code"), None, 0, 0)
    d = await t.async_pre_call_hook(None, None, {"model": "nim-code"}, "completion"); assert d["model"] == "nim-code", d
    d = await t.async_pre_call_hook(None, None, {"model": "nim-fast"}, "completion"); assert d["model"] == "nim-fast"
    d = await t.async_pre_call_hook(None, None, {"model": "something-else"}, "completion"); assert d["model"] == "something-else"
    s = json.load(open(os.environ["NIMCTL_HEALTH"]))
    assert "nim-code-r2" in s["cooldown"] and s["cooldown"]["nim-code-r2"]["rank"] == 2 and s["cooldown"]["nim-code-r2"]["model"] == "groq:b", s
    assert "nim-code" not in s["cooldown"] and s["routed"] >= 3, s
    print("chain ok", json.dumps(s["cooldown"]))
asyncio.run(main())
PY
check "hook: chain routing – a failed rank is paused, requests go to the next healthy rank, success clears it, pool ranks skip the budget" "chain ok" < <(PYTHONPATH="$TMP/pystub:$TMP/home" NIMCTL_RPM=120 NIMCTL_RPM_MAX_WAIT=0.6 NIMCTL_RPM_STATE="$TMP/rpm-test2.json" NIMCTL_CHAINS="$TMP/chains-test.json" NIMCTL_HEALTH="$TMP/health-test.json" timeout 30 python3 "$TMP/chain_test.py" 2>&1)
printf '{"cooldown":{"nim-code":{"model":"deepseek-ai/deepseek-v4-pro-0813","slot":"code","rank":1,"reason":"Timeout","until":%s,"fails":1}},"routed":1,"updated":%s}\n' "$(( $(date +%s) + 300 ))" "$(date +%s)" >"$TMP/home/health.json"
check "dashboard: paused ranks from health.json" "Pausiert +code #1 deepseek-ai/deepseek-v4-pro-0813 \(Timeout, bis [0-9]{2}:[0-9]{2}\)" < <(timeout 20 "$N" status)
check "status --json: health block" '"cooldown":\{"nim-code":\{' < <(timeout 20 "$N" status --json | jq -c .health)
rm -f "$TMP/home/health.json"
printf '{"rpm":36,"budget":36,"free":12,"waiting":1,"throttled":3,"rejected":0,"upstream_429":0,"avg_wait":1.4,"penalty_until":0,"updated":%s}\n' "$(date +%s)" >"$TMP/home/rpm.json"
check "dashboard: budget line from rpm.json" "Budget +36/min · 12 frei · 1 wartend · 3 gebremst \(Ø 1.4 s\)" < <(timeout 20 "$N" status)
printf '{"rpm":36,"budget":29,"free":0,"waiting":0,"throttled":3,"rejected":2,"upstream_429":1,"avg_wait":1.4,"penalty_until":%s,"updated":%s}\n' "$(( $(date +%s) + 240 ))" "$(date +%s)" >"$TMP/home/rpm.json"
check "dashboard: budget line shows rejections and the penalty" "29/min .*2 abgewiesen · gedrosselt nach 429 bis [0-9]{2}:[0-9]{2}" < <(timeout 20 "$N" status)
printf '{"rpm":36,"budget":36,"free":36,"waiting":0,"throttled":0,"rejected":0,"upstream_429":0,"avg_wait":0,"penalty_until":0,"updated":%s}\n' "$(( $(date +%s) - 600 ))" >"$TMP/home/rpm.json"
nocheck "dashboard: stale rpm.json is not shown" "Budget +36/min" < <(timeout 20 "$N" status)
rm -f "$TMP/home/rpm.json"
echo 'nimctl throttle: waited 1.2s (nim-code, budget 36/min)' >>"$TMP/home/logs/litellm.log"
check "stats: counts throttled requests" "Gebremst \(Budget\): 1" < <(timeout 20 "$N" stats)
check "stats --json: throttled" '"throttled":1' < <(timeout 20 "$N" stats --json | jq -c .)
timeout 30 "$N" stop >/dev/null 2>&1
