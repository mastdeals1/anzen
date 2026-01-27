/*
  # Add Chart of Accounts link to Bank Accounts
  
  1. Problem
    - The petty cash trigger tries to get coa_id from bank_accounts
    - This column doesn't exist, causing "column coa_id does not exist" error
  
  2. Solution
    - Add coa_id column to bank_accounts table
    - This links each bank account to its corresponding Chart of Accounts entry
    - Add foreign key constraint for data integrity
*/

-- Add coa_id column to bank_accounts
ALTER TABLE bank_accounts 
ADD COLUMN IF NOT EXISTS coa_id UUID REFERENCES chart_of_accounts(id);

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_bank_accounts_coa_id ON bank_accounts(coa_id);

-- Add helpful comment
COMMENT ON COLUMN bank_accounts.coa_id IS 'Links to the corresponding Chart of Accounts entry for this bank account';

SELECT 'Bank accounts now linked to Chart of Accounts via coa_id column' as status;
