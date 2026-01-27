/*
  # Add Petty Cash Linking to Bank Statement Lines
  
  1. Problem
    - Bank statement lines can match expenses and receipts
    - But they CANNOT match petty cash withdrawals
    - Missing matched_petty_cash_id column
    - No auto-matching for petty cash transactions
    
  2. Solution
    - Add matched_petty_cash_id column
    - Update auto-matching trigger to include petty cash
    - Link existing petty cash withdrawals automatically
*/

-- Step 1: Add matched_petty_cash_id column
ALTER TABLE bank_statement_lines
ADD COLUMN IF NOT EXISTS matched_petty_cash_id UUID REFERENCES petty_cash_transactions(id) ON DELETE SET NULL;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_matched_petty_cash 
ON bank_statement_lines(matched_petty_cash_id);

-- Add comment
COMMENT ON COLUMN bank_statement_lines.matched_petty_cash_id 
IS 'Links to petty cash transaction if this bank line represents a petty cash withdrawal';

-- Step 2: Create comprehensive auto-matching function
CREATE OR REPLACE FUNCTION auto_match_bank_statement_line()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_matched_petty_cash_id UUID;
  v_matched_expense_id UUID;
  v_matched_receipt_id UUID;
  v_match_tolerance NUMERIC := 1.0; -- Allow 1 rupiah tolerance
BEGIN
  -- Only auto-match if not already matched
  IF NEW.matched_petty_cash_id IS NOT NULL 
     OR NEW.matched_expense_id IS NOT NULL 
     OR NEW.matched_receipt_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Try to match PETTY CASH WITHDRAWALS (debit = money out)
  IF NEW.debit_amount > 0 THEN
    SELECT id INTO v_matched_petty_cash_id
    FROM petty_cash_transactions
    WHERE transaction_type = 'withdraw'
    AND bank_account_id = NEW.bank_account_id
    AND transaction_date = NEW.transaction_date
    AND ABS(amount - NEW.debit_amount) <= v_match_tolerance
    AND id NOT IN (
      -- Don't match if already linked to another statement line
      SELECT matched_petty_cash_id 
      FROM bank_statement_lines 
      WHERE matched_petty_cash_id IS NOT NULL
      AND id != NEW.id
    )
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_matched_petty_cash_id IS NOT NULL THEN
      NEW.matched_petty_cash_id := v_matched_petty_cash_id;
      NEW.reconciliation_status := 'matched';
      NEW.matched_at := NOW();
      RETURN NEW;
    END IF;

    -- Try to match EXPENSES (debit = money out)
    SELECT id INTO v_matched_expense_id
    FROM finance_expenses
    WHERE bank_account_id = NEW.bank_account_id
    AND expense_date = NEW.transaction_date
    AND ABS(amount - NEW.debit_amount) <= v_match_tolerance
    AND payment_method IN ('bank_transfer', 'check')
    AND id NOT IN (
      SELECT matched_expense_id 
      FROM bank_statement_lines 
      WHERE matched_expense_id IS NOT NULL
      AND id != NEW.id
    )
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_matched_expense_id IS NOT NULL THEN
      NEW.matched_expense_id := v_matched_expense_id;
      NEW.reconciliation_status := 'matched';
      NEW.matched_at := NOW();
      RETURN NEW;
    END IF;
  END IF;

  -- Try to match RECEIPTS (credit = money in)
  IF NEW.credit_amount > 0 THEN
    SELECT id INTO v_matched_receipt_id
    FROM receipt_vouchers
    WHERE bank_account_id = NEW.bank_account_id
    AND voucher_date = NEW.transaction_date
    AND ABS(amount - NEW.credit_amount) <= v_match_tolerance
    AND payment_method IN ('bank_transfer', 'check')
    AND id NOT IN (
      SELECT matched_receipt_id 
      FROM bank_statement_lines 
      WHERE matched_receipt_id IS NOT NULL
      AND id != NEW.id
    )
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_matched_receipt_id IS NOT NULL THEN
      NEW.matched_receipt_id := v_matched_receipt_id;
      NEW.reconciliation_status := 'matched';
      NEW.matched_at := NOW();
      RETURN NEW;
    END IF;
  END IF;

  -- No match found - mark as unmatched
  IF NEW.reconciliation_status IS NULL THEN
    NEW.reconciliation_status := 'unmatched';
  END IF;

  RETURN NEW;
END;
$$;

-- Drop old trigger if exists and create new one
DROP TRIGGER IF EXISTS trg_auto_match_bank_statement ON bank_statement_lines;

CREATE TRIGGER trg_auto_match_bank_statement
  BEFORE INSERT OR UPDATE ON bank_statement_lines
  FOR EACH ROW
  WHEN (NEW.matched_petty_cash_id IS NULL 
    AND NEW.matched_expense_id IS NULL 
    AND NEW.matched_receipt_id IS NULL)
  EXECUTE FUNCTION auto_match_bank_statement_line();

-- Step 3: Auto-link existing unmatched petty cash transactions
UPDATE bank_statement_lines bsl
SET 
  matched_petty_cash_id = pct.id,
  reconciliation_status = 'matched',
  matched_at = NOW()
FROM petty_cash_transactions pct
WHERE bsl.reconciliation_status = 'unmatched'
AND bsl.matched_petty_cash_id IS NULL
AND bsl.matched_expense_id IS NULL
AND bsl.matched_receipt_id IS NULL
AND bsl.debit_amount > 0
AND pct.transaction_type = 'withdraw'
AND pct.bank_account_id = bsl.bank_account_id
AND pct.transaction_date = bsl.transaction_date
AND ABS(pct.amount - bsl.debit_amount) <= 1.0
AND pct.id NOT IN (
  SELECT matched_petty_cash_id 
  FROM bank_statement_lines 
  WHERE matched_petty_cash_id IS NOT NULL
);

COMMENT ON FUNCTION auto_match_bank_statement_line() 
IS 'Automatically matches bank statement lines with petty cash, expenses, and receipts based on date, amount, and bank account';

SELECT 'Bank statement lines now support petty cash linking with auto-matching' as status;
