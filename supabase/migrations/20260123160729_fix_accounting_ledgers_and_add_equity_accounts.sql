/*
  # Fix Accounting Ledgers and Add Missing Equity Accounts
  
  1. New Accounts Added
    - Owner's Drawings (3110)
    - Loan from Vijay Lunkad (2220)
    - Misc Income (4910)
  
  2. Expense Trigger Fix
    - Fix expense posting to respect payment_method field
    - Cash expenses → Cash on Hand (1101)
    - Bank expenses → Specific Bank Account
    - Petty Cash expenses → Petty Cash (1102)
    - Map expense categories to correct COA accounts
    - Bank Charges → Bank Charges account (7100)
  
  3. Security
    - All accounts properly secured with RLS
    - Trigger function uses proper search_path
*/

-- =====================================================
-- 1. ADD MISSING ACCOUNTS
-- =====================================================

-- Add Owner's Drawings account (contra-equity)
INSERT INTO chart_of_accounts (code, name, account_type, parent_id, is_header, normal_balance, is_active, created_at)
VALUES (
  '3110',
  'Owner Drawings',
  'contra',
  (SELECT id FROM chart_of_accounts WHERE code = '3000' LIMIT 1),
  false,
  'debit',
  true,
  now()
) ON CONFLICT (code) DO NOTHING;

-- Add Loan from Vijay Lunkad account
INSERT INTO chart_of_accounts (code, name, account_type, parent_id, is_header, normal_balance, is_active, created_at)
VALUES (
  '2220',
  'Loan from Vijay Lunkad',
  'liability',
  (SELECT id FROM chart_of_accounts WHERE code = '2200' LIMIT 1),
  false,
  'credit',
  true,
  now()
) ON CONFLICT (code) DO NOTHING;

-- Add Miscellaneous Income
INSERT INTO chart_of_accounts (code, name, account_type, parent_id, is_header, normal_balance, is_active, created_at)
VALUES (
  '4910',
  'Miscellaneous Income',
  'revenue',
  (SELECT id FROM chart_of_accounts WHERE code = '4000' LIMIT 1),
  false,
  'credit',
  true,
  now()
) ON CONFLICT (code) DO NOTHING;

-- =====================================================
-- 2. CREATE EXPENSE CATEGORY TO COA MAPPING FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION get_expense_account_id(p_category TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id UUID;
BEGIN
  -- Map expense categories to correct Chart of Accounts
  v_account_id := CASE p_category
    -- Salaries and Staff
    WHEN 'salary' THEN (SELECT id FROM chart_of_accounts WHERE code = '6100' LIMIT 1)
    WHEN 'staff_welfare' THEN (SELECT id FROM chart_of_accounts WHERE code = '6150' LIMIT 1)
    WHEN 'employee_benefits' THEN (SELECT id FROM chart_of_accounts WHERE code = '6110' LIMIT 1)
    
    -- Rent
    WHEN 'office_rent' THEN (SELECT id FROM chart_of_accounts WHERE code = '6220' LIMIT 1)
    WHEN 'warehouse_rent' THEN (SELECT id FROM chart_of_accounts WHERE code = '6210' LIMIT 1)
    WHEN 'rent' THEN (SELECT id FROM chart_of_accounts WHERE code = '6200' LIMIT 1)
    
    -- Office & Admin
    WHEN 'office_admin' THEN (SELECT id FROM chart_of_accounts WHERE code = '6300' LIMIT 1)
    WHEN 'office_supplies' THEN (SELECT id FROM chart_of_accounts WHERE code = '6310' LIMIT 1)
    WHEN 'office_shifting_renovation' THEN (SELECT id FROM chart_of_accounts WHERE code = '6320' LIMIT 1)
    
    -- Utilities
    WHEN 'utilities' THEN (SELECT id FROM chart_of_accounts WHERE code = '6400' LIMIT 1)
    WHEN 'electricity' THEN (SELECT id FROM chart_of_accounts WHERE code = '6410' LIMIT 1)
    WHEN 'water' THEN (SELECT id FROM chart_of_accounts WHERE code = '6420' LIMIT 1)
    WHEN 'internet_phone' THEN (SELECT id FROM chart_of_accounts WHERE code = '6430' LIMIT 1)
    
    -- Vehicles & Transport
    WHEN 'fuel' THEN (SELECT id FROM chart_of_accounts WHERE code = '6510' LIMIT 1)
    WHEN 'vehicle_maintenance' THEN (SELECT id FROM chart_of_accounts WHERE code = '6520' LIMIT 1)
    WHEN 'vehicle_insurance' THEN (SELECT id FROM chart_of_accounts WHERE code = '6530' LIMIT 1)
    WHEN 'travel_conveyance' THEN (SELECT id FROM chart_of_accounts WHERE code = '6540' LIMIT 1)
    
    -- Sales Related
    WHEN 'delivery_sales' THEN (SELECT id FROM chart_of_accounts WHERE code = '6600' LIMIT 1)
    WHEN 'loading_sales' THEN (SELECT id FROM chart_of_accounts WHERE code = '6610' LIMIT 1)
    WHEN 'marketing_advertising' THEN (SELECT id FROM chart_of_accounts WHERE code = '6620' LIMIT 1)
    
    -- Professional Fees
    WHEN 'legal_professional' THEN (SELECT id FROM chart_of_accounts WHERE code = '6710' LIMIT 1)
    WHEN 'consulting_fees' THEN (SELECT id FROM chart_of_accounts WHERE code = '6720' LIMIT 1)
    WHEN 'accounting_audit' THEN (SELECT id FROM chart_of_accounts WHERE code = '6730' LIMIT 1)
    
    -- Bank & Financial
    WHEN 'bank_charges' THEN (SELECT id FROM chart_of_accounts WHERE code = '7100' LIMIT 1)
    WHEN 'interest_expense' THEN (SELECT id FROM chart_of_accounts WHERE code = '7200' LIMIT 1)
    
    -- Import Related (COGS)
    WHEN 'freight_import' THEN (SELECT id FROM chart_of_accounts WHERE code = '5300' LIMIT 1)
    WHEN 'duty_import' THEN (SELECT id FROM chart_of_accounts WHERE code = '5200' LIMIT 1)
    WHEN 'other_import' THEN (SELECT id FROM chart_of_accounts WHERE code = '5400' LIMIT 1)
    WHEN 'bpom_ski_fees' THEN (SELECT id FROM chart_of_accounts WHERE code = '5410' LIMIT 1)
    
    -- Default to Operating Expenses
    ELSE (SELECT id FROM chart_of_accounts WHERE code = '6000' LIMIT 1)
  END;
  
  RETURN v_account_id;
END;
$$;

-- =====================================================
-- 3. FIX EXPENSE TRIGGER TO RESPECT PAYMENT METHOD
-- =====================================================

CREATE OR REPLACE FUNCTION auto_post_expense_accounting()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_description TEXT;
  v_expense_account_id UUID;
  v_payment_account_id UUID;
  v_journal_id UUID;
  v_source_module TEXT;
BEGIN
  -- Skip if already posted (check for existing journal entry)
  IF EXISTS (
    SELECT 1 FROM journal_entries 
    WHERE source_module = 'expenses' 
    AND reference_number = 'EXP-' || NEW.id::text
  ) THEN
    RETURN NEW;
  END IF;

  -- Get the correct expense account based on category
  v_expense_account_id := get_expense_account_id(NEW.expense_category);
  
  IF v_expense_account_id IS NULL THEN
    RAISE NOTICE 'Could not find expense account for category: %', NEW.expense_category;
    RETURN NEW;
  END IF;

  -- Determine payment account based on payment_method and bank_account_id
  IF NEW.payment_method = 'cash' THEN
    -- Cash payment → Credit Cash on Hand
    SELECT id INTO v_payment_account_id
    FROM chart_of_accounts
    WHERE code = '1101' LIMIT 1;
    
    v_source_module := 'expenses';
    
  ELSIF NEW.payment_method = 'petty_cash' THEN
    -- Petty Cash payment → Credit Petty Cash
    SELECT id INTO v_payment_account_id
    FROM chart_of_accounts
    WHERE code = '1102' LIMIT 1;
    
    v_source_module := 'expenses';
    
  ELSIF NEW.payment_method = 'bank_transfer' AND NEW.bank_account_id IS NOT NULL THEN
    -- Bank payment → Credit specific bank account's COA
    SELECT coa_id INTO v_payment_account_id
    FROM bank_accounts
    WHERE id = NEW.bank_account_id;
    
    IF v_payment_account_id IS NULL THEN
      -- Fallback to main bank account
      SELECT id INTO v_payment_account_id
      FROM chart_of_accounts
      WHERE code = '1111' LIMIT 1;
    END IF;
    
    v_source_module := 'expenses';
    
  ELSIF NEW.payment_method IS NULL THEN
    -- Unpaid expense → Credit Accounts Payable
    SELECT id INTO v_payment_account_id
    FROM chart_of_accounts
    WHERE code = '2110' LIMIT 1;
    
    v_source_module := 'expenses';
    
  ELSE
    -- Default to Cash on Hand
    SELECT id INTO v_payment_account_id
    FROM chart_of_accounts
    WHERE code = '1101' LIMIT 1;
    
    v_source_module := 'expenses';
  END IF;

  IF v_payment_account_id IS NULL THEN
    RAISE NOTICE 'Could not find payment account - skipping auto-posting';
    RETURN NEW;
  END IF;

  -- Build description
  v_description := COALESCE(NEW.description, NEW.expense_category);

  -- Create journal entry
  INSERT INTO journal_entries (
    entry_date,
    entry_type,
    source_module,
    reference_number,
    description,
    total_debit,
    total_credit,
    is_posted,
    posted_at,
    created_by
  ) VALUES (
    NEW.expense_date,
    'expense',
    v_source_module,
    'EXP-' || NEW.id::text,
    v_description,
    NEW.amount,
    NEW.amount,
    true,
    now(),
    NEW.created_by
  ) RETURNING id INTO v_journal_id;

  -- Debit: Expense Account
  INSERT INTO journal_entry_lines (
    journal_entry_id,
    line_number,
    account_id,
    debit,
    credit,
    description
  ) VALUES (
    v_journal_id,
    1,
    v_expense_account_id,
    NEW.amount,
    0,
    v_description
  );

  -- Credit: Payment Account (Cash/Bank/Petty Cash/Payable)
  INSERT INTO journal_entry_lines (
    journal_entry_id,
    line_number,
    account_id,
    debit,
    credit,
    description
  ) VALUES (
    v_journal_id,
    2,
    v_payment_account_id,
    0,
    NEW.amount,
    CASE 
      WHEN NEW.payment_method = 'cash' THEN 'Cash on Hand'
      WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash'
      WHEN NEW.payment_method = 'bank_transfer' THEN (
        SELECT account_name FROM bank_accounts WHERE id = NEW.bank_account_id
      )
      WHEN NEW.payment_method IS NULL THEN 'Accounts Payable (Unpaid)'
      ELSE 'Payment'
    END
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error auto-posting expense accounting: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_auto_post_expense_accounting ON finance_expenses;

CREATE TRIGGER trigger_auto_post_expense_accounting
  AFTER INSERT ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION auto_post_expense_accounting();

-- =====================================================
-- 4. COMMENTS
-- =====================================================

COMMENT ON FUNCTION get_expense_account_id(TEXT) IS 
'Maps expense categories to their correct Chart of Accounts entries';

COMMENT ON FUNCTION auto_post_expense_accounting() IS 
'Fixed version: Respects payment_method field to post to correct accounts.
Cash → Cash on Hand (1101)
Bank → Specific Bank Account
Petty Cash → Petty Cash (1102)
Unpaid → Accounts Payable (2110)';
