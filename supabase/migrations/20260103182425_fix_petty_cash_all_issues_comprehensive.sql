/*
  # Comprehensive Petty Cash Fix - All Column Mismatches
  
  1. Issues Found
    a) Multiple versions of post_petty_cash_to_journal function exist
    b) Wrong column names in journal_entries:
       - reference_type → source_module
       - status → is_posted (boolean)
    c) Wrong column names in journal_entry_lines:
       - debit_amount → debit
       - credit_amount → credit
    d) Missing entry_number generation
    e) Missing line_number in journal_entry_lines
    
  2. Solution
    - Drop all versions of the function
    - Recreate with correct column names matching actual schema
    - Add proper entry_number and line_number generation
*/

-- Step 1: Drop trigger first
DROP TRIGGER IF EXISTS trigger_post_petty_cash ON petty_cash_transactions;

-- Step 2: Drop all versions of the function
DROP FUNCTION IF EXISTS post_petty_cash_to_journal();
DROP FUNCTION IF EXISTS post_petty_cash_to_journal(uuid);

-- Step 3: Create corrected function
CREATE OR REPLACE FUNCTION post_petty_cash_to_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_journal_id UUID;
  v_petty_cash_account_id UUID;
  v_expense_account_id UUID;
  v_bank_account_coa_id UUID;
  v_entry_number TEXT;
  v_line_num INTEGER;
BEGIN
  -- Generate journal entry number
  SELECT COALESCE(
    'JE' || TO_CHAR(NOW(), 'YYYYMM') || '-' || 
    LPAD((COUNT(*) FILTER (WHERE entry_number LIKE 'JE' || TO_CHAR(NOW(), 'YYYYMM') || '%') + 1)::TEXT, 4, '0'),
    'JE' || TO_CHAR(NOW(), 'YYYYMM') || '-0001'
  )
  INTO v_entry_number
  FROM journal_entries;

  -- Get petty cash account
  SELECT id INTO v_petty_cash_account_id
  FROM chart_of_accounts
  WHERE code LIKE '1-103%' OR LOWER(name) LIKE '%petty%cash%'
  LIMIT 1;

  -- Create petty cash account if missing
  IF v_petty_cash_account_id IS NULL THEN
    INSERT INTO chart_of_accounts (code, name, account_type, is_active)
    VALUES ('1-1030', 'Petty Cash', 'asset', true)
    RETURNING id INTO v_petty_cash_account_id;
  END IF;

  IF NEW.transaction_type = 'withdraw' THEN
    -- WITHDRAWAL: Dr Petty Cash, Cr Bank
    
    -- Get bank account's COA link
    IF NEW.bank_account_id IS NOT NULL THEN
      SELECT coa_id INTO v_bank_account_coa_id
      FROM bank_accounts
      WHERE id = NEW.bank_account_id;
    END IF;

    -- Fallback to default bank account
    IF v_bank_account_coa_id IS NULL THEN
      SELECT id INTO v_bank_account_coa_id
      FROM chart_of_accounts
      WHERE code LIKE '1-102%' OR LOWER(name) LIKE '%bank%'
      ORDER BY code
      LIMIT 1;
    END IF;

    -- Create journal entry with CORRECT columns
    INSERT INTO journal_entries (
      entry_number,
      entry_date,
      source_module,    -- CORRECT (not reference_type)
      reference_id,
      description,
      is_posted,        -- CORRECT (not status, boolean)
      created_by,
      posted_at
    ) VALUES (
      v_entry_number,
      NEW.transaction_date,
      'petty_cash',
      NEW.id,
      'Petty cash withdrawal: ' || COALESCE(NEW.description, ''),
      true,             -- CORRECT (boolean not 'posted')
      NEW.created_by,
      NOW()
    ) RETURNING id INTO v_journal_id;

    v_line_num := 1;

    -- Dr Petty Cash with CORRECT columns
    INSERT INTO journal_entry_lines (
      journal_entry_id,
      line_number,
      account_id,
      debit,            -- CORRECT (not debit_amount)
      credit,           -- CORRECT (not credit_amount)
      description
    ) VALUES (
      v_journal_id,
      v_line_num,
      v_petty_cash_account_id,
      NEW.amount,
      0,
      'Cash withdrawal'
    );

    -- Cr Bank with CORRECT columns
    IF v_bank_account_coa_id IS NOT NULL THEN
      v_line_num := v_line_num + 1;
      INSERT INTO journal_entry_lines (
        journal_entry_id,
        line_number,
        account_id,
        debit,          -- CORRECT (not debit_amount)
        credit,         -- CORRECT (not credit_amount)
        description
      ) VALUES (
        v_journal_id,
        v_line_num,
        v_bank_account_coa_id,
        0,
        NEW.amount,
        'Transfer to petty cash'
      );
    END IF;

  ELSIF NEW.transaction_type = 'expense' THEN
    -- EXPENSE: Dr Expense, Cr Petty Cash
    
    -- Map category to expense account
    SELECT id INTO v_expense_account_id
    FROM chart_of_accounts
    WHERE account_type = 'expense'
    AND (
      CASE 
        WHEN NEW.expense_category = 'Office Supplies' THEN LOWER(name) LIKE '%office%' OR code = '6-1010'
        WHEN NEW.expense_category = 'Transportation' THEN LOWER(name) LIKE '%transport%' OR code = '6-1020'
        WHEN NEW.expense_category = 'Meals & Entertainment' THEN LOWER(name) LIKE '%entertainment%' OR code = '6-1030'
        WHEN NEW.expense_category = 'Postage & Courier' THEN LOWER(name) LIKE '%postage%' OR code = '6-1040'
        WHEN NEW.expense_category = 'Cleaning & Maintenance' THEN LOWER(name) LIKE '%maintenance%' OR code = '6-1050'
        WHEN NEW.expense_category = 'Utilities' THEN LOWER(name) LIKE '%utilities%' OR code = '6-1060'
        ELSE code = '6-1090' OR LOWER(name) LIKE '%misc%'
      END
    )
    ORDER BY code
    LIMIT 1;

    -- Fallback to any expense account
    IF v_expense_account_id IS NULL THEN
      SELECT id INTO v_expense_account_id
      FROM chart_of_accounts
      WHERE account_type = 'expense'
      ORDER BY code
      LIMIT 1;
    END IF;

    -- Create journal entry with CORRECT columns
    INSERT INTO journal_entries (
      entry_number,
      entry_date,
      source_module,    -- CORRECT (not reference_type)
      reference_id,
      description,
      is_posted,        -- CORRECT (not status, boolean)
      created_by,
      posted_at
    ) VALUES (
      v_entry_number,
      NEW.transaction_date,
      'petty_cash',
      NEW.id,
      'Petty cash expense: ' || COALESCE(NEW.description, ''),
      true,             -- CORRECT (boolean not 'posted')
      NEW.created_by,
      NOW()
    ) RETURNING id INTO v_journal_id;

    v_line_num := 1;

    -- Dr Expense with CORRECT columns
    IF v_expense_account_id IS NOT NULL THEN
      INSERT INTO journal_entry_lines (
        journal_entry_id,
        line_number,
        account_id,
        debit,          -- CORRECT (not debit_amount)
        credit,         -- CORRECT (not credit_amount)
        description
      ) VALUES (
        v_journal_id,
        v_line_num,
        v_expense_account_id,
        NEW.amount,
        0,
        COALESCE(NEW.expense_category, 'Petty cash expense')
      );
      
      v_line_num := v_line_num + 1;
    END IF;

    -- Cr Petty Cash with CORRECT columns
    INSERT INTO journal_entry_lines (
      journal_entry_id,
      line_number,
      account_id,
      debit,            -- CORRECT (not debit_amount)
      credit,           -- CORRECT (not credit_amount)
      description
    ) VALUES (
      v_journal_id,
      v_line_num,
      v_petty_cash_account_id,
      0,
      NEW.amount,
      'Petty cash payment'
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Step 4: Recreate trigger
CREATE TRIGGER trigger_post_petty_cash
  AFTER INSERT ON petty_cash_transactions
  FOR EACH ROW
  EXECUTE FUNCTION post_petty_cash_to_journal();

COMMENT ON FUNCTION post_petty_cash_to_journal() 
IS 'Posts petty cash transactions to journal entries with correct column names matching actual schema';

SELECT 'Petty cash trigger fixed with correct column names' as status;
