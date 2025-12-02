from __future__ import annotations

import sys
from pathlib import Path
from pprint import pprint

# Ensure repo root on sys.path
HERE = Path(__file__).resolve()
ROOT = HERE.parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from automation.python.brokers.schwab_auth import client_from_token


def main() -> None:
    c = client_from_token()
    print("Client type:", type(c))
    print("\nAvailable attributes on client:")
    attrs = sorted(dir(c))
    for name in attrs:
        print("  ", name)


if __name__ == "__main__":
    main()
