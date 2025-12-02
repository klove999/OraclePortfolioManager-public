"""
schwab_client.py

Read-only Schwab client helpers for Oracle Portfolio Manager.

This module builds on schwab_auth.client_from_token() and exposes
higher-level functions to fetch:

  - accounts
  - positions (per account)
  - orders/trades since a given date

All functions are *read-only* and return raw JSON from Schwab.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from .schwab_auth import client_from_token  # same package


def get_http_client():
    """
    Return an authenticated Schwab HTTP client using the saved token.
    """
    return client_from_token()


def get_accounts_raw() -> Any:
    """
    Return the raw HTTP response JSON for all accounts.
    """
    c = get_http_client()
    resp = c.get_accounts()
    resp.raise_for_status()
    return resp.json()


def get_account_numbers() -> List[str]:
    """
    Convenience helper: extract accountNumbers from account JSON.
    """
    data = get_accounts_raw()
    numbers: List[str] = []
    if isinstance(data, list):
        for item in data:
            sa = item.get("securitiesAccount") or {}
            acct = sa.get("accountNumber")
            if isinstance(acct, str):
                numbers.append(acct)
    return numbers


def get_positions_raw(account_number: str) -> Any:
    """
    Fetch raw positions JSON for a specific account.
    Schwab's endpoint name / shape may vary; adapt as needed.
    """
    c = get_http_client()
    # Placeholder; you will likely need to adjust the method name/params
    resp = c.get_account_details(account_number, fields="positions")
    resp.raise_for_status()
    return resp.json()


from datetime import datetime
from typing import Any, Dict, List, Optional

from .schwab_auth import client_from_token  # already there


def get_http_client():
    """
    Return an authenticated Schwab HTTP client using the saved token.
    """
    return client_from_token()


from datetime import datetime, timezone, timedelta
from typing import Any, Optional

from .schwab_auth import client_from_token


def get_http_client():
    return client_from_token()


def _to_utc_iso_z(dt: datetime) -> str:
    """
    Convert a datetime to Schwab's expected ISO-8601 with Z suffix:
      yyyy-MM-dd'T'HH:mm:ss.sssZ

    We normalise to UTC and set milliseconds to .000 for simplicity.
    """
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)

    # Format with .000Z millis
    return dt.strftime("%Y-%m-%dT%H:%M:%S.000Z")


# automation/python/brokers/schwab_client.py

from __future__ import annotations

import datetime as dt
from typing import Any, Dict, List, Optional

from schwab.client import Client  # type: ignore

from .schwab_auth import client_from_token


def get_orders_raw(
    account_hash: str,
    since: Optional[dt.datetime] = None,
    until: Optional[dt.datetime] = None,
    status: Optional[str] = None,
    max_results: int = 200,
) -> List[Dict[str, Any]]:
    """
    Fetch raw Schwab orders for a given account using schwab-py's
    Client.get_orders_for_account(...) API.

    Parameters
    ----------
    account_hash : str
        Schwab account hash (NOT the raw account number).
    since : datetime, optional
        Lower bound on order entry time (UTC or timezone-aware).
    until : datetime, optional
        Upper bound on order entry time (UTC or timezone-aware).
    status : str, optional
        Optional single status filter (e.g. 'FILLED', 'WORKING', etc.).
    max_results : int
        Maximum number of orders to retrieve.

    Returns
    -------
    list[dict]
        Raw JSON objects returned by Schwab for each order.
    """
    c = client_from_token()

    # Build kwargs using schwab-py's expected parameter names
    kwargs: Dict[str, Any] = {}

    if max_results is not None:
        kwargs["max_results"] = max_results

    if since is not None:
        # schwab-py accepts datetime objects and converts them as needed.
        kwargs["from_entered_datetime"] = since

    if until is not None:
        kwargs["to_entered_datetime"] = until

    if status:
        # Try to map to Client.Order.Status enum if possible; otherwise pass raw string.
        try:
            kwargs["status"] = Client.Order.Status[status]
        except (KeyError, AttributeError):
            kwargs["status"] = status

    # NOTE: account_hash should already be the Schwab account hash, not the raw number.
    resp = c.get_orders_for_account(account_hash, **kwargs)
    resp.raise_for_status()
    data = resp.json()

    # The API may return a dict or list depending on context; normalize to list.
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    return []
