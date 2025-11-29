
--Enter new position
INSERT INTO positions (
    symbol,
    strategy,
    contracts,
    status,
    strike,
    expiration,
    entry_price,
    total_credit,
    total_debit,
    commissions,
    fees,
    entry_iv,
    account_size,
    entry_date,
    date_added,
    last_updated)
VALUES(
    'HUT', --symbol
    'ShortPut', --strategy
    -2, --contracts
    'OPEN', --status
    45.0, --strike
    '2025-11-14', --expiration
    3.20, --entry_price
    640.0, --total_credit
    0.0, --total_debit
    1.30, --commissions
    0.03, --fees
    1.2931, --entry_iv
    700000.0, --account_size
    '2025-11-06', --entry_date
    datetime(datetime('now'), '+6 hours'), --date_added
    datetime(datetime('now'), '+6 hours') --last_updated
);

SELECT * FROM positions
WHERE status = 'OPEN'

--Update mark and greeks on positions table
UPDATE positions
SET
    mark = 32.4,
    delta = -0.46,
    theta = -0.2,
    vega = 0.45,
    gamma = 0.01,
    rho = -0.26,
    iv = 0.36507,
    iv_rank = 0.00,
    last_updated = datetime((datetime('now')), '+6 hours')
WHERE id = 4

--Update position to close or roll
UPDATE positions
SET
    contracts = 0,
    status = 'ROLLED',
    total_debit = -704.0,
    commissions = 2.60,
    fees = 0.05,
    date_closed = '2025-11-05',
    last_updated = datetime(datetime('now'), '+6 hours'),
    notes = 'Rolled down and out to 34.0P.'
WHERE id = 14

--Enter new trade
INSERT INTO trades (
    position_id,
    trade_datetime,
    action,
    contracts,
    price,
    commissions,
    fees,
    underlying_price,
    notes,
    created_at)
VALUES (
    18, --position_id
    datetime('2025-11-05 08:30:00', '+6 hours'), --trade_datetime
    'SELL_OPEN', --action
    -2, --contracts
    3.20, --price
    1.30, --commissions
    0.03, --fees
    49.17,
    'Opened short put HUT 45.0P.', --notes
    datetime(datetime('now'),'+6 hours') --created_at
);

SELECT * FROM positions;
SELECT * FROM trades;

--Fully close trade
INSERT INTO trades (position_id, trade_date, action, side, strategy, contracts, strike, expiration, price, commissions, fees, notes)
VALUES (7, '2025-10-28', 'CLOSE', 'BUY', 'ShortPut', 6, 13.0, '2025-11-14', 0.31, 3.90, 0.07, 'Closed short put WULF 13.0P.');

--Partially close trade
INSERT INTO trades (position_id, trade_date, action, side, strategy, contracts, strike, expiration, price, commission, fees, notes)
VALUES (5, '2025-10-28', 'CLOSE', 'BUY', 'ShortPut', 6, 260.00, '2026-01-16', 13.84, 1.50, 'Closed WULF position partially.');

--Roll trade

     -- Step 1: close old position
     INSERT INTO trades (position_id, trade_date, action, side, strategy, contracts, strike, expiration, price, commissions, fees, notes)
     VALUES (1, '2025-10-01', 'CLOSE', 'BUY', 'ShortPut', 1, 260.00, '2026-01-16', 13.84, 0.65, 0.01, 'Closed MSTR to roll position up.');

     -- Step 2: open new leg
     INSERT INTO trades (position_id, trade_date, action, side, strategy, contracts, strike, expiration, price, commissions, fees, notes)
     VALUES (3, '2025-10-20', 'OPEN', 'SELL', 'ShortPut', 5, 25.00, '2025-11-15', 1.00, 0.0, 0.0, 'Opened new leg of roll.');


--Manual updates to positions table
UPDATE positions
SET status = 'OPEN',
WHERE id > 1

UPDATE positions
SET date_closed = NULL
WHERE id > 1

UPDATE positions
SET mark = .2, delta = .17, iv = .256843369140625, entry_iv = 0.235
WHERE id = 3

UPDATE positions
SET delta = delta * -1
WHERE id = 12;

UPDATE positions
SET entry_iv = 0.7365
WHERE id = 4;

UPDATE positions
SET iv = .4712
WHERE id = 1;

UPDATE positions
SET entry_date = '2025-09-30'
WHERE id = 1;

UPDATE positions
SET
    commissions = 7.8,
    fees = 0.16
WHERE id = 5;

UPDATE positions
SET total_credit = 540.00
WHERE id = 7;

UPDATE positions
SET total_debit = -704.00
WHERE id = 14;

UPDATE positions
SET notes = 'Rolled down and out from 38.0P.'
WHERE id = 17;

UPDATE positions
SET mark = 17.84, delta = 0.28, iv = 0.0, entry_iv = 0.0
WHERE id = 4

UPDATE positions
SET entry_date = '2025-10-27'
WHERE id = 6

UPDATE positions
SET delta = .37
WHERE id = 5

UPDATE positions
SET id = 8
WHERE id = 16;

UPDATE positions
SET notes = NULL
WHERE id = 12
SELECT * FROM trades;

UPDATE positions
SET total_credit = 285.00
WHERE id = 12;

UPDATE positions
SET total_debit = -3624.00
WHERE id = 2;

SELECT * FROM positions;

UPDATE positions
SET pnl = total_credit + total_debit - (commissions + fees)
WHERE status IN ('CLOSED', 'ROLLED')

UPDATE positions
SET pnl = 0.00
WHERE status = 'OPEN'

UPDATE positions
SET contracts = -2
WHERE id = 14;



--Manual updates to trades table
UPDATE trades
SET strike = 260.0, expiration = '2026-01-16'
WHERE id = 2

UPDATE trades
SET action = 'OPEN'
WHERE id = 1

UPDATE trades
MSTR
SET contracts = -2
WHERE id = 18

UPDATE trades
SET notes = 'Closed short put BBAI 6.5.'
WHERE id = 19

UPDATE trades
SET contracts = 6
WHERE id = 7;

UPDATE trades
SET side = 'SELL'
WHERE id = 14;

UPDATE trades
SET position_id = 12
WHERE id = 15

UPDATE trades
SET underlying_price = 35.34
WHERE id = 23

UPDATE trades
SET trade_datetime = datetime('2025-11-06 08:30:13', '+6 hours')
WHERE id = 24

UPDATE positions
SET expiration = '2026-01-16'
WHERE id = 10


SELECT symbol, strategy, contracts, strike, expiration, entry_price, mark, total_credit, pnl, entry_iv, entry_date
FROM positions
WHERE status = 'OPEN'

SELECT * FROM trades



UPDATE positions
SET pnl = 0.00


update positions
set pnl = (total_credit + total_debit) - (commissions + fees)

SELECT name FROM sqlite_master WHERE type='view';


SELECT * FROM vw_position_audit LIMIT 5;
WHERE symbol = 'MSTR'


SELECT name FROM sqlite_master WHERE type='view';


PRAGMA table_info(trades);

