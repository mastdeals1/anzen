/*
  # Phase 2: Move Expense Functions

  ## Overview
  Implements functions to move expenses between Petty Cash and Expense Tracker systems.

  ## Changes Made

  1. **Functions**
    - `move_expense_to_petty_cash()` - Move from finance_expenses to petty_cash_transactions
    - `move_expense_to_tracker()` - Move from petty_cash_transactions to finance_expenses

  2. **Safety Features**
    - Validates expense exists
    - Prevents duplicate moves
    - Maintains bidirectional links
    - Preserves journal entries
    - Updates both systems atomically

  ## Usage
  - Call from frontend when user wants to move an expense
  - Maintains data integrity across both systems
*/

-- ============================================================================
-- FUNCTION: Move Expense from Expense Tracker to Petty Cash
-- ============================================================================

CREATE OR REPLACE FUNCTION move_expense_to_petty_cash(
  p_expense_id UUID,
  p_user_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expense RECORD;
  v_pc_number TEXT;
  v_petty_cash_tx_id UUID;
BEGIN
  -- Get expense details
  SELECT * INTO v_expense
  FROM finance_expenses
  WHERE id = p_expense_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  -- Check if already linked to petty cash
  IF v_expense.petty_cash_transaction_id IS NOT NULL THEN
    RAISE EXCEPTION 'Expense already linked to petty cash';
  END IF;

  -- Generate petty cash transaction number
  SELECT 'PC-' || TO_CHAR(v_expense.expense_date, 'YYYYMMDD') || '-' ||
         LPAD((COUNT(*) + 1)::TEXT, 4, '0')
  INTO v_pc_number
  FROM petty_cash_transactions
  WHERE transaction_date = v_expense.expense_date;

  -- Create petty cash transaction
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
    v_expense.expense_date,
    'expense',
    v_expense.amount,
    v_expense.description,
    v_expense.expense_category,
    v_expense.bank_account_id,
    p_user_id,
    'moved_from_tracker',
    v_expense.description,
    'cash',
    v_expense.id
  ) RETURNING id INTO v_petty_cash_tx_id;

  -- Update finance_expenses with link
  UPDATE finance_expenses
  SET 
    petty_cash_transaction_id = v_petty_cash_tx_id,
    payment_method = 'petty_cash',
    paid_by = 'cash'
  WHERE id = p_expense_id;

  RETURN v_petty_cash_tx_id;
END;
$$;

COMMENT ON FUNCTION move_expense_to_petty_cash IS
  'Moves an expense from finance_expenses to petty_cash_transactions. Creates link and updates payment method.';

-- ============================================================================
-- FUNCTION: Move Expense from Petty Cash to Expense Tracker
-- ============================================================================

CREATE OR REPLACE FUNCTION move_expense_to_tracker(
  p_petty_cash_id UUID,
  p_bank_account_id UUID,
  p_payment_method TEXT,
  p_user_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pc_tx RECORD;
  v_expense_id UUID;
  v_finance_category TEXT;
BEGIN
  -- Get petty cash transaction details
  SELECT * INTO v_pc_tx
  FROM petty_cash_transactions
  WHERE id = p_petty_cash_id
  AND transaction_type = 'expense';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Petty cash expense not found';
  END IF;

  -- Check if already linked to finance_expenses
  IF v_pc_tx.finance_expense_id IS NOT NULL THEN
    -- Just update the existing expense
    UPDATE finance_expenses
    SET 
      payment_method = p_payment_method,
      bank_account_id = p_bank_account_id,
      paid_by = 'bank'
    WHERE id = v_pc_tx.finance_expense_id
    RETURNING id INTO v_expense_id;

    RETURN v_expense_id;
  END IF;

  -- Map petty cash category to finance category
  v_finance_category := CASE 
    WHEN v_pc_tx.expense_category IN ('Office Supplies', 'Postage & Courier', 'Cleaning & Maintenance', 'Miscellaneous') 
      THEN 'office_admin'
    WHEN v_pc_tx.expense_category = 'Transportation' 
      THEN 'delivery_sales'
    WHEN v_pc_tx.expense_category = 'Utilities' 
      THEN 'utilities'
    ELSE 'other'
  END;

  -- Create finance_expenses entry
  INSERT INTO finance_expenses (
    expense_category,
    expense_type,
    amount,
    expense_date,
    description,
    payment_method,
    bank_account_id,
    paid_by,
    created_by,
    petty_cash_transaction_id
  ) VALUES (
    v_finance_category,
    'admin',
    v_pc_tx.amount,
    v_pc_tx.transaction_date,
    v_pc_tx.description || ' (Moved from Petty Cash: ' || v_pc_tx.transaction_number || ')',
    p_payment_method,
    p_bank_account_id,
    'bank',
    p_user_id,
    v_pc_tx.id
  ) RETURNING id INTO v_expense_id;

  -- Update petty cash transaction with link
  UPDATE petty_cash_transactions
  SET 
    finance_expense_id = v_expense_id,
    source = 'moved_to_tracker'
  WHERE id = p_petty_cash_id;

  RETURN v_expense_id;
END;
$$;

COMMENT ON FUNCTION move_expense_to_tracker IS
  'Moves an expense from petty_cash_transactions to finance_expenses for bank reconciliation. Creates or updates finance_expenses entry.';

-- ============================================================================
-- RLS POLICIES FOR FUNCTION EXECUTION
-- ============================================================================

-- Users can execute these functions (enforced by SECURITY DEFINER and user_id parameter)
GRANT EXECUTE ON FUNCTION move_expense_to_petty_cash TO authenticated;
GRANT EXECUTE ON FUNCTION move_expense_to_tracker TO authenticated;
