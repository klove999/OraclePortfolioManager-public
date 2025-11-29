"""
update_contracts.py — update contract count for an existing position.
"""

import sqlite3
from pathlib import Path

db_path = Path(r"D:\Documents\Oracle_Portfolio_Manager_v5\data\portfolio.db")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

symbol = "CLSK"
expiration = "2025-11-14"
new_contracts = 4

cur.execute("""
    UPDATE positions
    SET contracts = ?, last_updated = datetime('now')
    WHERE symbol = ? AND expiration = ?;
""", (new_contracts, symbol, expiration))

conn.commit()
print(f"[OK] Updated {symbol} {expiration} to {new_contracts} contract(s).")
conn.close()
