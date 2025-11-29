# analyze_positions.py
# Oracle Portfolio Manager v5.0.9
# Author: Oracle (for Kirk)
# Date: 2025-10-27

import pandas as pd
import datetime

def pct(a, b):
    try:
        return round(((a - b) / b) * 100, 2)
    except ZeroDivisionError:
        return 0.0

def analyze_portfolio(path):
    df = pd.read_csv(path)
    print("\n📊 Oracle Portfolio Manager — Portfolio Analysis")
    print("="*65)
    today = datetime.datetime.now()

    summary_rows = []
    for _, row in df.iterrows():
        dte = (pd.to_datetime(row.Expiration) - today).days
        iv_change = pct(row.CurrentIV, row.EntryIV)
        margin_usage = round((row.Strike * 100 / row.AccountSize) * 100, 2)
        breakeven = row.Strike - row.EntryPrice
        option_pnl = (row.EntryPrice - row.Mark) * 100

        results = {
            "Symbol": row.Symbol,
            "Delta": row.Delta,
            "IVΔ(%)": iv_change,
            "DTE": dte,
            "Margin%": margin_usage,
            "P/L($)": option_pnl,
            "Rule1": margin_usage <= 5,
            "Rule2": row.Delta <= 0.35,
            "Rule3": dte > 45,
            "Rule4": iv_change < 0,
            "Rule5": option_pnl >= 0.25 * row.EntryPrice * 100,
            "Rule6": row.Strike >= breakeven,
        }
        summary_rows.append(results)

    summary = pd.DataFrame(summary_rows)
    print(summary.to_string(index=False))
    print("="*65)
    print(f"Run date: {today:%Y-%m-%d %H:%M:%S}")
    return summary
