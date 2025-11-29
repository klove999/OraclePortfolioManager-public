"""
seed_position.py — Oracle Portfolio Manager
Adds initial MSTR short put position to the SQLite registry.
"""

import sys
from pathlib import Path

# Ensure this script can import portfolio_registry.py from the same folder
HERE = Path(__file__).parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from portfolio_registry import add_position

# NOTE: Use your actual trade entry date here.
add_position(
    symbol="APLD",
    strategy="ShortPut",
    strike=31,
    expiration="2025-11-07",
    entry_price=1.64,
    mark=1.49,
    delta=0.28,
    entry_iv=129.06,
    current_iv=129.06,
    account_size=700000,
    entry_date="2025-10-27"  # <-- trade inception date
)

print("[OK] Position with entry date successfully added.")
