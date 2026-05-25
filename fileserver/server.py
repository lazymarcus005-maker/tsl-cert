import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


CERTS_DIR = Path("/certs")
STATE_DIR = Path("/state")
HOST = "0.0.0.0"
PORT = 80
SCHEDULE = [
    {"case": "valid", "duration_seconds": 300},
    {"case": "expired", "duration_seconds": 120},
    {"case": "notyet", "duration_seconds": 120},
    {"case": "wronghost", "duration_seconds": 120},
    {"case": "selfsigned", "duration_seconds": 120},
    {"case": "untrustedca", "duration_seconds": 120},
    {"case": "weakkey", "duration_seconds": 120},
    {"case": "wrongusage", "duration_seconds": 120},
    {"case": "wildcard", "duration_seconds": 120},
    {"case": "revoked", "duration_seconds": 120},
]


def load_rotation():
    rotation_path = STATE_DIR / "rotation.json"
    current_path = STATE_DIR / "current"
    default = {
        "current_case": "valid",
        "next_case": "expired",
        "duration_seconds": 300,
        "started_at_epoch": int(time.time()),
        "cycle_total_minutes": 23,
        "schedule": SCHEDULE,
    }

    if rotation_path.exists():
        with rotation_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        data.setdefault("schedule", SCHEDULE)
        data.setdefault("cycle_total_minutes", 23)
        data.setdefault("duration_seconds", 300)
        data.setdefault("started_at_epoch", int(time.time()))
        return data

    if current_path.exists():
        current_case = current_path.read_text(encoding="utf-8").strip() or "valid"
        default["current_case"] = current_case
        return default

    return default


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/status":
            self.serve_status()
            return
        if self.path == "/ca.crt":
            self.serve_file(CERTS_DIR / "ca" / "ca.crt", "application/x-x509-ca-cert")
            return
        if self.path == "/ca.mobileconfig":
            self.serve_file(CERTS_DIR / "ca" / "ca.mobileconfig", "application/x-apple-aspen-config")
            return

        self.send_response(404)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"error","message":"Not found"}')

    def serve_status(self):
        data = load_rotation()
        now = int(time.time())
        elapsed = max(0, now - int(data["started_at_epoch"]))
        remaining = max(0, int(data["duration_seconds"]) - elapsed)

        payload = {
            "current_case": data["current_case"],
            "next_case": data["next_case"],
            "next_in_seconds": remaining,
            "duration_seconds": data["duration_seconds"],
            "cycle_total_minutes": data["cycle_total_minutes"],
            "schedule": data["schedule"],
        }

        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def serve_file(self, path: Path, content_type: str):
        if not path.exists():
            self.send_response(404)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"error","message":"File not found"}')
            return

        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        if os.environ.get("ROTATION_LOG", "true") == "true":
            super().log_message(fmt, *args)


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    server.serve_forever()
