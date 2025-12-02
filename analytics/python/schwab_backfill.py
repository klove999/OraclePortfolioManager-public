"""
schwab_backfill.py

Backfill and sync trades/positions from Schwab into the local SQLite DB.

Usage (examples):
  python -m analytics.python.schwab_backfill --since 2025-09-30
  python -m analytics.python.schwab_backfill --since 2025-12-01 --account XXXX9514 --dry-run
"""

from __future__ import annotations

import argparse
import sqlite3
from dataclasses import dataclass
from datetime import datetime, date
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from automation.python.brokers import schwab_client


# --- Data model for a normalized trade event ---------------------------------


@dataclass
class TradeEvent:
    account_number: str
    symbol: str           # underlying symbol, e.g. "MSTR"
    option_type: str      # "CALL" or "PUT"
    strike: float
    expiration: date
    direction: str        # "BUY" or "SELL"
    open_close: str       # "OPENING" or "CLOSING"
    quantity: int         # positive integer, contracts
    price: float          # price per contract
    commissions: float
    fees: float
    trade_datetime: datetime
    underlying_price: Optional[float]
    schwab_order_id: Optional[str]
    schwab_leg_id: Optional[str]


# --- DB helpers --------------------------------------------------------------


def get_db_path() -> Path:
    """
    Resolve the DB path relative to repo root by default.

    You can later override this with an env var if needed.
    """
    here = Path(__file__).resolve()
    root = here.parents[2]  # repo root
    return root / "data" / "portfolio.db"


def connect_db(db_path: Optional[Path] = None) -> sqlite3.Connection:
    path = db_path or get_db_path()
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


# --- Schwab JSON → TradeEvent normalizer ------------------------------------


def normalize_orders_json(
    account_number: str,
    raw: Any,
) -> List[TradeEvent]:
    """
    Convert Schwab's orders JSON into a list of TradeEvent objects.

    This function is intentionally defensive and may need tuning based on
    the exact shape of Schwab's response in your environment.
    """
    events: List[TradeEvent] = []

    if not isinstance(raw, list):
        # Many Schwab endpoints return a list of orders
        return events

    for order in raw:
        order_id = str(order.get("orderId", "")) if "orderId" in order else None
        # Example fields; adjust as you inspect Schwab's JSON for orders/legs
        entered_time_str = order.get("enteredTime") or order.get("closeTime")
        if not entered_time_str:
            continue

        try:
            trade_dt = datetime.fromisoformat(entered_time_str.replace("Z", "+00:00"))
        except Exception:
            # Skip orders with unparseable timestamps
            continue

        order_legs = order.get("orderLegCollection") or []
        for leg in order_legs:
            instrument = leg.get("instrument") or {}
            asset_type = instrument.get("assetType")
            if asset_type not in ("OPTION", "OPTION_CONTRACT"):
                # skip non-option legs for now
                continue

            put_call = instrument.get("putCall") or instrument.get("optionType")
            option_type = "CALL" if str(put_call).upper().startswith("C") else "PUT"

            symbol = instrument.get("underlyingSymbol") or instrument.get("symbol")
            strike = float(instrument.get("strikePrice", 0.0))
            exp_str = instrument.get("maturityDate") or instrument.get("expirationDate")
            try:
                expiration = datetime.fromisoformat(exp_str).date()
            except Exception:
                # Fallback/skip if expiration is missing/invalid
                continue

            quantity = abs(int(leg.get("quantity", 0)))
            if quantity <= 0:
                continue

            instruction = str(leg.get("instruction", "")).upper()
            if "BUY" in instruction:
                direction = "BUY"
            elif "SELL" in instruction:
                direction = "SELL"
            else:
                # Unknown instruction; skip
                continue

            oc = str(leg.get("positionEffect", "")).upper()
            if "OPEN" in oc:
                open_close = "OPENING"
            elif "CLOSE" in oc:
                open_close = "CLOSING"
            else:
                open_close = "UNKNOWN"

            # Price / executions: simplify to averagePrice if present
            price = float(order.get("price", order.get("averagePrice", 0.0)) or 0.0)

            # Commissions/fees: these fields may be nested; tune as needed
            commissions = float(order.get("orderCommission", 0.0) or 0.0)
            fees = float(order.get("orderFee", 0.0) or 0.0)

            underlying_price = None  # optional for now; can be filled later

            leg_id = str(leg.get("legId", "")) if "legId" in leg else None

            ev = TradeEvent(
                account_number=account_number,
                symbol=symbol,
                option_type=option_type,
                strike=strike,
                expiration=expiration,
                direction=direction,
                open_close=open_close,
                quantity=quantity,
                price=price,
                commissions=commissions,
                fees=fees,
                trade_datetime=trade_dt,
                underlying_price=underlying_price,
                schwab_order_id=order_id,
                schwab_leg_id=leg_id,
            )
            events.append(ev)

    return events


# --- TradeEvent → DB mapping -------------------------------------------------


def map_event_to_action_and_contracts(ev: TradeEvent) -> Tuple[str, int]:
    """
    Map direction + open/close into your trades.action + signed contracts.

    Rules (based on your conventions):
      - SELL_OPEN  -> action='SELL_OPEN',  contracts = -quantity
      - BUY_OPEN   -> action='BUY_OPEN',   contracts = +quantity
      - BUY_CLOSE  -> action='BUY_CLOSE',  contracts = +quantity
      - SELL_CLOSE -> action='SELL_CLOSE', contracts = -quantity
    """
    q = ev.quantity

    if ev.direction == "SELL" and ev.open_close == "OPENING":
        return "SELL_OPEN", -q
    if ev.direction == "BUY" and ev.open_close == "OPENING":
        return "BUY_OPEN", q
    if ev.direction == "BUY" and ev.open_close == "CLOSING":
        return "BUY_CLOSE", q
    if ev.direction == "SELL" and ev.open_close == "CLOSING":
        return "SELL_CLOSE", -q

    # Fallback: treat unknown as no-op; you may prefer to log instead
    return "UNKNOWN", q


def find_or_create_position_id(conn: sqlite3.Connection, ev: TradeEvent) -> int:
    """
    Find an existing OPEN position matching this event, or create a new one.

    Match key:
      - symbol
      - strategy (ShortPut / ShortCall / LongPut / LongCall)
      - strike
      - expiration
      - status != 'CLOSED' and != 'ROLLED'

    Strategy mapping:
      - ShortPut  : SELL + PUT
      - ShortCall : SELL + CALL
      - LongPut   : BUY  + PUT
      - LongCall  : BUY  + CALL
    """
    if ev.direction == "SELL" and ev.option_type == "PUT":
        strategy = "ShortPut"
    elif ev.direction == "SELL" and ev.option_type == "CALL":
        strategy = "ShortCall"
    elif ev.direction == "BUY" and ev.option_type == "PUT":
        strategy = "LongPut"
    else:
        strategy = "LongCall"

    cur = conn.cursor()
    cur.execute(
        """
        SELECT id FROM positions
        WHERE symbol = ?
          AND strategy = ?
          AND strike = ?
          AND expiration = ?
          AND status IN ('OPEN', 'EXPIRED')
        ORDER BY id ASC
        """,
        (ev.symbol, strategy, ev.strike, ev.expiration.isoformat()),
    )
    row = cur.fetchone()
    if row:
        return row["id"]

    # No open position found; create a new one.
    # We'll initialize minimal fields and let other scripts enrich later.
    entry_date = ev.trade_datetime.strftime("%Y-%m-%dT%H:%M:%SZ")
    cur.execute(
        """
        INSERT INTO positions
          (symbol, strategy, contracts, status, strike, expiration,
           entry_price, mark, total_credit, total_debit,
           commissions, fees, entry_date, last_updated)
        VALUES
          (?, ?, ?, 'OPEN', ?, ?,
           ?, ?, ?, ?,
           ?, ?, ?, ?)
        """,
        (
            ev.symbol,
            strategy,
            0,  # we'll update contracts below
            ev.strike,
            ev.expiration.isoformat(),
            ev.price,
            ev.price,
            0.0,
            0.0,
            0.0,
            0.0,
            entry_date,
            entry_date,
        ),
    )
    conn.commit()
    return cur.lastrowid


def apply_trade_event_to_db(conn: sqlite3.Connection, ev: TradeEvent, dry_run: bool = True) -> None:
    """
    Insert a trade row (if new) and update the corresponding position.

    This function is intentionally conservative and avoids touching CLOSED/ROLLED
    positions. It also attempts to avoid duplicating trades by checking for an
    existing row with the same natural key.
    """
    action, contracts_signed = map_event_to_action_and_contracts(ev)
    if action == "UNKNOWN":
        print(f"[WARN] Skipping event with unknown action: {ev}")
        return

    pos_id = find_or_create_position_id(conn, ev)

    cur = conn.cursor()

    # Check for an existing identical trade (natural key)
    cur.execute(
        """
        SELECT id FROM trades
        WHERE position_id = ?
          AND trade_datetime = ?
          AND action = ?
          AND contracts = ?
          AND price = ?
        """,
        (
            pos_id,
            ev.trade_datetime.strftime("%Y-%m-%dT%H:%M:%SZ"),
            action,
            contracts_signed,
            ev.price,
        ),
    )
    existing = cur.fetchone()
    if existing:
        # Already recorded
        return

    trade_dt_str = ev.trade_datetime.strftime("%Y-%m-%dT%H:%M:%SZ")

    print(f"[INFO] New trade: pos_id={pos_id}, action={action}, contracts={contracts_signed}, "
          f"price={ev.price}, dt={trade_dt_str}")

    if not dry_run:
        cur.execute(
            """
            INSERT INTO trades
              (position_id, trade_datetime, action, contracts,
               price, commissions, fees, underlying_price, notes)
            VALUES
              (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                pos_id,
                trade_dt_str,
                action,
                contracts_signed,
                ev.price,
                ev.commissions,
                ev.fees,
                ev.underlying_price,
                "Imported from Schwab",
            ),
        )

        # Update position contracts + totals
        # SELL_OPEN / SELL_CLOSE => credit; BUY_* => debit
        delta_contracts = contracts_signed
        gross = abs(ev.quantity * ev.price * 100.0)
        total_comm_fees = ev.commissions + ev.fees

        if action in ("SELL_OPEN", "SELL_CLOSE"):
            credit = gross
            debit = 0.0
        else:
            credit = 0.0
            debit = gross

        cur.execute(
            """
            UPDATE positions
            SET contracts = contracts + ?,
                total_credit = total_credit + ?,
                total_debit = total_debit + ?,
                commissions = commissions + ?,
                fees = fees + ?,
                last_updated = ?
            WHERE id = ?
              AND status IN ('OPEN', 'EXPIRED')
            """,
            (
                delta_contracts,
                credit,
                debit,
                ev.commissions,
                ev.fees,
                trade_dt_str,
                pos_id,
            ),
        )

        conn.commit()


# --- CLI entry point ---------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Backfill Schwab option trades into the local portfolio DB."
    )
    parser.add_argument(
        "--since",
        required=True,
        help="Start date (YYYY-MM-DD) for fetching orders from Schwab.",
    )
    parser.add_argument(
        "--account",
        help="Specific Schwab accountNumber to sync (default: all).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done, but do not modify the DB.",
    )

    args = parser.parse_args()

    since_date = datetime.fromisoformat(args.since).replace(hour=0, minute=0, second=0, microsecond=0)

    conn = connect_db()

    if args.account:
        account_numbers = [args.account]
    else:
        account_numbers = schwab_client.get_account_numbers()

    print(f"[INFO] Backfill starting. Since={since_date.isoformat()}, accounts={account_numbers}, dry_run={args.dry_run}")

    for acct in account_numbers:
        print(f"[STEP] Fetching orders for account {acct}...")
        raw_orders = schwab_client.get_orders_raw(acct, since=since_date)
        events = normalize_orders_json(acct, raw_orders)
        print(f"[INFO] Normalized {len(events)} trade event(s) for account {acct}.")

        for ev in events:
            apply_trade_event_to_db(conn, ev, dry_run=args.dry_run)

    print("[DONE] Schwab backfill completed.")


if __name__ == "__main__":
    main()
