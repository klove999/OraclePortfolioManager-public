-- ===============================================
-- Position Audit Report
-- Verifies that total_credit, total_debit, and pnl
-- in the positions table align with trades history.
-- ===============================================

BEGIN TRANSACTION;

CREATE VIEW IF NOT EXISTS vw_position_audit AS

WITH trade_summary AS (
    SELECT
        t.position_id,
        p.symbol,
        p.strategy,
        p.status,
        p.strike,
        p.expiration,
        p.entry_date,
        p.date_closed,
        SUM(
            CASE WHEN t.contracts * -1 * t.price * 100 > 0
                 THEN t.contracts * -1 * t.price * 100
                 ELSE 0 END
        ) AS computed_credit,
        SUM(
            CASE WHEN t.contracts * -1 * t.price * 100 < 0
                 THEN ABS(t.contracts * -1 * t.price * 100)
                 ELSE 0 END
        ) AS computed_debit,
        SUM(t.commissions) AS total_commissions,
        SUM(t.fees) AS total_fees,
        SUM(t.contracts) AS net_contracts
    FROM trades t
    LEFT JOIN positions p ON t.position_id = p.id
    GROUP BY t.position_id
)

SELECT
    ts.position_id,
    ts.symbol,
    ts.strategy,
    ts.status,
    ts.strike,
    ts.expiration,
    ts.entry_date,
    ts.date_closed,

    -- Derived from trade history
    ROUND(ts.computed_credit, 2) AS computed_credit,
    ROUND(ts.computed_debit, 2)  AS computed_debit,
    ROUND(ts.computed_credit - ts.computed_debit, 2) AS computed_net_flow,
    ROUND(ts.total_commissions + ts.total_fees, 2) AS computed_costs,

    -- Stored in positions table
    ROUND(p.total_credit, 2) AS stored_total_credit,
    ROUND(p.total_debit, 2)  AS stored_total_debit,
    ROUND(p.pnl, 2)          AS stored_pnl,
    ROUND(p.commissions + p.fees, 2) AS stored_costs,

    -- Compare stored vs. computed
    ROUND(
        (ts.computed_credit - ts.computed_debit)
        - (p.total_credit - p.total_debit), 2
    ) AS pnl_diff,

    ROUND(p.total_credit - ts.computed_credit, 2) AS credit_diff,
    ROUND(p.total_debit  - ts.computed_debit, 2)  AS debit_diff,

    ts.net_contracts AS open_contracts
FROM trade_summary ts
LEFT JOIN positions p ON ts.position_id = p.id
ORDER BY ts.symbol, ts.position_id;

COMMIT;
