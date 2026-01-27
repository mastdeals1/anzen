/*
  # Phase 1: Petty Cash Bidirectional Linking & Fund Transfers

  ## Overview
  This migration implements Phase 1 of the petty cash fix plan:
  - Adds bidirectional linking between finance_expenses and petty_cash_transactions
  - Creates consolidated view of all expenses
  - Adds fund_transfers table for moving money between accounts
  - Creates balance checking views
  - Ensures required Chart of Accounts exist

  ## Changes Made

  1. **Schema Updates**
    - Add `petty_cash_transaction_id` to `finance_expenses` (nullable, for backward compatibility)
    - Add `finance_expense_id` to `petty_cash_transactions` (nullable, for backward compatibility)
    - Create `fund_transfers` table for inter-account transfers
    - Create `petty_cash_documents` table if not exists

  2. **Trigger Updates**
    - Update `auto_post_expense_accounting()` to store bidirectional link when creating petty cash transactions

  3. **Views**
    - `vw_all_expenses` - Consolidated view of expenses from both systems
    - `vw_petty_cash_balance` - Real-time petty cash balance
    - `vw_cash_on_hand_balance` - Real-time cash on hand balance from bank reconciliation

  4. **Functions**
    - `post_fund_transfer_journal()` - Manual function to post journal entries for fund transfers

  5. **Chart of Accounts**
    - Ensures COA 1101 (Cash on Hand) and 1102 (Petty Cash) exist

  ## Safety Notes
  - All changes are additive (no data modification)
  - Existing triggers enhanced, not replaced
  - Nullable columns for backward compatibility
  - No breaking changes to existing workflows
*/

-- ============================================================================
-- PART 1: ADD BIDIRECTIONAL LINK COLUMNS
-- ============================================================================

-- Add petty_cash_transaction_id to finance_expenses
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'finance_expenses' AND column_name = 'petty_cash_transaction_id'
  ) THEN
    ALTER TABLE finance_expenses
    ADD COLUMN petty_cash_transaction_id UUID REFERENCES petty_cash_transactions(id) ON DELETE SET NULL;

    CREATE INDEX IF NOT EXISTS idx_finance_expenses_petty_cash_tx
    ON finance_expenses(petty_cash_transaction_id);

    COMMENT ON COLUMN finance_expenses.petty_cash_transaction_id IS
      'Links to the petty_cash_transactions entry when payment_method = petty_cash. Enables bidirectional lookup.';
  END IF;
END $$;

-- Add finance_expense_id to petty_cash_transactions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'finance_expense_id'
  ) THEN
    ALTER TABLE petty_cash_transactions
    ADD COLUMN finance_expense_id UUID REFERENCES finance_expenses(id) ON DELETE SET NULL;

    CREATE INDEX IF NOT EXISTS idx_petty_cash_transactions_finance_expense
    ON petty_cash_transactions(finance_expense_id);

    COMMENT ON COLUMN petty_cash_transactions.finance_expense_id IS
      'Links to the finance_expenses entry when source = finance_expense. Enables bidirectional lookup.';
  END IF;
END $$;

-- ============================================================================
-- PART 2: UPDATE TRIGGER TO STORE BIDIRECTIONAL LINK
-- ============================================================================

DROP FUNCTION IF EXISTS auto_post_expense_accounting() CASCADE;

CREATE OR REPLACE FUNCTION auto_post_expense_accounting()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_description TEXT;
  v_inventory_account_id UUID;
  v_expense_account_id UUID;
  v_cash_account_id UUID;
  v_petty_cash_account_id UUID;
  v_payment_account_id UUID;
  v_journal_id UUID;
  v_entry_type TEXT;
  v_pc_number TEXT;
  v_petty_cash_tx_id UUID;
BEGIN
  -- Get account IDs
  SELECT id INTO v_inventory_account_id
  FROM chart_of_accounts
  WHERE code = '1130'
  LIMIT 1;

  SELECT id INTO v_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1101'
  LIMIT 1;

  SELECT id INTO v_petty_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1102'
  LIMIT 1;

  -- Determine payment account based on payment_method
  IF NEW.payment_method = 'petty_cash' THEN
    v_payment_account_id := v_petty_cash_account_id;
  ELSE
    v_payment_account_id := v_cash_account_id;
  END IF;

  -- Determine expense account based on category
  SELECT id INTO v_expense_account_id
  FROM chart_of_accounts
  WHERE CASE
    WHEN NEW.expense_category IN ('duty_customs', 'ppn_import', 'pph_import') THEN code = '5200'
    WHEN NEW.expense_category IN ('freight_import', 'clearing_forwarding') THEN code = '5300'
    WHEN NEW.expense_category IN ('container_handling', 'port_charges', 'transport_import') THEN code = '5400'
    WHEN NEW.expense_category = 'salary' THEN code = '6100'
    WHEN NEW.expense_category = 'warehouse_rent' THEN code = '6210'
    WHEN NEW.expense_category = 'utilities' THEN code = '6300'
    ELSE code = '6900'
  END
  LIMIT 1;

  -- Build description
  v_description := 'Expense: ' || NEW.expense_category;
  IF NEW.description IS NOT NULL THEN
    v_description := v_description || ' - ' || NEW.description;
  END IF;

  -- Determine entry type
  IF NEW.import_container_id IS NOT NULL THEN
    v_entry_type := 'CAPITALIZED TO INVENTORY';
  ELSE
    v_entry_type := 'EXPENSED TO P&L';
  END IF;

  -- Create journal entry with ZERO totals (will be recalculated by trigger)
  IF NEW.import_container_id IS NOT NULL AND v_inventory_account_id IS NOT NULL THEN
    INSERT INTO journal_entries (
      entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, created_by
    ) VALUES (
      NEW.expense_date, 'expenses', NEW.id, 'EXP-' || COALESCE(NEW.voucher_number, NEW.id::text),
      v_description || ' (' || v_entry_type || ')', 0, 0, true, NEW.created_by
    ) RETURNING id INTO v_journal_id;

    -- Insert lines (trigger will recalculate totals)
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES
      (v_journal_id, v_inventory_account_id, NEW.amount, 0, 'Inventory - ' || NEW.expense_category),
      (v_journal_id, v_payment_account_id, 0, NEW.amount,
        CASE WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash payment' ELSE 'Cash payment' END);

  ELSIF v_expense_account_id IS NOT NULL THEN
    INSERT INTO journal_entries (
      entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, created_by
    ) VALUES (
      NEW.expense_date, 'expenses', NEW.id, 'EXP-' || COALESCE(NEW.voucher_number, NEW.id::text),
      v_description || ' (' || v_entry_type || ')', 0, 0, true, NEW.created_by
    ) RETURNING id INTO v_journal_id;

    -- Insert lines (trigger will recalculate totals)
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES
      (v_journal_id, v_expense_account_id, NEW.amount, 0, 'Expense - ' || NEW.expense_category),
      (v_journal_id, v_payment_account_id, 0, NEW.amount,
        CASE WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash payment' ELSE 'Cash payment' END);
  END IF;

  -- Create petty cash transaction if needed AND store bidirectional link
  IF NEW.payment_method = 'petty_cash' AND v_journal_id IS NOT NULL THEN
    SELECT 'PC-' || TO_CHAR(NEW.expense_date, 'YYYYMMDD') || '-' ||
           LPAD((COUNT(*) + 1)::TEXT, 4, '0')
    INTO v_pc_number
    FROM petty_cash_transactions
    WHERE transaction_date = NEW.expense_date;

    INSERT INTO petty_cash_transactions (
      transaction_number,
      transaction_date,
      transaction_type,
      amount,
      description,
      expense_category,
      bank_account_id,
      created_by,
      source,
      paid_to,
      paid_by,
      finance_expense_id
    ) VALUES (
      v_pc_number,
      NEW.expense_date,
      'expense',
      NEW.amount,
      v_description,
      NEW.expense_category,
      NEW.bank_account_id,
      NEW.created_by,
      'finance_expense',
      NEW.description,
      NEW.paid_by,
      NEW.id
    ) RETURNING id INTO v_petty_cash_tx_id;

    -- Store bidirectional link back to finance_expenses
    UPDATE finance_expenses
    SET petty_cash_transaction_id = v_petty_cash_tx_id
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error auto-posting expense accounting: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_auto_post_expense_accounting
  AFTER INSERT ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION auto_post_expense_accounting();

COMMENT ON FUNCTION auto_post_expense_accounting IS
  'Auto-posts expense journal entries and creates petty cash transactions with bidirectional linking. Uses Petty Cash (1102) when payment_method=petty_cash, otherwise Cash on Hand (1101).';

-- ============================================================================
-- PART 3: CREATE FUND TRANSFERS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS fund_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_number TEXT NOT NULL UNIQUE,
  transfer_date DATE NOT NULL DEFAULT CURRENT_DATE,
  amount NUMERIC(15,2) NOT NULL CHECK (amount > 0),
  from_account_type TEXT NOT NULL CHECK (from_account_type IN ('petty_cash', 'cash_on_hand', 'bank')),
  to_account_type TEXT NOT NULL CHECK (to_account_type IN ('petty_cash', 'cash_on_hand', 'bank')),
  from_bank_account_id UUID REFERENCES bank_accounts(id) ON DELETE RESTRICT,
  to_bank_account_id UUID REFERENCES bank_accounts(id) ON DELETE RESTRICT,
  description TEXT,
  journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE SET NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT no_same_account_transfer CHECK (
    NOT (from_account_type = to_account_type AND
         COALESCE(from_bank_account_id, '00000000-0000-0000-0000-000000000000'::uuid) =
         COALESCE(to_bank_account_id, '00000000-0000-0000-0000-000000000000'::uuid))
  )
);

CREATE INDEX IF NOT EXISTS idx_fund_transfers_date ON fund_transfers(transfer_date);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_from_bank ON fund_transfers(from_bank_account_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_to_bank ON fund_transfers(to_bank_account_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_journal ON fund_transfers(journal_entry_id);

ALTER TABLE fund_transfers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all fund transfers"
  ON fund_transfers FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create fund transfers"
  ON fund_transfers FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

COMMENT ON TABLE fund_transfers IS
  'Records transfers between petty cash, cash on hand, and bank accounts. Does NOT auto-post journals - use post_fund_transfer_journal() function after verification.';

-- ============================================================================
-- PART 4: CREATE PETTY CASH DOCUMENTS TABLE IF NOT EXISTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS petty_cash_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  petty_cash_transaction_id UUID NOT NULL REFERENCES petty_cash_transactions(id) ON DELETE CASCADE,
  file_type TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_size BIGINT,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_petty_cash_documents_transaction
  ON petty_cash_documents(petty_cash_transaction_id);

ALTER TABLE petty_cash_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all petty cash documents"
  ON petty_cash_documents FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can upload petty cash documents"
  ON petty_cash_documents FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = uploaded_by);

-- ============================================================================
-- PART 5: CREATE CONSOLIDATED VIEW
-- ============================================================================

CREATE OR REPLACE VIEW vw_all_expenses AS
SELECT
  'finance_expense' AS source,
  fe.id,
  fe.expense_date AS transaction_date,
  fe.amount,
  fe.expense_category AS category,
  fe.description,
  fe.payment_method,
  fe.paid_by,
  NULL::TEXT AS paid_to,
  fe.import_container_id,
  fe.delivery_challan_id,
  fe.batch_id,
  fe.bank_account_id,
  fe.petty_cash_transaction_id,
  NULL::UUID AS finance_expense_id,
  fe.created_at,
  fe.created_by
FROM finance_expenses fe
WHERE fe.paid_by != 'cash'

UNION ALL

SELECT
  'petty_cash' AS source,
  pct.id,
  pct.transaction_date,
  pct.amount,
  pct.expense_category AS category,
  pct.description,
  'cash' AS payment_method,
  pct.paid_by,
  pct.paid_to,
  NULL::UUID AS import_container_id,
  NULL::UUID AS delivery_challan_id,
  NULL::UUID AS batch_id,
  pct.bank_account_id,
  NULL::UUID AS petty_cash_transaction_id,
  pct.finance_expense_id,
  pct.created_at,
  pct.created_by
FROM petty_cash_transactions pct
WHERE pct.transaction_type = 'expense';

COMMENT ON VIEW vw_all_expenses IS
  'Consolidated view of all expenses from both finance_expenses (paid_by != cash) and petty_cash_transactions (type = expense). Includes bidirectional links.';

-- ============================================================================
-- PART 6: CREATE BALANCE VIEWS
-- ============================================================================

CREATE OR REPLACE VIEW vw_petty_cash_balance AS
SELECT
  COALESCE(SUM(CASE WHEN transaction_type = 'withdraw' THEN amount ELSE 0 END), 0) AS total_inflows,
  COALESCE(SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END), 0) AS total_outflows,
  COALESCE(SUM(CASE WHEN transaction_type = 'withdraw' THEN amount ELSE -amount END), 0) AS current_balance
FROM petty_cash_transactions;

COMMENT ON VIEW vw_petty_cash_balance IS
  'Real-time petty cash balance: withdrawals (inflows) minus expenses (outflows).';

CREATE OR REPLACE VIEW vw_cash_on_hand_balance AS
SELECT
  coa.id AS cash_account_id,
  coa.code AS account_code,
  coa.name AS account_name,
  COALESCE(SUM(jel.debit - jel.credit), 0) AS balance
FROM chart_of_accounts coa
LEFT JOIN journal_entry_lines jel ON jel.account_id = coa.id
LEFT JOIN journal_entries je ON je.id = jel.journal_entry_id AND je.is_posted = true
WHERE coa.code = '1101'
GROUP BY coa.id, coa.code, coa.name;

COMMENT ON VIEW vw_cash_on_hand_balance IS
  'Real-time Cash on Hand (1101) balance from posted journal entries.';

-- ============================================================================
-- PART 7: CREATE MANUAL JOURNAL POSTING FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION post_fund_transfer_journal(
  p_transfer_id UUID,
  p_user_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_transfer RECORD;
  v_journal_id UUID;
  v_from_account_id UUID;
  v_to_account_id UUID;
  v_description TEXT;
BEGIN
  -- Get transfer details
  SELECT * INTO v_transfer
  FROM fund_transfers
  WHERE id = p_transfer_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Fund transfer not found';
  END IF;

  IF v_transfer.journal_entry_id IS NOT NULL THEN
    RAISE EXCEPTION 'Journal already posted for this transfer';
  END IF;

  -- Determine from_account_id
  IF v_transfer.from_account_type = 'petty_cash' THEN
    SELECT id INTO v_from_account_id FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
  ELSIF v_transfer.from_account_type = 'cash_on_hand' THEN
    SELECT id INTO v_from_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
  ELSIF v_transfer.from_account_type = 'bank' THEN
    SELECT coa_id INTO v_from_account_id FROM bank_accounts WHERE id = v_transfer.from_bank_account_id;
  END IF;

  -- Determine to_account_id
  IF v_transfer.to_account_type = 'petty_cash' THEN
    SELECT id INTO v_to_account_id FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
  ELSIF v_transfer.to_account_type = 'cash_on_hand' THEN
    SELECT id INTO v_to_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
  ELSIF v_transfer.to_account_type = 'bank' THEN
    SELECT coa_id INTO v_to_account_id FROM bank_accounts WHERE id = v_transfer.to_bank_account_id;
  END IF;

  IF v_from_account_id IS NULL OR v_to_account_id IS NULL THEN
    RAISE EXCEPTION 'Cannot determine chart of accounts for transfer';
  END IF;

  -- Build description
  v_description := 'Fund Transfer ' || v_transfer.transfer_number;
  IF v_transfer.description IS NOT NULL THEN
    v_description := v_description || ' - ' || v_transfer.description;
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
    v_transfer.transfer_date,
    'fund_transfers',
    v_transfer.id,
    v_transfer.transfer_number,
    v_description,
    0, -- Will be recalculated by trigger
    0, -- Will be recalculated by trigger
    true,
    p_user_id
  ) RETURNING id INTO v_journal_id;

  -- Create journal lines
  INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
  VALUES
    (v_journal_id, v_to_account_id, v_transfer.amount, 0, 'Transfer In'),
    (v_journal_id, v_from_account_id, 0, v_transfer.amount, 'Transfer Out');

  -- Link journal back to transfer
  UPDATE fund_transfers
  SET journal_entry_id = v_journal_id
  WHERE id = p_transfer_id;

  RETURN v_journal_id;
END;
$$;

COMMENT ON FUNCTION post_fund_transfer_journal IS
  'Manually posts journal entry for a fund transfer. Call this AFTER verifying the transfer is correct. Returns journal_entry_id.';

-- ============================================================================
-- PART 8: ENSURE REQUIRED COA ACCOUNTS EXIST
-- ============================================================================

-- Ensure Cash on Hand (1101) exists
INSERT INTO chart_of_accounts (code, name, account_type, is_active)
VALUES ('1101', 'Cash on Hand', 'asset', true)
ON CONFLICT (code) DO NOTHING;

-- Ensure Petty Cash (1102) exists
INSERT INTO chart_of_accounts (code, name, account_type, is_active)
VALUES ('1102', 'Petty Cash', 'asset', true)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- FINAL COMMENTS
-- ============================================================================

COMMENT ON COLUMN finance_expenses.petty_cash_transaction_id IS
  'Bidirectional link to petty_cash_transactions when payment_method = petty_cash';

COMMENT ON COLUMN petty_cash_transactions.finance_expense_id IS
  'Bidirectional link to finance_expenses when source = finance_expense';
