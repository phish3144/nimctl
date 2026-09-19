#!/usr/bin/env python3
"""Mock of NVIDIA's OpenAI-compatible endpoint for nimctl tests – or, with a provider name as second argument,
of a pool provider (Groq, Cerebras) with its own key and catalog.
Simulates: valid/invalid keys, a listed-but-dead model (404 Function not found), a very slow model (kimi-k3),
a cold model (first call slow), an overloaded model (429 worker limit), tool calling (some models cannot),
and streaming (SSE) for the bench command."""
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEY = "nvapi-testkey"
MODELS = ["deepseek-ai/deepseek-v4-pro-0813", "deepseek-ai/deepseek-v4-flash-0731", "moonshotai/kimi-k3",
          "moonshotai/kimi-k2.6", "nvidia/nemotron-3-super-120b", "nvidia/nemotron-3.5-lightning-30b-a3b",
          "poolside/laguna-xs-2.1", "nvidia/nemotron-3-ultra-550b-a55b", "zai-org/glm-5.3",
          "meta/llama-4-maverick-17b-128e-instruct", "mistralai/mistral-medium-3-notools", "nvidia/nemotron-stall-headers",
          "nvidia/nemotron-3-nano-30b-a3b", "nvidia/nv-embedqa-e5-v5"]
DEAD = {"moonshotai/kimi-k2.6"}
SLOW = {"moonshotai/kimi-k3": 40, "nvidia/nemotron-3-ultra-550b-a55b": 1.5, "nvidia/nemotron-stall-headers": 40}
STALL_HEADERS = {"nvidia/nemotron-stall-headers"}   # streaming: headers first, then 40 s of silence before the first chunk
COLD = {"deepseek-ai/deepseek-v4-pro-0813": 5}   # first call sleeps this long, later calls are fast
OVERLOADED = {"poolside/laguna-xs-2.1"}
NO_TOOLS = {"mistralai/mistral-medium-3-notools", "nvidia/nemotron-3.5-lightning-30b-a3b"}  # answer in prose, never call tools
CTX = {"nvidia/nemotron-3-nano-30b-a3b": 8192}   # context window: a bigger request gets the OpenAI-style 400
TPM = {  # free-tier tokens per minute of the mocked providers: a single request above the limit gets Groq's 413
    "groq": {"llama-3.3-70b-versatile": 12000, "llama-3.1-8b-instant": 6000, "openai/gpt-oss-120b": 8000, "openai/gpt-oss-20b": 8000, "qwen/qwen3-32b": 6000, "groq/compound": 70000, "moonshotai/kimi-k2-instruct-0905": 10000},
    "cerebras": {"llama-3.3-70b": 60000, "llama3.1-8b": 60000, "gpt-oss-120b": 60000, "qwen-3-235b-a22b-instruct-2507": 60000},
}
PROVIDERS = {  # nimctl pool: key and catalog of the mocked provider
    "groq": ("gsk_testkey_0123456789", ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3-32b", "groq/compound", "moonshotai/kimi-k2-instruct-0905"]),
    "cerebras": ("csk-testkey-0123456789", ["llama-3.3-70b", "llama3.1-8b", "gpt-oss-120b", "qwen-3-235b-a22b-instruct-2507"]),
    "mistral": ("mstr_testkey_0123456789", ["mistral-medium-latest", "mistral-small-latest", "devstral-medium-2507", "magistral-medium-latest", "mistral-large-latest", "codestral-latest", "mistral-embed", "mistral-moderation-latest"]),
}
LIMITS = {}
if len(sys.argv) > 2:
    KEY, MODELS = PROVIDERS[sys.argv[2]]; LIMITS = TPM.get(sys.argv[2], {})
seen = set()

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        try:
            self.send_response(code); self.send_header("Content-Type", "application/json"); self.end_headers()
            self.wfile.write(json.dumps(obj).encode())
        except (BrokenPipeError, ConnectionResetError):
            pass
    def _auth(self): return self.headers.get("Authorization") == f"Bearer {KEY}"
    def do_GET(self):
        if not self._auth(): return self._send(401, {"error": {"message": "unauthorized"}})
        if self.path.endswith("/models"): return self._send(200, {"data": [{"id": m} for m in MODELS]})
        self._send(404, {})
    def do_POST(self):
        if not self._auth(): return self._send(401, {"error": {"message": "unauthorized"}})
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        m = body["model"]
        if m in DEAD: return self._send(404, {"detail": "Function 'abc': Not found for account 'xyz'"})
        if m not in MODELS: return self._send(404, {"error": {"message": f"model {m} not found"}})
        if m in OVERLOADED: return self._send(429, {"error": {"message": "ResourceExhausted: Worker local total request limit reached (32/32)"}})
        est = sum(len(str(x.get("content") or "")) for x in body.get("messages", [])) // 4 + 20   # rough token count of the request
        if m in CTX and est > CTX[m]:
            return self._send(400, {"error": {"message": f"This model's maximum context length is {CTX[m]} tokens. However, you requested {est} tokens ({est - 5} in the messages, 5 in the completion). Please reduce the length of the messages or completion.", "type": "invalid_request_error", "code": "context_length_exceeded"}})
        if m in LIMITS and est > LIMITS[m]:
            return self._send(413, {"error": {"message": f"Request too large for model `{m}` in organization `org_test` service tier `on_demand` on tokens per minute (TPM): Limit {LIMITS[m]}, Requested {est}, please reduce your message size and try again. Need more tokens? Upgrade to Dev Tier.", "type": "tokens", "code": "rate_limit_exceeded"}})
        if m in COLD and m not in seen: seen.add(m); time.sleep(COLD[m])
        wants_tools = bool(body.get("tools")) and m not in NO_TOOLS
        if body.get("stream") and m in STALL_HEADERS:
            return self._stream(m, wants_tools, stall=SLOW[m])
        time.sleep(SLOW.get(m, 0.05))
        if body.get("stream"):
            return self._stream(m, wants_tools)
        if wants_tools:
            msg = {"role": "assistant", "content": None,
                   "tool_calls": [{"id": "call_1", "type": "function", "function": {"name": body["tools"][0]["function"]["name"], "arguments": json.dumps({"path": "README.md"})}}]}
            return self._send(200, {"choices": [{"message": msg, "finish_reason": "tool_calls"}], "usage": {"prompt_tokens": 30, "completion_tokens": 12, "total_tokens": 42}})
        self._send(200, {"choices": [{"message": {"role": "assistant", "content": f"Moin from {m}."}, "finish_reason": "stop"}],
                         "usage": {"prompt_tokens": 30, "completion_tokens": 12, "total_tokens": 42}})
    def _stream(self, m, wants_tools, stall=0):
        try:
            self.send_response(200); self.send_header("Content-Type", "text/event-stream"); self.end_headers(); self.wfile.flush()
            if stall: time.sleep(stall)
            words = f"Moin from {m}. This is a streamed answer with a few tokens.".split()
            for i, w in enumerate(words):
                chunk = {"choices": [{"delta": {"content": w + " "}, "index": 0, "finish_reason": None}]}
                self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode()); self.wfile.flush(); time.sleep(0.02)
            final = {"choices": [{"delta": {}, "index": 0, "finish_reason": "stop"}], "usage": {"prompt_tokens": 30, "completion_tokens": len(words), "total_tokens": 30 + len(words)}}
            self.wfile.write(f"data: {json.dumps(final)}\n\ndata: [DONE]\n\n".encode()); self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
