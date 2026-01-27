/*
  # Migrate Cash Expenses to Petty Cash with Bank Statement Links
  
  1. What This Does
    - Adds matched_petty_cash_id to bank_statement_lines
    - Migrates cash expenses from finance_expenses to petty_cash_transactions
    - Updates bank statement links to point to petty cash instead of expenses
    - Deletes the original expense records
  
  2. Steps
    - Add new column for petty cash matching
    - Insert all cash expenses into petty cash (with source flag to skip journal creation)
    - Update bank statement lines to link to petty cash
    - Delete cash expenses from finance_expenses
  
  3. Safety
    - Preserves all bank reconciliation data
    - Maintains container and DC links
    - Skips duplicate journal entries
*/

-- Step 1: Add matched_petty_cash_id column to bank_statement_lines
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bank_statement_lines' AND column_name = 'matched_petty_cash_id'
  ) THEN
    ALTER TABLE bank_statement_lines 
    ADD COLUMN matched_petty_cash_id UUID REFERENCES petty_cash_transactions(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Step 2: Migrate cash expenses to petty cash
INSERT INTO petty_cash_transactions (
  id,
  transaction_number,
  transaction_date,
  transaction_type,
  amount,
  description,
  expense_category,
  paid_by,
  import_container_id,
  delivery_challan_id,
  document_urls,
  source,
  created_by,
  created_at
)
SELECT 
  id,
  'PCE-' || TO_CHAR(expense_date, 'YYMMDD') || '-' || LPAD(ROW_NUMBER() OVER (PARTITION BY expense_date ORDER BY created_at)::text, 4, '0') as transaction_number,
  expense_date as transaction_date,
  'expense' as transaction_type,
  amount,
  description,
  expense_category,
  paid_by,
  import_container_id,
  delivery_challan_id,
  document_urls,
  'migrated_from_expenses' as source,
  created_by,
  created_at
FROM finance_expenses
WHERE payment_method = 'cash'
ON CONFLICT (id) DO NOTHING;

-- Step 3: Update bank statement lines to link to petty cash
UPDATE bank_statement_lines
SET 
  matched_petty_cash_id = matched_expense_id,
  matched_expense_id = NULL
WHERE matched_expense_id IN (
  SELECT id FROM finance_expenses WHERE payment_method = 'cash'
);

-- Step 4: Delete the migrated records from finance_expenses
DELETE FROM finance_expenses
WHERE payment_method = 'cash';

-- Step 5: Create index for performance
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_matched_petty_cash 
  ON bank_statement_lines(matched_petty_cash_id) 
  WHERE matched_petty_cash_id IS NOT NULL;

-- Comment for clarity
COMMENT ON COLUMN bank_statement_lines.matched_petty_cash_id IS 'Links bank statement line to petty cash transaction for reconciliation';
