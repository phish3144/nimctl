#!/usr/bin/env python3
"""nimctl web UI – the backend. Written to ~/.nimctl/web/server.py by nimctl (src/55-web.sh; embedded by build.sh).

Standard library only. Serves index.html and a small JSON API: the current state (nimctl status --json plus the
config, settings, probes, catalogs, bench results and notices), the proxy statistics, a 24-hour sample history for
the charts, log tails (also as a live stream), and `run`, which executes a nimctl command and streams its output as
server-sent events. Settings and candidate patterns are written to their files here; everything else goes through
nimctl itself, so the CLI stays the single place that validates model ids and keys.

Security: bound to NIMCTL_BIND (127.0.0.1). Every API call must carry the per-installation token in the
X-Nimctl-Token header (the page gets it when it is served, other origins cannot read it), and the Host header must
name this machine unless nimctl was deliberately bound elsewhere – so a web page open in the same browser can neither
read the state nor run commands. Secrets (API keys, passwords) reach nimctl through stdin or its environment, never
through a command line.
"""
import hmac
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HOME = os.environ.get("NIMCTL_HOME") or os.path.expanduser("~/.nimctl")
WEB = os.path.join(HOME, "web")
BIN = os.environ.get("NIMCTL_WEB_BIN") or "nimctl"
PORT = int(os.environ.get("NIMCTL_WEB_PORT") or 4040)
BIND = os.environ.get("NIMCTL_BIND") or "127.0.0.1"
LANG = "de" if (os.environ.get("NIMCTL_LANG") or "").startswith("de") else "en"
SETTINGS_KEYS = (os.environ.get("NIMCTL_WEB_KEYS") or "").split()
SLOTS = ["code", "fast", "chat", "review"]
PROVIDERS = ["groq", "gemini", "cerebras", "openrouter", "mistral"]
SERVICES = ["proxy", "chat", "ide", "search", "web"]
LOGS = {"proxy": "litellm.log", "chat": "open-webui.log", "ide": "code-server.log", "search": "searxng.log",
        "web": "web.log", "watch": "watch.log", "searxng-install": "searxng-install.log", "code-server-install": "code-server-install.log"}
HISTORY_FILE = os.path.join(WEB, "history.json")
HISTORY_MAX = 2880          # 24 h of samples
SAMPLE_EVERY = 30.0
STATE_TTL = 3.0
# nimctl commands the page may run (first argument). Interactive ones (code, setup, _fg) and the shell completion are out.
COMMANDS = {"start", "stop", "restart", "status", "check", "auto", "pick", "find", "test", "proxy", "pool", "ide", "search",
            "key", "doctor", "install", "update", "watch", "bench", "stats", "chat", "models", "web"}
RUN_ENV_KEYS = {"NIMCTL_CHAT_PASSWORD"}          # secrets a command may receive through its environment
RE_VALUE = re.compile(r"^[A-Za-z0-9._:/,+ -]*$")  # settings values (the same shape nimctl accepts when it reads the file)
RE_CAND_KEY = re.compile(r"^[a-z]+(\.[a-z]+)?$")
RE_CAND_VAL = re.compile(r"^[A-Za-z0-9._*+?()|^$\[\]\\ :/-]*$")
RE_ARG = re.compile(r"^[^\x00-\x08\x0a-\x1f\x7f]{0,2000}$")   # printable, no control characters
RE_ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")                    # LiteLLM colours its startup banner

with open(os.path.join(WEB, "token")) as _f:
    TOKEN = _f.read().strip()


def log(msg):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), msg, flush=True)


# ── files ──────────────────────────────────────────────────────────────────────────────────────────────────
def read_text(path, default=""):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return default


def read_kv(path):
    """KEY=VALUE lines → dict (parsed like nimctl does, never sourced)."""
    out = {}
    for line in read_text(path).splitlines():
        m = re.match(r"^([A-Z_]+)=(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip('"')
    return out


def read_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_atomic(path, text, mode=0o600):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def mtime(path):
    try:
        return int(os.stat(path).st_mtime)
    except OSError:
        return 0


def tail(path, n):
    lines = [RE_ANSI.sub("", l) for l in read_text(path).splitlines()]
    return lines[-n:] if n else lines


def mask(key):
    return (key[:6] + "…" + key[-4:]) if len(key) > 12 else ("•" * len(key) if key else "")


# ── nimctl ─────────────────────────────────────────────────────────────────────────────────────────────────
def base_env():
    env = dict(os.environ)
    env.update({"NIMCTL_HOME": HOME, "NO_COLOR": "1", "TERM": "dumb", "NIMCTL_INTERACTIVE": "0", "NIMCTL_YES": "1", "NIMCTL_WEB_CALLER": "1"})
    env.pop("NIMCTL_WEB_BIN", None)
    return env


def nimctl(args, timeout=120):
    """Run nimctl non-interactively; returns (rc, stdout)."""
    try:
        p = subprocess.run([BIN, *args], env=base_env(), capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)


def nimctl_json(args, timeout=60):
    rc, out = nimctl(args, timeout)
    try:
        return json.loads(out)
    except ValueError:
        return {"error": out[-400:], "rc": rc}


# ── state ──────────────────────────────────────────────────────────────────────────────────────────────────
_cache = {}
_cache_lock = threading.Lock()


def cached(key, ttl, fn):
    with _cache_lock:
        hit = _cache.get(key)
        if hit and time.monotonic() - hit[0] < ttl:
            return hit[1]
    val = fn()
    with _cache_lock:
        _cache[key] = (time.monotonic(), val)
    return val


def invalidate():
    with _cache_lock:
        _cache.clear()


def parse_pool_models(text):
    out = {}
    for tok in text.split():
        if "=" in tok:
            slot, model = tok.split("=", 1)
            out[slot] = model
    return out


def probes():
    rows = []
    for line in read_text(os.path.join(HOME, "probes")).splitlines():
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        rows.append({"id": parts[0], "result": parts[1], "ms": int(parts[2]) if parts[2].isdigit() else None,
                     "probed": int(parts[3]) if parts[3].isdigit() else None, "tools": parts[4] if len(parts) > 4 and parts[4] else None})
    return rows


def sizes():
    """~/.nimctl/sizes: which request sizes a model takes (id, tokens, ok/error, time)"""
    rows = []
    for line in read_text(os.path.join(HOME, "sizes")).splitlines():
        parts = line.split("\t")
        if len(parts) < 4 or not parts[1].isdigit():
            continue
        rows.append({"id": parts[0], "tokens": int(parts[1]), "result": parts[2], "probed": int(parts[3]) if parts[3].isdigit() else None})
    return rows


def bench_last():
    last = {}
    for line in read_text(os.path.join(HOME, "bench")).splitlines():
        parts = line.split("\t")
        if len(parts) >= 6 and parts[0]:
            last[parts[0]] = {"id": parts[0], "ttft_ms": _num(parts[1]), "tok_s": _num(parts[2]), "tokens": _num(parts[3]),
                              "tools": parts[4] or None, "at": _num(parts[5])}
    return list(last.values())


def _num(s):
    try:
        return float(s) if "." in s else int(s)
    except ValueError:
        return None


def candidates_file():
    out = {}
    for line in read_text(os.path.join(HOME, "candidates")).splitlines():
        m = re.match(r"^([a-z]+(?:\.[a-z]+)?):\s*(.*)$", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def settings_file():
    return {k: v for k, v in read_kv(os.path.join(HOME, "settings")).items() if k in SETTINGS_KEYS}


def build_state():
    st = nimctl_json(["status", "--json"])
    conf = read_kv(os.path.join(HOME, "config"))
    st["config"] = {
        "nvidia_key": mask(conf.get("NVIDIA_API_KEY", "")),
        "models": {s: conf.get("MODEL_" + s.upper(), "") for s in SLOTS},
        "extra_models": conf.get("EXTRA_MODELS", "").split(),
        "ide_enabled": conf.get("IDE_ENABLED") == "1", "ide_autocomplete": conf.get("IDE_AUTOCOMPLETE") == "1",
        "search_enabled": conf.get("SEARCH_ENABLED") == "1", "web_enabled": conf.get("WEB_ENABLED") == "1",
        "chains": {s: conf.get("CHAIN_" + s.upper(), "").split() for s in SLOTS},
        "pool": {p: {"key": bool(conf.get(p.upper() + "_API_KEY")), "key_masked": mask(conf.get(p.upper() + "_API_KEY", "")),
                     "ranks": ((st.get("pool") or {}).get(p) or {}).get("ranks", [])} for p in PROVIDERS},
    }
    st["health"] = read_json(os.path.join(HOME, "health.json"), {}) or {}
    st["settings"] = settings_file()
    st["settings_keys"] = SETTINGS_KEYS
    st["env_overrides"] = sorted(k for k in SETTINGS_KEYS if k in os.environ)
    st["rpm"] = read_json(os.path.join(HOME, "rpm.json"), {})
    st["probes"] = probes()
    st["sizes"] = sizes()
    st["catalog"] = read_text(os.path.join(HOME, "models.cache")).split()
    st["pool_catalogs"] = {p: read_text(os.path.join(HOME, f"models.{p}.cache")).split() for p in PROVIDERS}
    st["candidates"] = candidates_file()
    st["bench"] = bench_last()
    st["workspace"] = read_text(os.path.join(HOME, "ide-workspace")).strip()
    st["state_file"] = read_kv(os.path.join(HOME, "state"))
    proxy_started = _num(read_text(os.path.join(HOME, "run", "proxy.started")).strip() or "0") or 0
    st["notices"] = {
        "config_changed": bool(st.get("proxy", {}).get("up")) and mtime(os.path.join(HOME, "litellm.yaml")) > proxy_started + 1,
        "proxy_started": proxy_started,
    }
    st["logs"] = {name: os.path.getsize(os.path.join(HOME, "logs", f)) if os.path.exists(os.path.join(HOME, "logs", f)) else 0
                  for name, f in LOGS.items()}
    st["systemd"] = {s: os.path.exists(os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "systemd", "user", f"nimctl-{s}.service"))
                     for s in SERVICES + ["watch"]}
    st["lang"] = LANG
    st["home"] = HOME
    st["bin"] = BIN
    st["web"] = st.get("web") or {}
    st["web"]["history_samples"] = len(HISTORY)
    st["busy"] = CURRENT.get("args") if CURRENT.get("proc") else None
    st["now"] = int(time.time())
    return st


# ── history: one sample every 30 s, for the charts ─────────────────────────────────────────────────────────
HISTORY = read_json(HISTORY_FILE, []) if os.path.exists(HISTORY_FILE) else []
if not isinstance(HISTORY, list):
    HISTORY = []
_hist_lock = threading.Lock()


def sample():
    stats = nimctl_json(["stats", "--json"], 30)
    rpm = read_json(os.path.join(HOME, "rpm.json"), {}) or {}
    req = stats.get("requests") or {}
    by = req.get("by_status") or {}
    rec = {"t": int(time.time()), "total": req.get("total", 0) if stats.get("data", True) else 0,
           "c2": by.get("2xx", 0), "c4": by.get("4xx", 0), "c429": by.get("429", 0), "c5": by.get("5xx", 0),
           "fallbacks": stats.get("fallbacks", 0), "throttled": stats.get("throttled", 0), "errors": stats.get("errors", 0),
           "budget": rpm.get("budget"), "free": rpm.get("free"), "waiting": rpm.get("waiting"),
           "fresh": bool(rpm.get("updated")) and time.time() - rpm.get("updated", 0) < 120}
    with _hist_lock:
        HISTORY.append(rec)
        del HISTORY[:-HISTORY_MAX]
        try:
            write_atomic(HISTORY_FILE, json.dumps(HISTORY, separators=(",", ":")))
        except OSError:
            pass


def sampler():
    while True:
        try:
            sample()
        except Exception as e:  # never let the sampler die
            log(f"sampler: {e}")
        time.sleep(SAMPLE_EVERY)


# ── running commands ───────────────────────────────────────────────────────────────────────────────────────
RUN_LOCK = threading.Lock()
CURRENT = {}


class Handler(BaseHTTPRequestHandler):
    server_version = "nimctl-web"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # only what matters: commands and errors (state polls would flood the log)
        if self.path.startswith("/api/run") or "40" in str(args[1:2]) or "50" in str(args[1:2]):
            log(f"{self.address_string()} {fmt % args}")

    # ── helpers ─────────────────────────────────────────────────────────────────────────────────────
    def send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, code, text, ctype="text/plain; charset=utf-8"):
        body = text.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def start_sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.end_headers()

    def sse(self, data, event=None):
        if event:
            self.wfile.write(f"event: {event}\n".encode())
        self.wfile.write(f"data: {json.dumps(data, ensure_ascii=False)}\n\n".encode())   # real glyphs in the console (✓ ✗ →)
        self.wfile.flush()

    def host_ok(self):
        host = (self.headers.get("Host") or "").split(":")[0].strip("[]").lower()
        if BIND not in ("127.0.0.1", "localhost", "::1"):
            return True                     # deliberately exposed with NIMCTL_BIND – the token still protects the API
        return host in ("127.0.0.1", "localhost", "::1")

    def auth_ok(self, query_token=None):
        tok = self.headers.get("X-Nimctl-Token") or query_token or ""   # EventSource cannot send headers: the log stream takes ?token=
        origin = self.headers.get("Origin")
        if origin and urlparse(origin).hostname not in ("127.0.0.1", "localhost", "::1", (self.headers.get("Host") or "").split(":")[0]):
            return False
        return hmac.compare_digest(tok, TOKEN)

    def body_json(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 1_000_000:
            return None
        try:
            return json.loads(self.rfile.read(n) or b"{}")
        except ValueError:
            return None

    # ── routing ─────────────────────────────────────────────────────────────────────────────────────
    def do_GET(self):
        if not self.host_ok():
            return self.send_text(403, "forbidden host")
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path in ("/", "/index.html"):
            page = read_text(os.path.join(WEB, "index.html"))
            page = page.replace("__TOKEN__", TOKEN).replace("__LANG__", LANG).replace("__PORT__", str(PORT))
            return self.send_text(200, page, "text/html; charset=utf-8")
        if u.path == "/health":
            return self.send_json(200, {"ok": True})
        if u.path == "/favicon.ico":
            return self.send_text(204, "")
        if not u.path.startswith("/api/"):
            return self.send_text(404, "not found")
        if not self.auth_ok((q.get("token") or [None])[0] if u.path == "/api/log/stream" else None):
            return self.send_json(403, {"error": "token"})
        try:
            if u.path == "/api/state":
                return self.send_json(200, cached("state", STATE_TTL, build_state))
            if u.path == "/api/stats":
                return self.send_json(200, cached("stats", STATE_TTL, lambda: nimctl_json(["stats", "--json"], 30)))
            if u.path == "/api/history":
                with _hist_lock:
                    return self.send_json(200, HISTORY)
            if u.path == "/api/candidates":
                return self.send_json(200, cached("cands", 30, lambda: nimctl_json(["web", "candidates"], 30)))
            if u.path == "/api/log":
                name = (q.get("name") or ["proxy"])[0]
                if name not in LOGS:
                    return self.send_json(400, {"error": "unknown log"})
                n = min(int((q.get("n") or ["200"])[0]), 5000)
                path = os.path.join(HOME, "logs", LOGS[name])
                return self.send_json(200, {"name": name, "lines": tail(path, n), "size": os.path.getsize(path) if os.path.exists(path) else 0})
            if u.path == "/api/log/stream":
                return self.stream_log((q.get("name") or ["proxy"])[0])
        except Exception as e:
            log(f"GET {u.path}: {e}")
            return self.send_json(500, {"error": str(e)})
        return self.send_json(404, {"error": "not found"})

    def do_POST(self):
        if not self.host_ok():
            return self.send_text(403, "forbidden host")
        u = urlparse(self.path)
        if not u.path.startswith("/api/") or not self.auth_ok():
            return self.send_json(403, {"error": "token"})
        body = self.body_json()
        if body is None:
            return self.send_json(400, {"error": "bad json"})
        try:
            if u.path == "/api/run":
                return self.run(body)
            if u.path == "/api/abort":
                return self.abort()
            if u.path == "/api/settings":
                return self.save_settings(body)
            if u.path == "/api/candidates":
                return self.save_candidates(body)
            if u.path == "/api/workspace":
                return self.set_workspace(body)
        except Exception as e:
            log(f"POST {u.path}: {e}")
            return self.send_json(500, {"error": str(e)})
        return self.send_json(404, {"error": "not found"})

    # ── endpoints ───────────────────────────────────────────────────────────────────────────────────
    def run(self, body):
        args = body.get("args")
        if not isinstance(args, list) or not args or not all(isinstance(a, str) and RE_ARG.match(a) for a in args):
            return self.send_json(400, {"error": "bad args"})
        if args[0] not in COMMANDS or len(args) > 12:
            return self.send_json(400, {"error": "command not allowed"})
        stdin_text = body.get("stdin") if isinstance(body.get("stdin"), str) else ""
        extra_env = {k: v for k, v in (body.get("env") or {}).items() if k in RUN_ENV_KEYS and isinstance(v, str)}
        env = base_env()
        env.update(extra_env)
        env["NIMCTL_YES"] = "0" if body.get("yes") is False else "1"
        env["NIMCTL_INTERACTIVE"] = "1" if stdin_text else "0"
        if not RUN_LOCK.acquire(blocking=False):
            return self.send_json(409, {"error": "busy", "running": CURRENT.get("args")})
        try:
            log(f"run: {' '.join(args)}" + (" (stdin)" if stdin_text else ""))
            proc = subprocess.Popen([BIN, *args], env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)
            CURRENT.update({"proc": proc, "args": args, "started": time.time()})
            invalidate()
            self.start_sse()
            self.sse({"args": args}, "start")
            try:
                proc.stdin.write(stdin_text + ("\n" if stdin_text and not stdin_text.endswith("\n") else ""))
            except OSError:
                pass
            try:
                proc.stdin.close()
            except OSError:
                pass
            try:
                for line in proc.stdout:
                    self.sse(line.rstrip("\n"))
            except (BrokenPipeError, ConnectionResetError):
                pass  # the browser went away – let the command finish on its own
            rc = proc.wait()
            invalidate()
            try:
                self.sse({"rc": rc, "seconds": round(time.time() - CURRENT["started"], 1)}, "exit")
            except (BrokenPipeError, ConnectionResetError):
                pass
        finally:
            CURRENT.clear()
            RUN_LOCK.release()

    def abort(self):
        proc = CURRENT.get("proc")
        if not proc:
            return self.send_json(200, {"aborted": False})
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except OSError:
            pass
        return self.send_json(200, {"aborted": True})

    def save_settings(self, body):
        values = body.get("settings")
        if not isinstance(values, dict):
            return self.send_json(400, {"error": "settings"})
        current = settings_file()
        for k, v in values.items():
            if k not in SETTINGS_KEYS or not isinstance(v, str) or not RE_VALUE.match(v) or len(v) > 300:
                return self.send_json(400, {"error": f"bad setting {k}"})
            if v.strip() == "":
                current.pop(k, None)
            else:
                current[k] = v.strip()
        text = "".join(f"{k}={current[k]}\n" for k in SETTINGS_KEYS if k in current)
        write_atomic(os.path.join(HOME, "settings"), text)
        invalidate()
        return self.send_json(200, {"settings": current, "restart": True})

    def save_candidates(self, body):
        values = body.get("candidates")
        if not isinstance(values, dict):
            return self.send_json(400, {"error": "candidates"})
        current = candidates_file()
        for k, v in values.items():
            if not RE_CAND_KEY.match(k or "") or not isinstance(v, str) or not RE_CAND_VAL.match(v) or len(v) > 500:
                return self.send_json(400, {"error": f"bad candidates {k}"})
            if v.strip() == "":
                current.pop(k, None)
            else:
                current[k] = " ".join(v.split())
        write_atomic(os.path.join(HOME, "candidates"), "".join(f"{k}: {v}\n" for k, v in current.items()))
        invalidate()
        return self.send_json(200, {"candidates": current})

    def set_workspace(self, body):
        d = body.get("dir")
        if not isinstance(d, str) or not d or "\n" in d:
            return self.send_json(400, {"error": "dir"})
        d = os.path.realpath(os.path.expanduser(d))
        if not os.path.isdir(d):
            return self.send_json(400, {"error": "not a directory"})
        write_atomic(os.path.join(HOME, "ide-workspace"), d + "\n")
        rc, out = nimctl(["ide", "config"], 60)
        invalidate()
        return self.send_json(200, {"dir": d, "rc": rc, "output": out[-2000:]})

    def stream_log(self, name):
        if name not in LOGS:
            return self.send_json(400, {"error": "unknown log"})
        path = os.path.join(HOME, "logs", LOGS[name])
        self.start_sse()
        try:
            for line in tail(path, 100):
                self.sse(line)
            pos = os.path.getsize(path) if os.path.exists(path) else 0
            while True:
                size = os.path.getsize(path) if os.path.exists(path) else 0
                if size < pos:
                    pos = 0             # truncated (proxy restart)
                    self.sse("", "truncated")
                if size > pos:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        f.seek(pos)
                        chunk = f.read()
                        pos = f.tell()
                    for line in chunk.splitlines():
                        self.sse(RE_ANSI.sub("", line))
                else:
                    self.sse("", "ping")
                    time.sleep(1.0)
        except (BrokenPipeError, ConnectionResetError, OSError):
            return


def main():
    if not os.path.exists(os.path.join(WEB, "index.html")):
        sys.exit("nimctl web: index.html missing – run nimctl web")
    threading.Thread(target=sampler, daemon=True).start()
    srv = ThreadingHTTPServer((BIND, PORT), Handler)
    srv.daemon_threads = True
    log(f"nimctl web UI on http://{BIND}:{PORT} (home {HOME}, nimctl {BIN})")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
