# trade_registry.py
# Oracle Portfolio Manager v5.0.9
# Author: Oracle (for Kirk)
# Date: 2025-10-27

import pandas as pd
from pathlib import Path
import datetime

class TradeRegistry:
    """Manages active short option positions in the Oracle Portfolio Manager."""

    def __init__(self, registry_path=None):
        default_path = Path.home() / "Documents" / "OraclePortfolioManager" / "portfolio.csv"
        self.registry_path = Path(registry_path) if registry_path else default_path
        self.columns = [
            "Symbol", "Strategy", "Strike", "Expiration",
            "EntryPrice", "Mark", "EntryIV", "CurrentIV",
            "Delta", "AccountSize", "OpenDate"
        ]
        self._load_or_initialize()

    def _load_or_initialize(self):
        if self.registry_path.exists():
            self.df = pd.read_csv(self.registry_path)
        else:
            self.df = pd.DataFrame(columns=self.columns)
            self.df.to_csv(self.registry_path, index=False)

    def add_trade(self, **kwargs):
        """Adds or updates a trade in the registry."""
        trade = {col: kwargs.get(col, None) for col in self.columns}
        df = self.df[self.df["Symbol"] != trade["Symbol"]]
        self.df = pd.concat([df, pd.DataFrame([trade])], ignore_index=True)
        self.save()

    def remove_trade(self, symbol):
        """Removes a trade by symbol."""
        self.df = self.df[self.df["Symbol"] != symbol]
        self.save()

    def save(self):
        self.df.to_csv(self.registry_path, index=False)

    def list_trades(self):
        """Displays the registry in a clean table."""
        print("\n📘 Current Portfolio Registry\n" + "="*50)
        print(self.df.to_string(index=False))
        print("="*50)

    def export_excel(self, output_path=None):
        """Exports registry to Excel."""
        output = Path(output_path) if output_path else self.registry_path.with_suffix(".xlsx")
        self.df.to_excel(output, index=False)
        print(f"[OK] Exported registry to {output}")
