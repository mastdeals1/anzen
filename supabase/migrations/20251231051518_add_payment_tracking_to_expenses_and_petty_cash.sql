/*
  # Add Payment Method Tracking to Expenses and Petty Cash

  1. Changes to finance_expenses
    - Add payment_method column (cash, bank_transfer, check, giro, other)
    - Add bank_account_id FK to bank_accounts table
    - Add payment_reference for check/giro numbers or transfer refs
    - Add index on bank_account_id for performance

  2. Changes to petty_cash_books
    - Add replenishment_source ('cash', 'bank')
    - Add replenishment_bank_account_id FK to bank_accounts
    - Add replenishment_reference for tracking bank transfers
    - Add indexes for queries

  3. Security
    - No RLS changes needed as existing policies cover new fields
*/

-- ============================================
-- 1. Add Payment Tracking to finance_expenses
-- ============================================

-- Add payment method column
ALTER TABLE finance_expenses
ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT 'cash'
CHECK (payment_method IN ('cash', 'bank_transfer', 'check', 'giro', 'other'));

-- Add bank account reference
ALTER TABLE finance_expenses
ADD COLUMN IF NOT EXISTS bank_account_id UUID REFERENCES bank_accounts(id) ON DELETE SET NULL;

-- Add payment reference (check number, transfer ID, etc.)
ALTER TABLE finance_expenses
ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(100);

-- Add index for bank account lookups
CREATE INDEX IF NOT EXISTS idx_finance_expenses_bank_account
ON finance_expenses(bank_account_id)
WHERE bank_account_id IS NOT NULL;

-- Add comment
COMMENT ON COLUMN finance_expenses.payment_method IS 'How the expense was paid: cash, bank_transfer, check, giro, other';
COMMENT ON COLUMN finance_expenses.bank_account_id IS 'Bank account used if payment_method is bank_transfer/check/giro';
COMMENT ON COLUMN finance_expenses.payment_reference IS 'Check number, transfer reference, or giro number';

-- ============================================
-- 2. Add Replenishment Tracking to petty_cash_books
-- ============================================

-- Add replenishment source
ALTER TABLE petty_cash_books
ADD COLUMN IF NOT EXISTS replenishment_source VARCHAR(20) DEFAULT 'cash'
CHECK (replenishment_source IN ('cash', 'bank'));

-- Add bank account for replenishment
ALTER TABLE petty_cash_books
ADD COLUMN IF NOT EXISTS replenishment_bank_account_id UUID REFERENCES bank_accounts(id) ON DELETE SET NULL;

-- Add replenishment reference
ALTER TABLE petty_cash_books
ADD COLUMN IF NOT EXISTS replenishment_reference VARCHAR(100);

-- Add index
CREATE INDEX IF NOT EXISTS idx_petty_cash_books_bank_account
ON petty_cash_books(replenishment_bank_account_id)
WHERE replenishment_bank_account_id IS NOT NULL;

-- Add comments
COMMENT ON COLUMN petty_cash_books.replenishment_source IS 'Source of petty cash replenishment: cash or bank';
COMMENT ON COLUMN petty_cash_books.replenishment_bank_account_id IS 'Bank account used if replenishment_source is bank';
COMMENT ON COLUMN petty_cash_books.replenishment_reference IS 'Transfer reference or check number for bank replenishments';

-- ============================================
-- 3. Update existing records to have default values
-- ============================================

-- Set default payment_method for existing expenses
UPDATE finance_expenses
SET payment_method = 'cash'
WHERE payment_method IS NULL;

-- Set default replenishment_source for existing petty cash books
UPDATE petty_cash_books
SET replenishment_source = 'cash'
WHERE replenishment_source IS NULL;

DO $$ BEGIN
  RAISE NOTICE 'Payment tracking added to finance_expenses and petty_cash_books';
  RAISE NOTICE 'Existing records defaulted to cash payment method';
  RAISE NOTICE 'Bank account linking available for both tables';
END $$;
