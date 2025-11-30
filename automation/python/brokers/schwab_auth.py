"""
schwab_auth.py

Manual OAuth helper for Schwab using schwab-py.

This module does:
  - Read Schwab API credentials + callback URL + token path from environment.
  - Walk you through a manual OAuth login flow (copy/paste URL).
  - Write a token file to SCHWAB_TOKEN_PATH.
  - Provide a helper to build a client from that token later.

It does NOT touch your database.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Optional, Any

from schwab import auth, client  # type: ignore[import]


ENV_API_KEY = "SCHWAB_API_KEY"
ENV_APP_SECRET = "SCHWAB_APP_SECRET"
ENV_CALLBACK_URL = "SCHWAB_CALLBACK_URL"
ENV_TOKEN_PATH = "SCHWAB_TOKEN_PATH"


class SchwabAuthError(RuntimeError):
    """Raised when Schwab authentication configuration is invalid."""


def _get_env(name: str, required: bool = True) -> Optional[str]:
    value = os.environ.get(name)
    if required and not value:
        raise SchwabAuthError(f"Missing required environment variable: {name}")
    return value


def get_token_path() -> Path:
    token_path = _get_env(ENV_TOKEN_PATH, required=True)
    path = Path(token_path).expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def manual_login_flow() -> client.Client:
    """
    Run Schwab's manual OAuth login flow using schwab.auth.client_from_manual_flow.

    This will:
      - Print a login URL for you to open in a browser.
      - After you log in and see a blank or error page at https://127.0.0.1:8182/?code=...,
        you copy the FULL URL from your browser address bar.
      - Paste that URL when prompted in the terminal.
      - The function will trade that code for a token and save it to SCHWAB_TOKEN_PATH.

    Returns:
      An authenticated schwab.client.Client instance.
    """
    api_key = _get_env(ENV_API_KEY, required=True)
    app_secret = _get_env(ENV_APP_SECRET, required=True)
    callback_url = _get_env(ENV_CALLBACK_URL, required=True)
    token_path = get_token_path()

    print("[INFO] Starting Schwab manual OAuth flow.")
    print("[INFO] Using callback URL:", callback_url)
    print("[INFO] Token will be saved to:", token_path)

    c = auth.client_from_manual_flow(
        api_key=api_key,
        app_secret=app_secret,
        callback_url=callback_url,
        token_path=str(token_path),
        asyncio=False,
        enforce_enums=True,
    )

    print("[OK] Token created and saved.")
    return c


def client_from_token() -> client.Client:
    """
    Build a client from an existing token file.

    Use this AFTER manual_login_flow has succeeded at least once.
    """
    api_key = _get_env(ENV_API_KEY, required=True)
    app_secret = _get_env(ENV_APP_SECRET, required=True)
    token_path = get_token_path()

    if not token_path.exists():
        raise SchwabAuthError(
            f"Token file does not exist at {token_path}. "
            "Run manual_login_flow() first."
        )

    c = auth.client_from_token_file(
        token_path=str(token_path),
        api_key=api_key,
        app_secret=app_secret,
        asyncio=False,
        enforce_enums=True,
    )
    return c

def _print_accounts_response(resp: Any) -> None:
    """
    Helper to inspect and print the result of client.get_accounts() safely.
    Schwab methods return httpx.Response objects, not lists, so we must call
    .json() before looking at the data.
    """
    try:
        status = resp.status_code
    except AttributeError:
        print("[WARN] get_accounts() did not return an HTTP response object.")
        print(f"[INFO] Raw object: {resp!r}")
        return

    print(f"[INFO] get_accounts() status: {status}")

    try:
        data = resp.json()
    except Exception as e:
        print(f"[WARN] Could not decode accounts JSON: {e}")
        try:
            print("[DEBUG] Raw response text:")
            print(resp.text)
        except Exception:
            pass
        return

    # Data is a list of account records in your case.
    if isinstance(data, list):
        print(f"[INFO] Retrieved {len(data)} account record(s) (list).")
        for item in data:
            sa = item.get("securitiesAccount") or {}
            acct_id = sa.get("accountNumber", "?")
            acct_type = sa.get("type", "")
            # Optionally mask the account number for display:
            if isinstance(acct_id, str) and len(acct_id) > 4:
                masked = "****" + acct_id[-4:]
            else:
                masked = acct_id
            print(f"  - {masked}  [{acct_type}]")
    elif isinstance(data, dict):
        print("[INFO] get_accounts() returned a dict; top-level keys:")
        print("   ", list(data.keys()))
    else:
        print(f"[INFO] get_accounts() returned JSON of type {type(data)}.")
        print("      Value:", data)


def smoke_accounts_manual() -> None:
    """
    Connectivity check using the manual flow (first-time setup).
    """
    c = manual_login_flow()
    resp = c.get_accounts()
    _print_accounts_response(resp)
    print("[OK] Schwab connectivity test (manual) completed.")


def smoke_accounts_from_token() -> None:
    """
    Connectivity check using an existing token file (no login needed).
    """
    c = client_from_token()
    resp = c.get_accounts()
    _print_accounts_response(resp)
    print("[OK] Schwab connectivity test (from token) completed.")


if __name__ == "__main__":
    try:
        print("[STEP] Schwab manual auth smoke test starting...")
        smoke_accounts_manual()
    except SchwabAuthError as e:
        print(f"[ERROR] Schwab auth configuration error: {e}")
    except Exception as e:
        print(f"[ERROR] Schwab auth runtime error: {e}")
