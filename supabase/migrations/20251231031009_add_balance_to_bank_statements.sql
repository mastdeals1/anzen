/*
  # Add Balance Column to Bank Statement Lines

  1. Changes
    - Add `statement_balance` column to track running balance from bank CSV
    - This allows comparing statement balance vs calculated system balance

  2. Purpose
    - Enable reconciliation by comparing CSV balance with system-calculated balance
    - Support proper bank reconciliation workflows
*/

-- Add statement balance column
ALTER TABLE bank_statement_lines
ADD COLUMN IF NOT EXISTS statement_balance numeric(15,2);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_balance
ON bank_statement_lines(statement_balance)
WHERE statement_balance IS NOT NULL;
