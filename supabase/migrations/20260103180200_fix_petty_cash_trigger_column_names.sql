/*
  # Fix Petty Cash Trigger Column Names
  
  1. Problem
    - The `post_petty_cash_to_journal()` trigger function references wrong column names
    - Uses `account_code` and `account_name` instead of `code` and `name`
    - This causes errors when moving expenses from bank to petty cash
  
  2. Solution
    - Update trigger function to use correct column names: `code` and `name`
    - This fixes the "column account_code does not exist" error
*/

CREATE OR REPLACE FUNCTION post_petty_cash_to_journal()
RETURNS TRIGGER AS $$
DECLARE
  v_journal_id UUID;
  v_petty_cash_account_id UUID;
  v_expense_account_id UUID;
  v_bank_account_coa_id UUID;
BEGIN
  -- Get petty cash account (1-1030 or similar) - FIXED: using 'code' not 'account_code'
  SELECT id INTO v_petty_cash_account_id
  FROM chart_of_accounts
  WHERE code LIKE '1-103%' OR name ILIKE '%petty%cash%'
  LIMIT 1;

  IF v_petty_cash_account_id IS NULL THEN
    -- Create petty cash account if not exists - FIXED: using 'code' and 'name'
    INSERT INTO chart_of_accounts (code, name, account_type, parent_id, is_active)
    VALUES ('1-1030', 'Petty Cash', 'asset', NULL, true)
    RETURNING id INTO v_petty_cash_account_id;
  END IF;

  IF NEW.transaction_type = 'withdraw' THEN
    -- Withdraw: Dr Petty Cash, Cr Bank
    -- Get linked bank account's COA id
    SELECT coa_id INTO v_bank_account_coa_id
    FROM bank_accounts
    WHERE id = NEW.bank_account_id;

    IF v_bank_account_coa_id IS NULL THEN
      -- Use default bank account - FIXED: using 'code' not 'account_code'
      SELECT id INTO v_bank_account_coa_id
      FROM chart_of_accounts
      WHERE code LIKE '1-102%' OR name ILIKE '%bank%'
      LIMIT 1;
    END IF;

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_date, reference_type, reference_id, description, 
      status, created_by, posted_at
    ) VALUES (
      NEW.transaction_date, 'petty_cash', NEW.id,
      'Cash withdrawal: ' || NEW.description,
      'posted', NEW.created_by, NOW()
    ) RETURNING id INTO v_journal_id;

    -- Dr Petty Cash
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit_amount, credit_amount, description)
    VALUES (v_journal_id, v_petty_cash_account_id, NEW.amount, 0, 'Cash withdrawal');

    -- Cr Bank
    IF v_bank_account_coa_id IS NOT NULL THEN
      INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit_amount, credit_amount, description)
      VALUES (v_journal_id, v_bank_account_coa_id, 0, NEW.amount, 'Cash withdrawal to petty cash');
    END IF;

  ELSIF NEW.transaction_type = 'expense' THEN
    -- Expense: Dr Expense, Cr Petty Cash
    -- Get expense account based on category - FIXED: using 'code' and 'name'
    SELECT id INTO v_expense_account_id
    FROM chart_of_accounts
    WHERE account_type = 'expense'
    AND (
      CASE 
        WHEN NEW.expense_category = 'Office Supplies' THEN name ILIKE '%office%' OR code = '6-1010'
        WHEN NEW.expense_category = 'Transportation' THEN name ILIKE '%transport%' OR code = '6-1020'
        WHEN NEW.expense_category = 'Meals & Entertainment' THEN name ILIKE '%entertainment%' OR code = '6-1030'
        WHEN NEW.expense_category = 'Postage & Courier' THEN name ILIKE '%postage%' OR code = '6-1040'
        WHEN NEW.expense_category = 'Cleaning & Maintenance' THEN name ILIKE '%maintenance%' OR code = '6-1050'
        WHEN NEW.expense_category = 'Utilities' THEN name ILIKE '%utilities%' OR code = '6-1060'
        ELSE code = '6-1090' OR name ILIKE '%misc%'
      END
    )
    LIMIT 1;

    IF v_expense_account_id IS NULL THEN
      -- Use general expense account
      SELECT id INTO v_expense_account_id
      FROM chart_of_accounts
      WHERE account_type = 'expense'
      LIMIT 1;
    END IF;

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_date, reference_type, reference_id, description, 
      status, created_by, posted_at
    ) VALUES (
      NEW.transaction_date, 'petty_cash', NEW.id,
      'Petty cash expense: ' || NEW.description,
      'posted', NEW.created_by, NOW()
    ) RETURNING id INTO v_journal_id;

    -- Dr Expense
    IF v_expense_account_id IS NOT NULL THEN
      INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit_amount, credit_amount, description)
      VALUES (v_journal_id, v_expense_account_id, NEW.amount, 0, COALESCE(NEW.expense_category, 'Petty cash expense'));
    END IF;

    -- Cr Petty Cash
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit_amount, credit_amount, description)
    VALUES (v_journal_id, v_petty_cash_account_id, 0, NEW.amount, 'Petty cash expense');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'pg_temp';

SELECT 'Petty cash trigger function fixed - now using correct column names (code and name)' as status;
