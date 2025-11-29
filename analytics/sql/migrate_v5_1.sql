-- =========================================================
-- Oracle Portfolio Manager v5.1 - Schema Migration
-- =========================================================
-- Creates or updates all core data tables:
--   positions, trades, greeks_log
-- =========================================================
PRAGMA foreign_keys = ON;
-- =========================================================
-- 1. POSITIONS TABLE
-- =========================================================
CREATE TABLE IF NOT EXISTS "positions"(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    strategy TEXT,
    contracts INTEGER DEFAULT 0,
    status TEXT DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED', 'ROLLED', 'EXPIRED')),
    strike REAL,
    expiration TEXT,
    age INTEGER,
    dte INTEGER,
    entry_price REAL,
    mark REAL,
    total_credit REAL DEFAULT 0.0,
    total_debit REAL DEFAULT 0.0,
    commissions REAL DEFAULT 0.0,
    fees REAL DEFAULT 0.0,
    pnl REAL DEFAULT 0.0,
    delta REAL,
    theta REAL,
    vega REAL,
    gamma REAL,
    rho REAL,
    entry_iv REAL,
    -- entry implied volatility
    iv REAL,
    -- current implied volatility
    iv_rank REAL,
    iv_pctl REAL,
    account_size REAL,
    entry_date TEXT,
    date_closed TEXT,
    date_added TEXT DEFAULT CURRENT_TIMESTAMP,
    last_updated TEXT DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);
-- =========================================================
-- 2. TRADES TABLE
-- =========================================================
CREATE TABLE IF NOT EXISTS "trades" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    position_id INTEGER,
    trade_date TEXT NOT NULL,
    action TEXT CHECK(
        action IN (
            'BUY_OPEN',
            'SELL_OPEN',
            'BUY_CLOSE',
            'SELL_CLOSE',
            'ROLL'
        )
    ) NOT NULL,
    contracts INTEGER NOT NULL,
    price REAL NOT NULL,
    commissions REAL DEFAULT 0.0,
    fees REAL DEFAULT 0.0,
    underlying_price REAL,
    notes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(position_id) REFERENCES positions(id)
);
-- =========================================================
-- 3. GREEKS LOG TABLE
-- =========================================================
CREATE TABLE IF NOT EXISTS "greeks_log" (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    position_id INTEGER REFERENCES positions(id) ON DELETE CASCADE,
    log_time TEXT DEFAULT (datetime('now')),
    delta REAL,
    gamma REAL,
    theta REAL,
    vega REAL,
    rho REAL,
    iv REAL,
    iv_rank REAL,
    iv_pctl REAL,
    underlying_price REAL,
    mark REAL,
    comments TEXT,
    FOREIGN KEY(position_id) REFERENCES positions(id)
);
-- =========================================================
-- 4. INDEXES FOR PERFORMANCE
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_positions_symbol ON positions(symbol);
CREATE INDEX IF NOT EXISTS idx_trades_position_id ON trades(position_id);
CREATE INDEX IF NOT EXISTS idx_greeks_log_position_id ON greeks_log(position_id);
-- =========================================================
-- 5. SMOKE TEST SEED DATA (OPTIONAL)
-- =========================================================
-- Uncomment the following lines for CI pipeline seeding
-- INSERT INTO positions (symbol, strategy, strike, expiration, entry_price, mark, delta, iv, entry_date, contracts)
-- VALUES ('AAPL', 'ShortPut', 180.0, '2025-12-19', 2.45, 1.95, -0.25, 30.2, '2025-10-15', 1);
-- INSERT INTO trades (position_id, trade_date, trade_type, contracts, price, commissions, fees)
-- VALUES (1, '2025-10-15', 'SELL_TO_OPEN', 1, 2.45, 0.65, 0.15);
