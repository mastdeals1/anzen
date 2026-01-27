/*
  # Fix Move Expense to Petty Cash - Payment Method Constraint

  ## Problem
  The `move_expense_to_petty_cash()` function was setting `payment_method = 'petty_cash'`
  but the finance_expenses table check constraint only allows:
  - 'cash'
  - 'bank_transfer'
  - 'cheque'
  - 'credit_card'
  - 'other'

  ## Solution
  Update the function to use `payment_method = 'cash'` instead of 'petty_cash'
  since the expense is being paid via cash from petty cash.

  ## Changes
  1. Update move_expense_to_petty_cash to set payment_method = 'cash'
*/

-- Drop and recreate the function with fix
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
  -- Use 'cash' payment method (allowed by constraint) not 'petty_cash'
  UPDATE finance_expenses
  SET 
    petty_cash_transaction_id = v_petty_cash_tx_id,
    payment_method = 'cash',
    paid_by = 'cash'
  WHERE id = p_expense_id;

  RETURN v_petty_cash_tx_id;
END;
$$;

COMMENT ON FUNCTION move_expense_to_petty_cash IS
  'Moves an expense from finance_expenses to petty_cash_transactions. Creates link and updates payment method to cash (petty cash payments are recorded as cash).';