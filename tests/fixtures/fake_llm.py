#!/usr/bin/env python3
"""Scripted fake LLM endpoint for the test suite (test-only dependency).

Answers every POST with the next entry of a JSON script, repeating the last
entry once the script runs out, and appends one JSON line per request it saw
to --requests so a test can assert on exactly what the client sent.

Script entry: {"status": 200, "headers": {"retry-after": "0"}, "body": {...}}
"""
import argparse
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--script", required=True)
    ap.add_argument("--requests", required=True)
    ap.add_argument("--port-file", required=True)
    args = ap.parse_args()

    with open(args.script) as f:
        script = json.load(f)
    lock = threading.Lock()
    state = {"n": 0}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            raw = self.rfile.read(int(self.headers.get("content-length", 0)))
            try:
                body = json.loads(raw) if raw else None
            except ValueError:
                body = raw.decode("utf-8", "replace")
            with lock:
                entry = script[min(state["n"], len(script) - 1)]
                state["n"] += 1
                with open(args.requests, "a") as f:
                    f.write(json.dumps({
                        "path": self.path,
                        "headers": {k.lower(): v for k, v in self.headers.items()},
                        "body": body,
                    }) + "\n")
            payload = json.dumps(entry.get("body", {})).encode()
            self.send_response(entry.get("status", 200))
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(payload)))
            for k, v in entry.get("headers", {}).items():
                self.send_header(k, v)
            self.end_headers()
            self.wfile.write(payload)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(args.port_file, "w") as f:
        f.write(str(server.server_address[1]))
    server.serve_forever()


if __name__ == "__main__":
    main()
