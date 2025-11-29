"""
data_quality.py
----------------
Validates and safeguards live market data before it is applied to the portfolio.
Ensures that updates to `positions` and `greeks_log` meet minimum numeric and
integrity standards to preserve data quality.

Author: Oracle Portfolio Manager (v5.0.1)
"""

import sqlite3
import pandas as pd
from datetime import datetime, timezone

VALID_RANGES = {
    "delta": (-1.0, 1.0),
    "iv": (0.01, 5.0),
    "gamma": (-10.0, 10.0),
    "theta": (-10.0, 10.0),
    "vega": (-10.0, 10.0),
    "rho": (-10.0, 10.0),
}

def validate_numeric(value, min_val, max_val):
    """Ensure numeric values fall within acceptable range."""
    if value is None:
        return False
    try:
        val = float(value)
        return min_val <= val <= max_val
    except (ValueError, TypeError):
        return False


def validate_row(row: dict) -> bool:
    """Validate one row of fetched data."""
    if row.get("mark", 0) <= 0:
        return False
    for field, (low, high) in VALID_RANGES.items():
        if field in row and not validate_numeric(row[field], low, high):
            return False
    return True


def quality_audit(df: pd.DataFrame) -> pd.DataFrame:
    """
    Inspect a DataFrame of fetched data and return valid rows only.
    Adds a 'valid' column for logging.
    """
    if df.empty:
        return df

    df["valid"] = df.apply(
        lambda x: validate_row(x.to_dict()),
        axis=1
    )
    return df


def log_invalid_rows(df: pd.DataFrame, log_path="logs/data_quality_warnings.log"):
    """Append all invalid rows to a local log file with UTC timestamp."""
    if df.empty:
        return
    invalids = df[df["valid"] == False]
    if invalids.empty:
        return
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(f"\n[{ts}] Invalid rows detected ({len(invalids)})\n")
        f.write(invalids.to_string(index=False))
        f.write("\n")


def filter_and_log(df: pd.DataFrame, conn: sqlite3.Connection) -> pd.DataFrame:
    """
    Full validation pipeline:
    - Validates numeric ranges
    - Logs rejected rows
    - Returns only rows that passed all checks
    """
    if df.empty:
        return df
    audited = quality_audit(df)
    log_invalid_rows(audited[audited["valid"] == False])
    valid_df = audited[audited["valid"] == True].drop(columns=["valid"], errors="ignore")
    return valid_df


if __name__ == "__main__":
    print("[INFO] Data quality module initialized.")
    print(f"[INFO] Validation ranges: {VALID_RANGES}")
