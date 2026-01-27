/*
  # Add Opening Balance to Bank Accounts

  1. Changes
    - Add `opening_balance` column to bank_accounts table
    - This stores the opening balance for the current financial year
    - Used for calculating running balance in Bank Ledger view

  2. Purpose
    - Enable proper Bank Ledger (Bank Book) view
    - Support Tally-style accounting with opening balances
*/

-- Add opening balance column
ALTER TABLE bank_accounts
ADD COLUMN IF NOT EXISTS opening_balance numeric(15,2) DEFAULT 0 NOT NULL;

-- Add comment
COMMENT ON COLUMN bank_accounts.opening_balance IS 'Opening balance for current financial year';
