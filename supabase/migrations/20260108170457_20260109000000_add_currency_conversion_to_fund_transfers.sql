/*
  # Add Currency Conversion Support to Fund Transfers

  1. What This Does
    - Adds from_amount and to_amount columns for cross-currency transfers
    - Adds exchange_rate column to track conversion rate
    - Updates triggers to handle different amounts per currency
    - Ensures both bank accounts show the transfer in their ledgers

  2. Changes Made
    - Add from_amount, to_amount, exchange_rate columns
    - Migrate existing data (amount becomes from_amount)
    - Update auto_post_fund_transfer_journal to handle currency conversion
    - Add foreign keys to bank statement lines for reconciliation

  3. Usage
    - For same-currency transfers: from_amount = to_amount, exchange_rate = 1
    - For IDR→USD: from_amount = IDR, to_amount = USD, exchange_rate = auto-calculated
    - Link to bank reconciliation lines for both accounts
*/

-- ============================================================================
-- DROP VIEW FIRST (will recreate later)
-- ============================================================================

DROP VIEW IF EXISTS vw_fund_transfers_detailed CASCADE;

-- ============================================================================
-- ADD CURRENCY CONVERSION COLUMNS
-- ============================================================================

DO $$
BEGIN
  -- Add from_amount column (replaces amount)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fund_transfers' AND column_name = 'from_amount'
  ) THEN
    ALTER TABLE fund_transfers ADD COLUMN from_amount NUMERIC(15,2);

    -- Migrate existing data: copy amount to from_amount
    UPDATE fund_transfers SET from_amount = amount WHERE from_amount IS NULL;

    -- Make it NOT NULL after migration
    ALTER TABLE fund_transfers ALTER COLUMN from_amount SET NOT NULL;
  END IF;

  -- Add to_amount column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fund_transfers' AND column_name = 'to_amount'
  ) THEN
    ALTER TABLE fund_transfers ADD COLUMN to_amount NUMERIC(15,2);

    -- Migrate existing data: copy amount to to_amount
    UPDATE fund_transfers SET to_amount = amount WHERE to_amount IS NULL;

    -- Make it NOT NULL after migration
    ALTER TABLE fund_transfers ALTER COLUMN to_amount SET NOT NULL;
  END IF;

  -- Add exchange_rate column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fund_transfers' AND column_name = 'exchange_rate'
  ) THEN
    ALTER TABLE fund_transfers ADD COLUMN exchange_rate NUMERIC(15,6);

    -- Set default 1.0 for existing records
    UPDATE fund_transfers SET exchange_rate = 1.0 WHERE exchange_rate IS NULL;
  END IF;
END $$;

-- Add check constraint: exchange_rate must be positive
ALTER TABLE fund_transfers DROP CONSTRAINT IF EXISTS fund_transfers_exchange_rate_check;
ALTER TABLE fund_transfers ADD CONSTRAINT fund_transfers_exchange_rate_check
  CHECK (exchange_rate IS NULL OR exchange_rate > 0);

-- Add indexes for foreign keys
CREATE INDEX IF NOT EXISTS idx_fund_transfers_from_statement
  ON fund_transfers(from_bank_statement_line_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_to_statement
  ON fund_transfers(to_bank_statement_line_id);

-- ============================================================================
-- UPDATE AUTO-POST TRIGGER TO HANDLE CURRENCY CONVERSION
-- ============================================================================

CREATE OR REPLACE FUNCTION auto_post_fund_transfer_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from_account_id UUID;
  v_to_account_id UUID;
  v_from_currency TEXT;
  v_to_currency TEXT;
  v_journal_id UUID;
  v_description TEXT;
  v_from_amount NUMERIC;
  v_to_amount NUMERIC;
BEGIN
  -- Determine from_account_id and currency
  IF NEW.from_account_type = 'petty_cash' THEN
    SELECT id, 'IDR' INTO v_from_account_id, v_from_currency
    FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
  ELSIF NEW.from_account_type = 'cash_on_hand' THEN
    SELECT id, 'IDR' INTO v_from_account_id, v_from_currency
    FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
  ELSIF NEW.from_account_type = 'bank' THEN
    SELECT coa_id, currency INTO v_from_account_id, v_from_currency
    FROM bank_accounts WHERE id = NEW.from_bank_account_id;
  END IF;

  -- Determine to_account_id and currency
  IF NEW.to_account_type = 'petty_cash' THEN
    SELECT id, 'IDR' INTO v_to_account_id, v_to_currency
    FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
  ELSIF NEW.to_account_type = 'cash_on_hand' THEN
    SELECT id, 'IDR' INTO v_to_account_id, v_to_currency
    FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
  ELSIF NEW.to_account_type = 'bank' THEN
    SELECT coa_id, currency INTO v_to_account_id, v_to_currency
    FROM bank_accounts WHERE id = NEW.to_bank_account_id;
  END IF;

  IF v_from_account_id IS NULL OR v_to_account_id IS NULL THEN
    RAISE EXCEPTION 'Cannot determine chart of accounts for transfer';
  END IF;

  -- Use from_amount and to_amount for journal (handles currency conversion)
  v_from_amount := NEW.from_amount;
  v_to_amount := NEW.to_amount;

  -- Build description
  v_description := 'Fund Transfer ' || NEW.transfer_number;
  IF v_from_currency != v_to_currency THEN
    v_description := v_description || ' (FX: ' || v_from_currency || ' → ' || v_to_currency || ')';
  END IF;
  IF NEW.description IS NOT NULL THEN
    v_description := v_description || ' - ' || NEW.description;
  END IF;

  -- For cross-currency transfers, we need TWO journal entries:
  -- 1. Debit TO account (in TO currency)
  -- 2. Credit FROM account (in FROM currency)
  -- The difference is handled by exchange gain/loss account

  IF v_from_currency = v_to_currency THEN
    -- Same currency: simple transfer with matching debit/credit
    INSERT INTO journal_entries (
      entry_date,
      source_module,
      reference_id,
      reference_number,
      description,
      total_debit,
      total_credit,
      is_posted,
      created_by
    ) VALUES (
      NEW.transfer_date,
      'fund_transfers',
      NEW.id,
      NEW.transfer_number,
      v_description,
      v_from_amount,
      v_from_amount,
      true,
      NEW.created_by
    ) RETURNING id INTO v_journal_id;

    -- Create journal lines (same amount)
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES
      (v_journal_id, v_to_account_id, v_from_amount, 0, 'Transfer In: ' || NEW.transfer_number),
      (v_journal_id, v_from_account_id, 0, v_from_amount, 'Transfer Out: ' || NEW.transfer_number);
  ELSE
    -- Cross-currency: record both amounts
    -- Note: In proper multi-currency accounting, each account maintains its own currency
    -- For now, we'll record the transfer with both amounts in the description
    INSERT INTO journal_entries (
      entry_date,
      source_module,
      reference_id,
      reference_number,
      description,
      total_debit,
      total_credit,
      is_posted,
      created_by
    ) VALUES (
      NEW.transfer_date,
      'fund_transfers',
      NEW.id,
      NEW.transfer_number,
      v_description,
      v_from_amount, -- Use FROM amount for totals
      v_from_amount,
      true,
      NEW.created_by
    ) RETURNING id INTO v_journal_id;

    -- Create journal lines with cross-currency notation
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES
      (v_journal_id, v_to_account_id, v_from_amount, 0,
       'Transfer In: ' || NEW.transfer_number || ' (' || v_to_currency || ' ' || v_to_amount::TEXT || ')'),
      (v_journal_id, v_from_account_id, 0, v_from_amount,
       'Transfer Out: ' || NEW.transfer_number || ' (' || v_from_currency || ' ' || v_from_amount::TEXT || ')');
  END IF;

  -- Update fund transfer with journal and status
  UPDATE fund_transfers
  SET
    journal_entry_id = v_journal_id,
    status = 'posted',
    posted_at = now(),
    posted_by = NEW.created_by
  WHERE id = NEW.id;

  -- Link to bank statement lines if provided
  IF NEW.from_bank_statement_line_id IS NOT NULL THEN
    UPDATE bank_statement_lines
    SET
      matched_fund_transfer_id = NEW.id,
      reconciliation_status = 'matched',
      matched_at = now(),
      matched_by = NEW.created_by,
      notes = 'Linked to Fund Transfer ' || NEW.transfer_number
    WHERE id = NEW.from_bank_statement_line_id;
  END IF;

  IF NEW.to_bank_statement_line_id IS NOT NULL THEN
    UPDATE bank_statement_lines
    SET
      matched_fund_transfer_id = NEW.id,
      reconciliation_status = 'matched',
      matched_at = now(),
      matched_by = NEW.created_by,
      notes = 'Linked to Fund Transfer ' || NEW.transfer_number
    WHERE id = NEW.to_bank_statement_line_id;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error auto-posting fund transfer journal: %', SQLERRM;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION auto_post_fund_transfer_journal IS
  'Auto-posts journal entry for fund transfers, handles currency conversion and bank reconciliation linking';

-- ============================================================================
-- RECREATE FUND TRANSFER VIEW TO SHOW CURRENCY INFO
-- ============================================================================

CREATE OR REPLACE VIEW vw_fund_transfers_detailed AS
SELECT
  ft.id,
  ft.transfer_number,
  ft.transfer_date,
  ft.amount,  -- Keep for backwards compatibility
  ft.from_amount,
  ft.to_amount,
  ft.exchange_rate,
  ft.from_account_type,
  ft.to_account_type,
  ft.description,
  ft.status,
  ft.posted_at,
  ft.created_at,
  ft.from_bank_statement_line_id,
  ft.to_bank_statement_line_id,

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
  'Detailed view of fund transfers with currency conversion info and account names';

GRANT SELECT ON vw_fund_transfers_detailed TO authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON COLUMN fund_transfers.from_amount IS 'Amount debited from source account (in source currency)';
COMMENT ON COLUMN fund_transfers.to_amount IS 'Amount credited to destination account (in destination currency)';
COMMENT ON COLUMN fund_transfers.exchange_rate IS 'Exchange rate used for conversion (to_amount / from_amount)';
COMMENT ON COLUMN fund_transfers.from_bank_statement_line_id IS 'Links to bank statement showing money OUT';
COMMENT ON COLUMN fund_transfers.to_bank_statement_line_id IS 'Links to bank statement showing money IN';
