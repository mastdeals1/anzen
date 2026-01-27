/*
  # Add Bank Account IDs to Fund Transfer View

  ## What This Does
  Adds from_bank_account_id, to_bank_account_id, and statement line IDs to the view
  so the frontend can properly edit fund transfers.

  ## Changes
  - Drop and recreate vw_fund_transfers_detailed with additional ID columns
*/

DROP VIEW IF EXISTS vw_fund_transfers_detailed CASCADE;

CREATE VIEW vw_fund_transfers_detailed AS
SELECT
  ft.id,
  ft.transfer_number,
  ft.transfer_date,
  ft.amount,
  ft.from_amount,
  ft.to_amount,
  ft.exchange_rate,
  ft.from_account_type,
  ft.to_account_type,
  ft.from_bank_account_id,
  ft.to_bank_account_id,
  ft.from_bank_statement_line_id,
  ft.to_bank_statement_line_id,
  ft.description,
  ft.status,
  ft.posted_at,
  ft.created_at,

  -- From account details
  CASE
    WHEN ft.from_account_type = 'petty_cash' THEN 'Petty Cash'
    WHEN ft.from_account_type = 'cash_on_hand' THEN 'Cash on Hand'
    WHEN ft.from_account_type = 'bank' THEN from_bank.bank_name || ' - ' || from_bank.account_number
    ELSE ft.from_account_type
  END AS from_account_name,
  from_bank.currency AS from_currency,

  -- To account details
  CASE
    WHEN ft.to_account_type = 'petty_cash' THEN 'Petty Cash'
    WHEN ft.to_account_type = 'cash_on_hand' THEN 'Cash on Hand'
    WHEN ft.to_account_type = 'bank' THEN to_bank.bank_name || ' - ' || to_bank.account_number
    ELSE ft.to_account_type
  END AS to_account_name,
  to_bank.currency AS to_currency,

  -- Journal entry details
  ft.journal_entry_id,
  je.entry_date AS journal_date,
  je.is_posted AS journal_posted,

  -- Creator details
  ft.created_by,
  up.full_name AS created_by_name
FROM fund_transfers ft
LEFT JOIN bank_accounts from_bank ON ft.from_bank_account_id = from_bank.id
LEFT JOIN bank_accounts to_bank ON ft.to_bank_account_id = to_bank.id
LEFT JOIN journal_entries je ON ft.journal_entry_id = je.id
LEFT JOIN user_profiles up ON ft.created_by = up.id;

COMMENT ON VIEW vw_fund_transfers_detailed IS
  'Detailed view of fund transfers with currency conversion info, account names, and IDs for editing';

GRANT SELECT ON vw_fund_transfers_detailed TO authenticated;
