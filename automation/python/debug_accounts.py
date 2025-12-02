from __future__ import annotations

import sys
from pathlib import Path
from pprint import pprint

# --- Ensure repo root is on sys.path ----------------------------------------

# debug_accounts.py is in:  <repo_root>/automation/python/
# We want repo_root (the parent of "automation") on sys.path.
HERE = Path(__file__).resolve()
ROOT = HERE.parents[2]  # ../../ from automation/python => repo root

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Now we can import using absolute project-style imports
from automation.python.brokers.schwab_auth import client_from_token


def main() -> None:
    c = client_from_token()
    resp = c.get_accounts()

    print("STATUS:", resp.status_code)

    try:
        data = resp.json()
        print("RAW JSON:")
        pprint(data, width=140)
    except Exception as e:
        print("Failed to decode JSON:", e)
        try:
            print("TEXT:", resp.text[:1000])
        except Exception:
            pass


if __name__ == "__main__":
    main()
