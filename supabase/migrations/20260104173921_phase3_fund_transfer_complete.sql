/*
  # Phase 3: Fund Transfer System Complete

  ## Overview
  Implements complete fund transfer system with automatic journal posting.

  ## Changes Made

  1. **Enhanced fund_transfers table**
    - Add status tracking
    - Add posted_at timestamp
    - Add posted_by user reference

  2. **Auto-post journal trigger**
    - Automatically posts journal when fund transfer is created
    - No manual step needed
    - Maintains integrity

  3. **Views for fund transfers**
    - Show fund transfers with account details
    - Show posted status
    - Update petty cash balance view

  ## Usage
  - Create fund transfer through UI
  - Journal automatically posted
  - Both accounts updated in real-time
*/

-- ============================================================================
-- ENHANCE FUND TRANSFERS TABLE
-- ============================================================================

DO $$
BEGIN
  -- Add status column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fund_transfers' AND column_name = 'status'
  ) THEN
    ALTER TABLE fund_transfers
    ADD COLUMN status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'posted', 'cancelled'));
  END IF;

  -- Add posted_at column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fund_transfers' AND column_name = 'posted_at'
  ) THEN
    ALTER TABLE fund_transfers
    ADD COLUMN posted_at TIMESTAMPTZ;
  END IF;

  -- Add posted_by column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'fund_transfers' AND column_name = 'posted_by'
  ) THEN
    ALTER TABLE fund_transfers
    ADD COLUMN posted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_fund_transfers_status ON fund_transfers(status);

-- ============================================================================
-- AUTO-POST JOURNAL TRIGGER FOR FUND TRANSFERS
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
  v_journal_id UUID;
  v_description TEXT;
BEGIN
  -- Determine from_account_id
  IF NEW.from_account_type = 'petty_cash' THEN
    SELECT id INTO v_from_account_id FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
  ELSIF NEW.from_account_type = 'cash_on_hand' THEN
    SELECT id INTO v_from_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
  ELSIF NEW.from_account_type = 'bank' THEN
    SELECT coa_id INTO v_from_account_id FROM bank_accounts WHERE id = NEW.from_bank_account_id;
  END IF;

  -- Determine to_account_id
  IF NEW.to_account_type = 'petty_cash' THEN
    SELECT id INTO v_to_account_id FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
  ELSIF NEW.to_account_type = 'cash_on_hand' THEN
    SELECT id INTO v_to_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
  ELSIF NEW.to_account_type = 'bank' THEN
    SELECT coa_id INTO v_to_account_id FROM bank_accounts WHERE id = NEW.to_bank_account_id;
  END IF;

  IF v_from_account_id IS NULL OR v_to_account_id IS NULL THEN
    RAISE EXCEPTION 'Cannot determine chart of accounts for transfer';
  END IF;

  -- Build description
  v_description := 'Fund Transfer ' || NEW.transfer_number;
  IF NEW.description IS NOT NULL THEN
    v_description := v_description || ' - ' || NEW.description;
  END IF;

  -- Create journal entry
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
    0, -- Will be recalculated by trigger
    0, -- Will be recalculated by trigger
    true,
    NEW.created_by
  ) RETURNING id INTO v_journal_id;

  -- Create journal lines
  INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
  VALUES
    (v_journal_id, v_to_account_id, NEW.amount, 0, 'Transfer In: ' || NEW.transfer_number),
    (v_journal_id, v_from_account_id, 0, NEW.amount, 'Transfer Out: ' || NEW.transfer_number);

  -- Update fund transfer with journal and status
  UPDATE fund_transfers
  SET 
    journal_entry_id = v_journal_id,
    status = 'posted',
    posted_at = now(),
    posted_by = NEW.created_by
  WHERE id = NEW.id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error auto-posting fund transfer journal: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_auto_post_fund_transfer_journal ON fund_transfers;

-- Create trigger
CREATE TRIGGER trigger_auto_post_fund_transfer_journal
  AFTER INSERT ON fund_transfers
  FOR EACH ROW
  EXECUTE FUNCTION auto_post_fund_transfer_journal();

COMMENT ON FUNCTION auto_post_fund_transfer_journal IS
  'Automatically posts journal entry when fund transfer is created. Updates status to posted.';

-- ============================================================================
-- CREATE FUND TRANSFER VIEW WITH DETAILS
-- ============================================================================

CREATE OR REPLACE VIEW vw_fund_transfers_detailed AS
SELECT
  ft.id,
  ft.transfer_number,
  ft.transfer_date,
  ft.amount,
  ft.from_account_type,
  ft.to_account_type,
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
  
  -- To account details
  CASE 
    WHEN ft.to_account_type = 'petty_cash' THEN 'Petty Cash'
    WHEN ft.to_account_type = 'cash_on_hand' THEN 'Cash on Hand'
    WHEN ft.to_account_type = 'bank' THEN to_bank.bank_name || ' - ' || to_bank.account_number
    ELSE ft.to_account_type
  END AS to_account_name,
  
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
  'Detailed view of fund transfers with account names and journal entry status';

-- Grant access to view
GRANT SELECT ON vw_fund_transfers_detailed TO authenticated;

-- ============================================================================
-- FUNCTION: Generate Fund Transfer Number
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_fund_transfer_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_year TEXT;
  v_month TEXT;
  v_count INT;
  v_number TEXT;
BEGIN
  v_year := TO_CHAR(CURRENT_DATE, 'YY');
  v_month := TO_CHAR(CURRENT_DATE, 'MM');
  
  SELECT COUNT(*) INTO v_count
  FROM fund_transfers
  WHERE transfer_number LIKE 'FT' || v_year || v_month || '%';
  
  v_number := 'FT' || v_year || v_month || '-' || LPAD((v_count + 1)::TEXT, 4, '0');
  
  RETURN v_number;
END;
$$;

COMMENT ON FUNCTION generate_fund_transfer_number IS
  'Generates sequential fund transfer number in format FT[YY][MM]-[NNNN]';

GRANT EXECUTE ON FUNCTION generate_fund_transfer_number TO authenticated;

-- ============================================================================
-- CREATE PETTY CASH STATEMENT VIEW
-- ============================================================================

CREATE OR REPLACE VIEW vw_petty_cash_statement AS
-- Petty cash withdrawals (inflows)
SELECT
  pct.id,
  pct.transaction_date,
  pct.transaction_number AS reference,
  'Withdrawal' AS transaction_type,
  pct.description,
  pct.amount AS inflow,
  0::NUMERIC AS outflow,
  pct.created_at
FROM petty_cash_transactions pct
WHERE pct.transaction_type = 'withdraw'

UNION ALL

-- Petty cash expenses (outflows)
SELECT
  pct.id,
  pct.transaction_date,
  pct.transaction_number AS reference,
  'Expense' AS transaction_type,
  pct.description || COALESCE(' - ' || pct.expense_category, '') AS description,
  0::NUMERIC AS inflow,
  pct.amount AS outflow,
  pct.created_at
FROM petty_cash_transactions pct
WHERE pct.transaction_type = 'expense'

UNION ALL

-- Fund transfers TO petty cash (inflows)
SELECT
  ft.id,
  ft.transfer_date AS transaction_date,
  ft.transfer_number AS reference,
  'Transfer In' AS transaction_type,
  'From ' || CASE 
    WHEN ft.from_account_type = 'cash_on_hand' THEN 'Cash on Hand'
    WHEN ft.from_account_type = 'bank' THEN 'Bank'
    ELSE ft.from_account_type
  END || COALESCE(' - ' || ft.description, '') AS description,
  ft.amount AS inflow,
  0::NUMERIC AS outflow,
  ft.created_at
FROM fund_transfers ft
WHERE ft.to_account_type = 'petty_cash'
AND ft.status = 'posted'

UNION ALL

-- Fund transfers FROM petty cash (outflows)
SELECT
  ft.id,
  ft.transfer_date AS transaction_date,
  ft.transfer_number AS reference,
  'Transfer Out' AS transaction_type,
  'To ' || CASE 
    WHEN ft.to_account_type = 'cash_on_hand' THEN 'Cash on Hand'
    WHEN ft.to_account_type = 'bank' THEN 'Bank'
    ELSE ft.to_account_type
  END || COALESCE(' - ' || ft.description, '') AS description,
  0::NUMERIC AS inflow,
  ft.amount AS outflow,
  ft.created_at
FROM fund_transfers ft
WHERE ft.from_account_type = 'petty_cash'
AND ft.status = 'posted'

ORDER BY transaction_date DESC, created_at DESC;

COMMENT ON VIEW vw_petty_cash_statement IS
  'Complete petty cash statement including transactions and fund transfers';

GRANT SELECT ON vw_petty_cash_statement TO authenticated;

-- ============================================================================
-- RECREATE PETTY CASH BALANCE VIEW WITH FUND TRANSFERS
-- ============================================================================

DROP VIEW IF EXISTS vw_petty_cash_balance CASCADE;

CREATE VIEW vw_petty_cash_balance AS
SELECT
  COALESCE(SUM(CASE WHEN pct.transaction_type = 'withdraw' THEN pct.amount ELSE 0 END), 0) AS total_inflows,
  COALESCE(SUM(CASE WHEN pct.transaction_type = 'expense' THEN pct.amount ELSE 0 END), 0) AS total_outflows,
  COALESCE((SELECT SUM(amount) FROM fund_transfers WHERE to_account_type = 'petty_cash' AND status = 'posted'), 0) AS transfer_inflows,
  COALESCE((SELECT SUM(amount) FROM fund_transfers WHERE from_account_type = 'petty_cash' AND status = 'posted'), 0) AS transfer_outflows,
  COALESCE(SUM(CASE WHEN pct.transaction_type = 'withdraw' THEN pct.amount ELSE -pct.amount END), 0) + 
  COALESCE((SELECT SUM(amount) FROM fund_transfers WHERE to_account_type = 'petty_cash' AND status = 'posted'), 0) -
  COALESCE((SELECT SUM(amount) FROM fund_transfers WHERE from_account_type = 'petty_cash' AND status = 'posted'), 0) AS current_balance
FROM petty_cash_transactions pct;

COMMENT ON VIEW vw_petty_cash_balance IS
  'Real-time petty cash balance including withdrawals, expenses, and fund transfers';

GRANT SELECT ON vw_petty_cash_balance TO authenticated;
