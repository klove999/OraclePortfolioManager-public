"""
live_update.py — Oracle Portfolio Manager
Version : v5.4.4
Author  : Oracle (for Kirk)
Date    : 2025-11-01

Cycle:
1) Pull latest option mark, IV, and delta (Yahoo Finance) for each DB position
2) Update SQLite
3) Run portfolio_registry.py to refresh analytics & exports

Hardenings:
- Single-run guard (prevents accidental double invocation)
- ASCII-only console output (sanitizes subprocess output)
- UTF-8-safe logging to file
- Missing-greeks tolerant (delta may be absent -> 0.0 with WARN)
"""

import os
import sqlite3
from datetime import datetime
from pathlib import Path
from loguru import logger
import time
import subprocess
import yfinance as yf
from colorama import init, Fore, Style
import pandas as pd
from data_quality import filter_and_log

# ==========================================
# Resolve base directory and database path
# ==========================================
def resolve_db_path():
    """
    Determine the absolute path to the database file.
    Priority:
      1. ORACLE_DB_PATH (explicit override from environment)
      2. Default: <repo_root>/data/portfolio.db
    """
    env_path = os.getenv("ORACLE_DB_PATH")
    if env_path:
        db_path = Path(env_path)
        # Make relative paths resolve from the repo root, not the automation folder
        if not db_path.is_absolute():
            db_path = Path(__file__).resolve().parents[2] / db_path
        logger.info(f"[CI] Using ORACLE_DB_PATH override: {db_path}")
        return db_path.resolve()

    # Default local fallback
    return Path(__file__).resolve().parents[2] / "data" / "portfolio.db"

# Resolve and print
DB_PATH = resolve_db_path()
print(f"[INFO] Database path resolved to: {DB_PATH}")

# Ensure the parent folder exists
DB_PATH.parent.mkdir(parents=True, exist_ok=True)

# Ensure database exists before connecting
if not DB_PATH.exists():
    print(f"[WARN] No database found at {DB_PATH}. Creating placeholder...")
    sqlite3.connect(DB_PATH).close()

# -------- Init --------
init(autoreset=True)

BASE_DIR = Path(__file__).resolve().parents[2]
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

LOG_FILE = LOG_DIR / f"live_updates_{datetime.now().strftime('%Y%m%d')}.txt"
PORTFOLIO_SCRIPT = BASE_DIR / "analytics" / "portfolio_registry.py"

# ---------- Utilities ----------
def to_ascii(s: str) -> str:
    """Return a best-effort ASCII-only version of s (drops non-ASCII)."""
    try:
        return s.encode("ascii", "ignore").decode("ascii")
    except Exception:
        return s  # last resort

def log(msg, color=None):
    """UTF-8 log to console + file; keep console ASCII-safe."""
    stamp = datetime.now().strftime("%H:%M:%S")
    text = f"[{stamp}] {to_ascii(str(msg))}"
    try:
        if color:
            print(color + text + Style.RESET_ALL)
        else:
            print(text)
    finally:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(text + "\n")

# ---------- Core pull ----------
def update_position(symbol, strike, expiration):
    """Fetch latest mark, IV, delta from Yahoo Finance, tolerant to missing greeks."""
    try:
        t = yf.Ticker(symbol)
        if expiration not in (t.options or []):
            log(f"{symbol} — expiration {expiration} not found in available chains.", Fore.YELLOW)
            return None

        chain = t.option_chain(expiration)
        puts = chain.puts
        match = puts[puts["strike"].round(2) == round(float(strike), 2)]
        if match.empty:
            log(f"{symbol} {strike}P not found in {expiration} puts.", Fore.YELLOW)
            return None

        row = match.iloc[0]
        mark = float(row.get("lastPrice", 0.0) or 0.0)
        iv   = float(row.get("impliedVolatility", 0.0) or 0.0)
        dlt  = row.get("delta", 0.0)

        try:
            delta = float(0.0 if pd.isna(dlt) else dlt)
        except Exception:
            delta = 0.0

        if delta == 0.0:
            log(f"{symbol} {strike}P missing delta; defaulted to 0.0", Fore.YELLOW)

        log(f"{symbol} {strike}P -> mark={mark:.2f}, IV={iv:.3f}, d={delta:.2f}", Fore.GREEN)
        return mark, iv, delta

    except Exception as e:
        log(f"{symbol} {strike}P update failed: {e}", Fore.RED)
        return None

# ---------- DB helpers ----------
def get_positions():
    conn = sqlite3.connect(DB_PATH)
    try:
        df = pd.read_sql_query("SELECT id, symbol, strike, expiration FROM positions", conn)
    finally:
        conn.close()
    return df

df = fetch_live_data()
df = filter_and_log(df, conn)

def update_db(row_id, mark, iv, delta):
    conn = sqlite3.connect(DB_PATH)
    try:
        cur = conn.cursor()
        cur.execute(
            """
            UPDATE positions
            SET mark=?, iv=?, delta=?, last_updated=?
            WHERE id=?
            AND status NOT IN ('CLOSED', 'ROLLED')
            """,
            (mark, iv, delta, datetime.now().strftime("%Y-%m-%d %H:%M:%S"), int(row_id)),
        )
        conn.commit()
    finally:
        conn.close()

# ---------- Orchestrator ----------
def run_portfolio_refresh():
    log("Running portfolio_registry.py for live analytics...", Fore.CYAN)
    try:
        env = os.environ.copy()
        env["PYTHONIOENCODING"] = "utf-8"
        env["ORACLE_LIVE_ACTIVE"] = "1"  # guard: prevent recursion

        result = subprocess.run(
            ["python", str(PORTFOLIO_SCRIPT)],
            capture_output=True,
            text=True,
            env=env,
            timeout=180,
        )

        if result.returncode == 0:
            log("Portfolio analysis completed successfully.", Fore.GREEN)
            # Print only a short, ASCII-sanitized tail to avoid mojibake
            tail = "\n".join(to_ascii(result.stdout).splitlines()[-100:])
            if tail.strip():
                log(tail, Fore.WHITE)
        else:
            err_tail = "\n".join(to_ascii(result.stderr).splitlines()[-20:])
            log(f"Portfolio analysis failed:\n{err_tail}", Fore.RED)

    except Exception as e:
        log(f"Error running portfolio_registry.py: {e}", Fore.RED)

# ---------- Main ----------
def run():
    # Double-run guard
    if os.environ.get("ORACLE_LIVE_ACTIVE") == "1":
        log("Duplicate invocation detected; skipping recursive run.", Fore.YELLOW)
        return
    os.environ["ORACLE_LIVE_ACTIVE"] = "1"

    log("=== Oracle Live Data Sync + Analytics ===", Fore.CYAN)

    df = get_positions()
    if df.empty:
        log("No positions found in database.", Fore.YELLOW)
        return

    for _, pos in df.iterrows():
        res = update_position(pos["symbol"], pos["strike"], pos["expiration"])
        if res:
            mark, iv, delta = res
            update_db(pos["id"], mark, iv, delta)
            time.sleep(1.2)  # polite rate-limit

    log("All positions updated in database.", Fore.GREEN)
    run_portfolio_refresh()
    log("=== Sync + Analytics Cycle Complete ===", Fore.CYAN)

if __name__ == "__main__":
    run()
