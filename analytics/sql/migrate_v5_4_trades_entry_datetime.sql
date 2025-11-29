-- ===============================================
-- v5.4 – Trades table: rename trade_date → trade_datetime
-- Adds full UTC timestamp support for trade records.
-- ===============================================

BEGIN TRANSACTION;

-- Rename the column
ALTER TABLE trades RENAME COLUMN trade_date TO trade_datetime;

-- Optional: backfill legacy dates to full UTC timestamps
-- This ensures uniform ISO 8601 format (e.g., 2025-11-05T00:00:00Z)
UPDATE trades
SET trade_datetime = trade_datetime || 'T00:00:00Z'
WHERE LENGTH(trade_datetime) = 10;  -- only has date

COMMIT;
