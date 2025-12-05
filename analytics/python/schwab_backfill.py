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

# --- Helper functions ---------------------------------------------------------

def _parse_schwab_datetime(dt_str: str) -> Optional[datetime]:
    """
    Parse Schwab datetime strings like '2025-12-02T14:31:19+0000' or with 'Z'.

    Returns a timezone-aware datetime in UTC, or None on failure.
    """
    s = (dt_str or "").strip()
    if not s:
        return None

    # Handle trailing 'Z'
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    # Handle timezone like +0000 or -0500 (no colon)
    elif len(s) >= 5 and (s[-5] in "+-") and s[-2:].isdigit() and s[-3] != ":":
        # Convert ...+0000 → ...+00:00
        s = s[:-2] + ":" + s[-2:]

    try:
        return datetime.fromisoformat(s)
    except Exception:
        return None


def _parse_occ_option_symbol(symbol: str) -> Optional[tuple[date, float]]:
    """
    Parse an OCC-style option symbol like 'CORZ  251226P00015500'.

    Expected layout (21 chars):
      - 0:6   -> underlying padded (ignored here; we use underlyingSymbol)
      - 6:12  -> YYMMDD expiration
      - 12    -> 'C' or 'P'
      - 13:21 -> strike * 1000 as integer

    Returns (expiration_date, strike) or None if parsing fails.
    """
    s = symbol or ""
    if len(s) < 21:
        return None

    try:
        date_str = s[6:12]      # '251226'
        yy = int(date_str[0:2])
        mm = int(date_str[2:4])
        dd = int(date_str[4:6])
        year = 2000 + yy
        exp = date(year, mm, dd)

        strike_str = s[13:21]   # '00015500'
        strike_int = int(strike_str)
        strike = strike_int / 1000.0

        return exp, strike
    except Exception:
        return None


def derive_action_from_event(ev: TradeEvent) -> Optional[str]:
    """
    Map a TradeEvent's direction/open_close into a trades.action string.

    Heuristics:
      - OPENING + SELL -> SELL_OPEN
      - OPENING + BUY  -> BUY_OPEN
      - CLOSING + SELL -> SELL_CLOSE
      - CLOSING + BUY  -> BUY_CLOSE
      - UNKNOWN:
          * SELL -> SELL_OPEN   (assume opening short)
          * BUY  -> BUY_CLOSE   (assume closing short)
    """

    direction = (ev.direction or "").upper()
    oc = (ev.open_close or "").upper()

    # Normalize open/close base
    if oc == "OPENING":
        base = "OPEN"
    elif oc == "CLOSING":
        base = "CLOSE"
    else:
        # UNKNOWN or empty: apply domain-specific fallback
        if direction == "SELL":
            base = "OPEN"   # assume opening short
        elif direction == "BUY":
            base = "CLOSE"  # assume closing short
        else:
            return None

    # Normalize side
    if direction not in ("BUY", "SELL"):
        return None

    return f"{direction}_{base}"


# --- Schwab JSON → TradeEvent normalizer ------------------------------------


def normalize_orders_json(
    account_hash: str,
    raw: Any,
) -> List[TradeEvent]:
    """
    Convert Schwab's orders JSON into a list of TradeEvent objects.

    This version is tuned to Schwab's documented schema and your sample JSON:
      - Only includes FILLED orders.
      - Only includes legs where orderLegType/assetType indicate an OPTION.
      - Derives expiration and strike from OCC-style instrument.symbol if needed.
    """

    events: List[TradeEvent] = []

    if not isinstance(raw, list):
        return events

    for order in raw:
        status = str(order.get("status", "")).upper()
        if status != "FILLED":
            # Only record filled trades in the trades table.
            continue

        order_id = str(order.get("orderId", "")) if "orderId" in order else None

        entered_time_str = order.get("enteredTime") or order.get("closeTime")
        trade_dt = _parse_schwab_datetime(entered_time_str) if entered_time_str else None
        if trade_dt is None:
            continue

        legs = order.get("orderLegCollection") or []
        if not isinstance(legs, list):
            continue

        # Optional: derive a better fill price from orderActivityCollection
        fill_price: float = 0.0
        acts = order.get("orderActivityCollection") or []
        if isinstance(acts, list):
            for act in acts:
                if str(act.get("activityType", "")).upper() == "EXECUTION":
                    exec_legs = act.get("executionLegs") or []
                    if exec_legs:
                        try:
                            fill_price = float(exec_legs[0].get("price", 0.0) or 0.0)
                        except Exception:
                            pass
                        if fill_price > 0.0:
                            break
        if fill_price <= 0.0:
            # Fallback to order-level price if no execution price found
            try:
                fill_price = float(order.get("price", 0.0) or 0.0)
            except Exception:
                fill_price = 0.0

        for leg in legs:
            leg_type = str(leg.get("orderLegType", "")).upper()
            instr = leg.get("instrument") or {}
            asset_type = str(instr.get("assetType", "")).upper()

            # Skip non-option legs (equities, mutual funds, sweep vehicles, etc.)
            if "OPTION" not in leg_type and asset_type != "OPTION":
                continue

            put_call = instr.get("putCall")
            if not put_call:
                continue
            option_type = "CALL" if str(put_call).upper().startswith("C") else "PUT"

            underlying = instr.get("underlyingSymbol") or instr.get("symbol")
            if not underlying:
                continue

            # Attempt to get expiration & strike
            expiration: Optional[date] = None
            strike: Optional[float] = None

            # Preferred fields if present
            exp_str = instr.get("maturityDate") or instr.get("expirationDate")
            if exp_str:
                try:
                    exp_dt = _parse_schwab_datetime(exp_str)
                    if exp_dt is not None:
                        expiration = exp_dt.date()
                except Exception:
                    expiration = None

            raw_strike = instr.get("strikePrice")
            if raw_strike is not None:
                try:
                    strike = float(raw_strike)
                except Exception:
                    strike = None

            # Fallback: parse OCC-style symbol, e.g. 'CORZ  251226P00015500'
            if expiration is None or strike is None:
                occ_sym = instr.get("symbol")
                parsed = _parse_occ_option_symbol(occ_sym) if occ_sym else None
                if parsed is not None:
                    exp_from_sym, strike_from_sym = parsed
                    if expiration is None:
                        expiration = exp_from_sym
                    if strike is None:
                        strike = strike_from_sym

            if expiration is None or strike is None:
                # Can't meaningfully record this as an option trade without these
                continue

            try:
                quantity = abs(int(leg.get("quantity", 0) or 0))
            except Exception:
                quantity = 0
            if quantity <= 0:
                continue

            instruction = str(leg.get("instruction", "")).upper()
            if "BUY" in instruction:
                direction = "BUY"
            elif "SELL" in instruction:
                direction = "SELL"
            else:
                continue

            pos_effect = str(leg.get("positionEffect", "")).upper()
            if "OPEN" in pos_effect:
                open_close = "OPENING"
            elif "CLOSE" in pos_effect:
                open_close = "CLOSING"
            else:
                open_close = "UNKNOWN"

            # For now, commissions / fees = 0.0.
            # We will enrich these later from /accounts/{accountNumber}/transactions.
            commissions = 0.0
            fees = 0.0

            leg_id = str(leg.get("legId", "")) if "legId" in leg else None

            ev = TradeEvent(
                account_number=account_hash,
                symbol=underlying,
                option_type=option_type,
                strike=strike,
                expiration=expiration,
                direction=direction,
                open_close=open_close,
                quantity=quantity,
                price=fill_price,
                commissions=commissions,
                fees=fees,
                trade_datetime=trade_dt,
                underlying_price=None,  # can be enriched later
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
    positions (only OPEN/EXPIRED are updated). It also attempts to avoid
    duplicating trades by checking for an existing row with the same natural key.
    """
    # Derive normalized action like "SELL_OPEN", "BUY_CLOSE", etc.
    action = derive_action_from_event(ev)
    if action is None:
        print(f"[WARN] Skipping event with unknown action: {ev}")
        return

    # Compute signed contracts delta based on action and quantity.
    # Convention:
    #   - SELL_OPEN  : opening short  -> -quantity
    #   - BUY_OPEN   : opening long   -> +quantity
    #   - BUY_CLOSE  : closing short  -> +quantity (moves contracts back toward 0)
    #   - SELL_CLOSE : closing long   -> -quantity
    side, phase = action.split("_", 1)  # e.g. "SELL_OPEN" -> ("SELL", "OPEN")
    qty = int(ev.quantity)

    if phase == "OPEN":
        contracts_signed = qty if side == "BUY" else -qty
    else:  # phase == "CLOSE"
        contracts_signed = -qty if side == "SELL" else qty

    # Find or create the owning position id
    pos_id = find_or_create_position_id(conn, ev)

    cur = conn.cursor()

    trade_dt_str = ev.trade_datetime.strftime("%Y-%m-%dT%H:%M:%SZ")

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
            trade_dt_str,
            action,
            contracts_signed,
            ev.price,
        ),
    )
    existing = cur.fetchone()
    if existing:
        # Already recorded
        return

    print(
        f"[INFO] New trade: pos_id={pos_id}, action={action}, "
        f"contracts={contracts_signed}, price={ev.price}, dt={trade_dt_str}"
    )

    if not dry_run:
        # Insert trade row
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

        # Compute gross notional and credit/debit
        gross = abs(ev.quantity * ev.price * 100.0)
        total_comm_fees = ev.commissions + ev.fees

        if side == "SELL":
            credit = gross
            debit = 0.0
        else:
            credit = 0.0
            debit = gross

        # Update position contracts + totals
        # Only OPEN / EXPIRED positions are updated.
        cur.execute(
            """
            UPDATE positions
            SET contracts    = contracts + ?,
                total_credit = total_credit + ?,
                total_debit  = total_debit + ?,
                commissions  = commissions + ?,
                fees         = fees + ?,
                last_updated = ?
            WHERE id = ?
              AND status IN ('OPEN', 'EXPIRED')
            """,
            (
                contracts_signed,
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
