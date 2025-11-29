import os, time, json, webbrowser
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import requests
from datetime import datetime, timezone, timedelta

AUTH_BASE = "https://api.schwab.com/oauth2"
API_BASE  = "https://api.schwab.com/v1"

class SchwabClient:
    def __init__(self, client_id:str, redirect_uri:str, token_path:str):
        self.client_id = client_id
        self.redirect_uri = redirect_uri
        self.token_path = token_path
        self.session = requests.Session()
        self.tokens = self._load_tokens()

    # ---------- OAuth basics ----------
    def _load_tokens(self):
        if os.path.exists(self.token_path):
            with open(self.token_path, "r", encoding="utf-8") as f:
                return json.load(f)
        return {}

    def _save_tokens(self):
        os.makedirs(os.path.dirname(self.token_path), exist_ok=True)
        with open(self.token_path, "w", encoding="utf-8") as f:
            json.dump(self.tokens, f, indent=2)

    def _expired(self):
        t = self.tokens.get("expires_at")
        if not t: return True
        return datetime.now(timezone.utc) >= datetime.fromisoformat(t.replace("Z","+00:00"))

    def ensure_token(self):
        if not self.tokens:
            self._interactive_auth()
        elif self._expired():
            self._refresh()
        self.session.headers.update({"Authorization": f"Bearer {self.tokens['access_token']}"})

    def _interactive_auth(self):
        # Authorization Code flow (exact URLs/params depend on Schwab’s spec)
        auth_url = (
            f"{AUTH_BASE}/authorize"
            f"?response_type=code&client_id={self.client_id}"
            f"&redirect_uri={self.redirect_uri}"
            f"&scope=read"
        )
        print("[INFO] Opening browser for Schwab authorization...")
        webbrowser.open(auth_url)

        code = self._wait_for_code()
        # Exchange for tokens (adjust endpoint per Schwab docs)
        resp = requests.post(f"{AUTH_BASE}/token", data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": self.redirect_uri,
            "client_id": self.client_id
        })
        resp.raise_for_status()
        data = resp.json()
        self._ingest_token_response(data)

    def _refresh(self):
        resp = requests.post(f"{AUTH_BASE}/token", data={
            "grant_type": "refresh_token",
            "refresh_token": self.tokens["refresh_token"],
            "client_id": self.client_id
        })
        resp.raise_for_status()
        data = resp.json()
        self._ingest_token_response(data)

    def _ingest_token_response(self, data):
        # Normalized structure; adjust keys per Schwab payload
        access = data["access_token"]
        refresh = data.get("refresh_token", self.tokens.get("refresh_token"))
        expires_in = int(data.get("expires_in", 3600))
        exp_at = (datetime.now(timezone.utc) + timedelta(seconds=expires_in)).strftime("%Y-%m-%dT%H:%M:%SZ")
        self.tokens = {"access_token": access, "refresh_token": refresh, "expires_at": exp_at}
        self._save_tokens()

    # Simple local HTTP server to capture code
    def _wait_for_code(self):
        code_holder = {"code": None}
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self_inner):
                q = parse_qs(urlparse(self_inner.path).query)
                code_holder["code"] = q.get("code", [None])[0]
                self_inner.send_response(200); self_inner.end_headers()
                self_inner.wfile.write(b"Schwab auth complete. You can close this tab.")
        host, port = urlparse(self.redirect_uri).hostname, urlparse(self.redirect_uri).port
        with HTTPServer((host, port), Handler) as httpd:
            while not code_holder["code"]:
                httpd.handle_request()
            return code_holder["code"]

    # ---------- Example data calls (adjust endpoints/fields per docs) ----------
    def get_accounts(self):
        self.ensure_token()
        r = self.session.get(f"{API_BASE}/accounts")
        r.raise_for_status()
        return r.json()

    def get_orders(self, account_id, from_utc=None, to_utc=None):
        self.ensure_token()
        params = {}
        if from_utc: params["from"] = from_utc
        if to_utc:   params["to"]   = to_utc
        r = self.session.get(f"{API_BASE}/accounts/{account_id}/orders", params=params)
        r.raise_for_status()
        return r.json()

    def get_positions(self, account_id):
        self.ensure_token()
        r = self.session.get(f"{API_BASE}/accounts/{account_id}/positions")
        r.raise_for_status()
        return r.json()
