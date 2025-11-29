import sqlite3, json
from pathlib import Path
from datetime import datetime, timezone
from brokers.schwab_client import SchwabClient

DB = Path("data/portfolio.db")

def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def upsert_trade(conn, pos_id, when_utc, action, contracts, price, commiss=0.0, fees=0.0, u_price=None, notes=None):
    conn.execute("""
        INSERT INTO trades(position_id, trade_datetime, action, contracts, price, commissions, fees, underlying_price, notes)
        VALUES(?,?,?,?,?,?,?,?,?)
    """, (pos_id, when_utc, action, contracts, price, commiss, fees, u_price, notes))
    conn.commit()

def upsert_position_from_broker(conn, payload):
    # Map Schwab payload → positions schema (pseudo, adjust mapping)
    symbol   = payload["symbol"]
    strategy = payload.get("strategy","ShortPut")
    strike   = float(payload["strike"])
    expiry   = payload["expiration"]      # ISO (UTC)
    status   = "OPEN" if payload["open"] else "CLOSED"
    contracts= int(payload["contracts"])
    entry_dt = payload["entry_datetime"]  # ISO (UTC)
    entry_px = float(payload["entry_price"])
    mark     = float(payload.get("mark", entry_px))

    conn.execute("""
        INSERT INTO positions(symbol, strategy, contracts, status, strike, expiration, entry_price, mark, entry_date, last_updated)
        VALUES(?,?,?,?,?,?,?,?,?,datetime('now'))
        ON CONFLICT(symbol, strategy, strike, expiration) DO UPDATE SET
            contracts=excluded.contracts,
            status=excluded.status,
            mark=excluded.mark,
            last_updated=datetime('now')
    """, (symbol, strategy, contracts, status, strike, expiry, entry_px, mark, entry_dt))
    conn.commit()

def main():
    conn = sqlite3.connect(DB)
    client = SchwabClient(
        client_id    = "<YOUR_CLIENT_ID>",
        redirect_uri = "http://127.0.0.1:8751/callback",
        token_path   = str(Path.home()/".oracle_portfolio/schwab_tokens.json")
    )

    # Example: import positions & orders per account
    accounts = client.get_accounts()
    for acct in accounts:
        acct_id = acct["account_id"]  # adjust field name
        # Positions
        for pos in client.get_positions(acct_id):
            upsert_position_from_broker(conn, pos)

        # Orders/trades → convert to trades rows
        orders = client.get_orders(acct_id)
        for od in orders:
            # map Schwab order to: position_id, trade_datetime, action, contracts, price, commissions, fees, underlying_price
            # you'll need a symbol/strike/expiry match to find position_id
            pass

    conn.close()

if __name__ == "__main__":
    main()
