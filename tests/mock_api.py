#!/usr/bin/env python3
"""Mock of NVIDIA's OpenAI-compatible endpoint for nimctl tests.
Simulates: valid/invalid keys, a listed-but-dead model (404 Function not found),
a very slow model (kimi-k3), and normal fast models."""
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

KEY = "nvapi-testkey"
MODELS = ["deepseek-ai/deepseek-v4-pro-0813", "deepseek-ai/deepseek-v4-flash-0731", "moonshotai/kimi-k3",
          "moonshotai/kimi-k2.6", "nvidia/nemotron-3-super-120b", "nvidia/nemotron-3.5-lightning-30b-a3b",
          "poolside/laguna-xs-2.1", "nvidia/nemotron-3-ultra-550b-a55b", "zai-org/glm-5.3", "meta/llama-4-maverick-17b-128e-instruct"]
DEAD = {"moonshotai/kimi-k2.6"}
SLOW = {"moonshotai/kimi-k3": 40, "nvidia/nemotron-3-ultra-550b-a55b": 1.5, "deepseek-ai/deepseek-v4-pro-0813": 0.6}

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj):
        self.send_response(code); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(json.dumps(obj).encode())
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
        time.sleep(SLOW.get(m, 0.05))
        self._send(200, {"choices": [{"message": {"content": f"Moin from {m}."}}], "usage": {"total_tokens": 42}})

if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
