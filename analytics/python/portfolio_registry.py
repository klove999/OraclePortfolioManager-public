#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Oracle Portfolio Manager v5
Portfolio Registry + Analytics Module
-------------------------------------
Analyzes positions, computes returns and risk metrics,
and outputs an aligned table and portfolio summary.
"""

import os
import sqlite3
import datetime as dt
import pandas as pd
from colorama import init, Fore, Style

init(autoreset=True)

DB_PATH = r"D:\Documents\OraclePortfolioManager\data\portfolio.db"

# --------------------------------------------------------------------
# Utility functions
# --------------------------------------------------------------------
def fetch_positions():
    """Load all open positions from the SQLite database."""
    if not os.path.exists(DB_PATH):
        print(f"[ERROR] Database not found at {DB_PATH}")
        return pd.DataFrame()

    conn = sqlite3.connect(DB_PATH)
    df = pd.read_sql_query("SELECT * FROM positions", conn)
    conn.close()
    return df


def analyze_position(row):
    """Compute analytics for a single position record."""
    try:
        entry_price = float(row.get("entry_price") or 0.0)
        mark = float(row.get("mark") or 0.0)
        contracts = float(row.get("contracts") or 1.0)
        account_size = float(row.get("account_size") or 1.0)
        entry_iv = float(row.get("entry_iv") or 0.0)
        iv = float(row.get("iv") or 0.0)
        delta = float(row.get("delta") or 0.0)

        entry_date = dt.datetime.strptime(row["entry_date"], "%Y-%m-%d").date()
        today = dt.date.today()
        age_days = (today - entry_date).days

        # P/L and Returns
        pl = (entry_price - mark) * contracts * 100
        ret_pct = (pl / (abs(entry_price * 100 * contracts))) * 100 if entry_price != 0 else 0.0
        exposure = abs(entry_price * 100 * contracts)
        credit = entry_price * 100 * contracts

        # Annualized return (cap extreme)
        ann_ret = 0.0
        if age_days > 0:
            ann_ret = ((1 + ret_pct / 100) ** (365 / age_days) - 1) * 100
        ann_ret = max(min(ann_ret, 500), -500)

        # IV metrics
        if entry_iv > 0:
            iv_change_pct = ((iv / entry_iv) - 1.0) * 100.0
        else:
            iv_change_pct = 0.0
        iv_change_pct = round(iv_change_pct, 2)

        # Return on capital
        roc = (pl / (exposure - credit)) * 100 if (exposure - credit) != 0 else 0.0
        ann_roc = 0.0
        if age_days > 0:
            ann_roc = ((1 + roc / 100) ** (365 / age_days) - 1) * 100
        ann_roc = max(min(ann_roc, 500), -500)

        return {
            "Symbol": row.get("symbol", ""),
            "Strategy": row.get("strategy", ""),
            "Contracts": int(contracts),
            "Entry Date": row.get("entry_date", ""),
            "Age (days)": age_days,
            "DTE": row.get("expiration", ""),
            "Entry IV %": round(entry_iv * 100, 2),
            "IV %": round(iv * 100, 2),
            "IV Δ %": iv_change_pct,
            "Δ": round(delta, 2),
            "P/L ($)": round(pl, 2),
            "Return %": round(ret_pct, 2),
            "Ann. Ret %": round(ann_ret, 2),
            "Credit ($)": round(credit, 2),
            "Exposure ($)": round(exposure, 2),
            "ROC %": round(roc, 2),
            "Ann. ROC %": round(ann_roc, 2),
            "Exposure %": round(exposure / account_size * 100, 2) if account_size > 0 else 0.0,
        }
    except Exception as e:
        print(f"[WARN] Failed to analyze {row.get('symbol','?')}: {e}")
        return None


def color_iv_change(v):
    """Color-code IV compression/expansion."""
    try:
        x = float(v)
    except Exception:
        return v
    s = f"{x:.2f}".rstrip("0").rstrip(".")
    if x <= -5:
        return f"{Fore.GREEN}{s}{Style.RESET_ALL}"
    if x >= 5:
        return f"{Fore.RED}{s}{Style.RESET_ALL}"
    return f"{Fore.YELLOW}{s}{Style.RESET_ALL}"


# --------------------------------------------------------------------
# Summary calculations
# --------------------------------------------------------------------
def summarize(df):
    """Generate portfolio summary metrics."""
    total_credit = df["Credit ($)"].sum()
    total_pl = df["P/L ($)"].sum()
    total_exposure = df["Exposure ($)"].sum()
    total_net_cap = total_exposure - total_credit

    port_ret = (total_pl / total_exposure) * 100 if total_exposure != 0 else 0.0
    roc = (total_pl / total_net_cap) * 100 if total_net_cap != 0 else 0.0
    avg_age = df["Age (days)"].mean()

    ann_ret = ((1 + port_ret / 100) ** (365 / avg_age) - 1) * 100 if avg_age > 0 else 0
    ann_roc = ((1 + roc / 100) ** (365 / avg_age) - 1) * 100 if avg_age > 0 else 0

    t_bill = 3.76
    excess_ret = ann_ret - t_bill

    summary = f"""
============================================================
📊 Portfolio Summary (Benchmark Comparison)
------------------------------------------------------------
Total Credit ($)           : {total_credit:,.2f}
Total P/L ($)              : {total_pl:,.2f}
Total Exposure ($)         : {total_exposure:,.2f}
Total Net Capital ($)      : {total_net_cap:,.2f}
Portfolio Return (%)       : {port_ret:,.2f}
Total Return on Capital (%) : {roc:,.2f}
Average Age (days)         : {avg_age:,.2f}
Annualized Return (%)      : {min(max(ann_ret, -500), 500):.2f}
Annualized ROC (%)         : {min(max(ann_roc, -500), 500):.2f}
3M T-Bill Benchmark        : {t_bill:.2f}%
Excess Return (%)          : {excess_ret:.2f}
============================================================
"""
    print(summary)


# --------------------------------------------------------------------
# Main execution
# --------------------------------------------------------------------
def run():
    df = fetch_positions()
    if df.empty:
        print("[WARN] No positions found.")
        return

    analysis = [analyze_position(r) for _, r in df.iterrows()]
    analysis = [a for a in analysis if a is not None]
    if not analysis:
        print("[WARN] No valid analyses.")
        return

    out = pd.DataFrame(analysis)

    # Apply color to IV Δ %
    out["IV Δ %"] = out["IV Δ %"].apply(color_iv_change)

    cols = [
        "Symbol","Strategy","Contracts","Entry Date","Age (days)","DTE",
        "Entry IV %","Curr IV %","IV Δ %","Δ",
        "P/L ($)","Return %","Ann. Ret %",
        "Credit ($)","Exposure ($)",
        "ROC %","Ann. ROC %","Exposure %"
    ]

    disp = out[cols].copy()

    print(disp.to_string(index=False))
    summarize(out)


if __name__ == "__main__":
    run()
