/*
  # Fix Bank Accounts - Create Separate COA for IDR and USD
  
  1. Problem
    - Both BCA IDR and BCA USD bank accounts have coa_id = NULL
    - Receipt voucher trigger falls back to generic code 1111 "Bank BCA"
    - ALL receipts (both IDR and USD) post to the SAME generic account
    - This causes bank ledger to show ALL receipts in BOTH accounts
  
  2. Solution
    - Create TWO separate Chart of Accounts entries:
      * 111101: Bank BCA - IDR (for account 0930201022)
      * 111102: Bank BCA - USD (for account 0930201014)
    - Link bank_accounts records to their specific COAs
    - Update existing journal entries to use correct accounts
  
  3. Changes
    - Add 2 new COA accounts
    - Update bank_accounts.coa_id for both accounts
    - Move existing receipt journal entries to correct account
*/

-- Step 1: Create separate COA accounts for BCA IDR and BCA USD
INSERT INTO chart_of_accounts (code, name, account_type, parent_id, is_active)
VALUES 
  ('111101', 'Bank BCA - IDR (0930201022)', 'asset', 
   (SELECT id FROM chart_of_accounts WHERE code = '1110'), true),
  ('111102', 'Bank BCA - USD (0930201014)', 'asset', 
   (SELECT id FROM chart_of_accounts WHERE code = '1110'), true)
ON CONFLICT (code) DO NOTHING;

-- Step 2: Link bank accounts to their specific COAs
UPDATE bank_accounts
SET coa_id = (SELECT id FROM chart_of_accounts WHERE code = '111101')
WHERE account_number = '0930 2010 22' 
  AND alias = 'BCA IDR';

UPDATE bank_accounts
SET coa_id = (SELECT id FROM chart_of_accounts WHERE code = '111102')
WHERE account_number = '0930 2010 14' 
  AND alias = 'BCA USD';

-- Step 3: Update existing receipt voucher journal entries to use correct account
-- All existing receipts went to BCA IDR account, so move them from 1111 to 111101
UPDATE journal_entry_lines
SET account_id = (SELECT id FROM chart_of_accounts WHERE code = '111101')
WHERE account_id = (SELECT id FROM chart_of_accounts WHERE code = '1111')
  AND journal_entry_id IN (
    SELECT id FROM journal_entries WHERE source_module = 'receipt'
  )
  AND debit > 0;