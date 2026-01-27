/*
  # Add Voucher Number to Finance Expenses for Bank Reconciliation

  1. Changes
    - Add `voucher_number` column to `finance_expenses` table
    - Add index for faster lookups during bank reconciliation matching
  
  2. Purpose
    - Enable easy matching of bank transactions to expense vouchers
    - Support auto-matching by voucher number
    - Improve reconciliation workflow
*/

-- Add voucher_number field if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'finance_expenses' AND column_name = 'voucher_number'
  ) THEN
    ALTER TABLE finance_expenses ADD COLUMN voucher_number TEXT;
  END IF;
END $$;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_finance_expenses_voucher_number 
ON finance_expenses(voucher_number) 
WHERE voucher_number IS NOT NULL;

-- Add comment
COMMENT ON COLUMN finance_expenses.voucher_number IS 'Expense voucher number for bank reconciliation matching (e.g., PV-001, EXP-2025-001)';
