"""
data_quality.py

Lightweight data-quality helpers for Oracle Portfolio Manager.

This module is intentionally small and CI-safe. It provides:

    - filter_and_log(df, conn=None, label="default")

so that it can be called either as:

    df = filter_and_log(df)

or (in more advanced flows):

    df = filter_and_log(df, conn, label="live_run")

Without a database connection, it simply applies basic sanity filters
and returns the cleaned DataFrame.
"""

from __future__ import annotations

from typing import Optional
import pandas as pd


def filter_and_log(
    df: pd.DataFrame,
    conn: Optional[object] = None,
    label: str = "default",
) -> pd.DataFrame:
    """
    Basic data-quality filter for live_update.

    Parameters
    ----------
    df : pandas.DataFrame
        Portfolio or live data snapshot. Expected columns might include:
        - delta
        - iv
        - mark
        but this function is defensive and will only touch columns that exist.
    conn : optional
        Optional DB connection handle (e.g., sqlite3.Connection). Currently
        unused; reserved for future logging/auditing.
    label : str
        Optional label for future logging context.

    Returns
    -------
    pandas.DataFrame
        A cleaned copy of the DataFrame with obviously bad values nulled out.
    """
    if df is None or df.empty:
        return df

    df = df.copy()

    # Clean delta if present
    if "delta" in df.columns:
        def clean_delta(x):
            # Replace clearly invalid placeholders with None
            if x in (None, 0, 0.0, "0", "0.0"):
                return None
            try:
                # Clamp to a reasonable range if wildly out of bounds
                val = float(x)
                if val < -5 or val > 5:
                    return None
                return val
            except Exception:
                return None

        df["delta"] = df["delta"].apply(clean_delta)

    # Clean iv if present
    if "iv" in df.columns:
        def clean_iv(x):
            if x in (None, 0, 0.0):
                return None
            try:
                val = float(x)
                if val < 0 or val > 10:  # 0–1000% implied vol; generous cap
                    return None
                return val
            except Exception:
                return None

        df["iv"] = df["iv"].apply(clean_iv)

    # Clean mark if present
    if "mark" in df.columns:
        def clean_mark(x):
            if x in (None, 0, 0.0):
                return None
            try:
                val = float(x)
                if val < 0:
                    return None
                return val
            except Exception:
                return None

        df["mark"] = df["mark"].apply(clean_mark)

    # Future: if conn is provided, we could log anomalies to a table.
    # For now, we keep this CI-safe and side-effect free.

    return df
