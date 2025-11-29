-- v5.2 – Indexes for positions table

BEGIN TRANSACTION;

CREATE INDEX IF NOT EXISTS idx_positions_symbol_status
    ON positions(symbol, status);

CREATE INDEX IF NOT EXISTS idx_positions_status_dte
    ON positions(status, dte);

COMMIT;
