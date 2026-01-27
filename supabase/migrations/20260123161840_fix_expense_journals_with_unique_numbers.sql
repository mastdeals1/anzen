/*
  # Fix ALL Expense Journal Entries with Unique Numbers
  
  1. Problem
    - 63+ expenses paid via bank show "Cash on Hand" in journals
    - Expense categories mapped to wrong COA accounts
    - Entry number generation causing duplicates
  
  2. Solution
    - Delete ALL expense journal entries
    - Fix expense category mapping
    - Recreate entries with sequential unique numbers
    - Update trigger for future expenses
  
  3. Result
    - Bank expenses → Bank BCA IDR/USD accounts
    - Cash expenses → Cash on Hand
    - Correct expense categories
*/

-- =====================================================
-- 1. DELETE ALL INCORRECT EXPENSE JOURNAL ENTRIES
-- =====================================================

DO $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  -- Delete lines first
  DELETE FROM journal_entry_lines
  WHERE journal_entry_id IN (
    SELECT id FROM journal_entries 
    WHERE source_module = 'expenses'
  );
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % journal entry lines', v_deleted_count;
  
  -- Delete journal entries
  DELETE FROM journal_entries 
  WHERE source_module = 'expenses';
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % journal entries', v_deleted_count;
END $$;

-- =====================================================
-- 2. FIX EXPENSE CATEGORY TO COA MAPPING FUNCTION
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
  v_account_id := CASE p_category
    WHEN 'salary' THEN (SELECT id FROM chart_of_accounts WHERE code = '6100' LIMIT 1)
    WHEN 'staff_welfare' THEN (SELECT id FROM chart_of_accounts WHERE code = '6150' LIMIT 1)
    WHEN 'employee_benefits' THEN (SELECT id FROM chart_of_accounts WHERE code = '6110' LIMIT 1)
    WHEN 'office_rent' THEN (SELECT id FROM chart_of_accounts WHERE code = '6220' LIMIT 1)
    WHEN 'warehouse_rent' THEN (SELECT id FROM chart_of_accounts WHERE code = '6210' LIMIT 1)
    WHEN 'rent' THEN (SELECT id FROM chart_of_accounts WHERE code = '6200' LIMIT 1)
    WHEN 'utilities' THEN (SELECT id FROM chart_of_accounts WHERE code = '6300' LIMIT 1)
    WHEN 'electricity' THEN (SELECT id FROM chart_of_accounts WHERE code = '6310' LIMIT 1)
    WHEN 'water' THEN (SELECT id FROM chart_of_accounts WHERE code = '6320' LIMIT 1)
    WHEN 'internet_phone' THEN (SELECT id FROM chart_of_accounts WHERE code = '6330' LIMIT 1)
    WHEN 'office_supplies' THEN (SELECT id FROM chart_of_accounts WHERE code = '6400' LIMIT 1)
    WHEN 'office_admin' THEN (SELECT id FROM chart_of_accounts WHERE code = '6410' LIMIT 1)
    WHEN 'office_shifting_renovation' THEN (SELECT id FROM chart_of_accounts WHERE code = '6420' LIMIT 1)
    WHEN 'fuel' THEN (SELECT id FROM chart_of_accounts WHERE code = '6500' LIMIT 1)
    WHEN 'vehicle_maintenance' THEN (SELECT id FROM chart_of_accounts WHERE code = '6500' LIMIT 1)
    WHEN 'travel_conveyance' THEN (SELECT id FROM chart_of_accounts WHERE code = '6500' LIMIT 1)
    WHEN 'delivery_sales' THEN (SELECT id FROM chart_of_accounts WHERE code = '6510' LIMIT 1)
    WHEN 'loading_sales' THEN (SELECT id FROM chart_of_accounts WHERE code = '6520' LIMIT 1)
    WHEN 'marketing_advertising' THEN (SELECT id FROM chart_of_accounts WHERE code = '6600' LIMIT 1)
    WHEN 'legal_professional' THEN (SELECT id FROM chart_of_accounts WHERE code = '6700' LIMIT 1)
    WHEN 'consulting_fees' THEN (SELECT id FROM chart_of_accounts WHERE code = '6700' LIMIT 1)
    WHEN 'accounting_audit' THEN (SELECT id FROM chart_of_accounts WHERE code = '6700' LIMIT 1)
    WHEN 'bpom_ski_fees' THEN (SELECT id FROM chart_of_accounts WHERE code = '6710' LIMIT 1)
    WHEN 'bank_charges' THEN (SELECT id FROM chart_of_accounts WHERE code = '7100' LIMIT 1)
    WHEN 'interest_expense' THEN (SELECT id FROM chart_of_accounts WHERE code = '7200' LIMIT 1)
    WHEN 'freight_import' THEN (SELECT id FROM chart_of_accounts WHERE code = '5300' LIMIT 1)
    WHEN 'duty_import' THEN (SELECT id FROM chart_of_accounts WHERE code = '5200' LIMIT 1)
    WHEN 'other_import' THEN (SELECT id FROM chart_of_accounts WHERE code = '5400' LIMIT 1)
    ELSE (SELECT id FROM chart_of_accounts WHERE code = '6900' LIMIT 1)
  END;
  
  IF v_account_id IS NULL THEN
    SELECT id INTO v_account_id FROM chart_of_accounts WHERE code = '6000' LIMIT 1;
  END IF;
  
  RETURN v_account_id;
END;
$$;

-- =====================================================
-- 3. RECREATE JOURNAL ENTRIES - BATCH BY MONTH
-- =====================================================

DO $$
DECLARE
  v_expense RECORD;
  v_expense_account_id UUID;
  v_payment_account_id UUID;
  v_journal_id UUID;
  v_description TEXT;
  v_payment_desc TEXT;
  v_entry_number TEXT;
  v_year_month TEXT;
  v_prev_year_month TEXT := '';
  v_counter INTEGER := 0;
  v_created_count INTEGER := 0;
BEGIN
  FOR v_expense IN 
    SELECT * FROM finance_expenses 
    ORDER BY expense_date, created_at
  LOOP
    -- Get year-month
    v_year_month := TO_CHAR(v_expense.expense_date, 'YYMM');
    
    -- Reset counter if new month
    IF v_year_month != v_prev_year_month THEN
      -- Get max counter for this month
      SELECT COALESCE(MAX(CAST(SUBSTRING(entry_number FROM '-([0-9]+)$') AS INTEGER)), 0)
      INTO v_counter
      FROM journal_entries
      WHERE entry_number LIKE 'JE' || v_year_month || '-%';
      
      v_prev_year_month := v_year_month;
    END IF;
    
    v_counter := v_counter + 1;
    v_entry_number := 'JE' || v_year_month || '-' || LPAD(v_counter::TEXT, 4, '0');
    
    -- Get accounts
    v_expense_account_id := get_expense_account_id(v_expense.expense_category);
    IF v_expense_account_id IS NULL THEN CONTINUE; END IF;

    IF v_expense.payment_method = 'cash' THEN
      SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
      v_payment_desc := 'Cash on Hand';
    ELSIF v_expense.payment_method = 'petty_cash' THEN
      SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
      v_payment_desc := 'Petty Cash';
    ELSIF v_expense.payment_method = 'bank_transfer' AND v_expense.bank_account_id IS NOT NULL THEN
      SELECT coa_id, account_name INTO v_payment_account_id, v_payment_desc
      FROM bank_accounts WHERE id = v_expense.bank_account_id;
      IF v_payment_account_id IS NULL THEN
        SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1111' LIMIT 1;
        v_payment_desc := 'Bank Account';
      END IF;
    ELSIF v_expense.payment_method IS NULL THEN
      SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '2110' LIMIT 1;
      v_payment_desc := 'Accounts Payable';
    ELSE
      SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
      v_payment_desc := 'Cash on Hand';
    END IF;

    IF v_payment_account_id IS NULL THEN CONTINUE; END IF;

    v_description := COALESCE(v_expense.description, v_expense.expense_category);

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_number, entry_date, source_module, reference_number,
      description, total_debit, total_credit, is_posted, posted_at, created_by
    ) VALUES (
      v_entry_number, v_expense.expense_date, 'expenses', 'EXP-' || v_expense.id::text,
      v_description, v_expense.amount, v_expense.amount, true, now(), v_expense.created_by
    ) RETURNING id INTO v_journal_id;

    -- Debit: Expense
    INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, debit, credit, description)
    VALUES (v_journal_id, 1, v_expense_account_id, v_expense.amount, 0, v_description);

    -- Credit: Payment
    INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, debit, credit, description)
    VALUES (v_journal_id, 2, v_payment_account_id, 0, v_expense.amount, v_payment_desc);

    v_created_count := v_created_count + 1;
  END LOOP;

  RAISE NOTICE 'Recreated % journal entries', v_created_count;
END $$;

-- =====================================================
-- 4. UPDATE TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION auto_post_expense_accounting()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expense_account_id UUID;
  v_payment_account_id UUID;
  v_journal_id UUID;
  v_description TEXT;
  v_payment_desc TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM journal_entries WHERE source_module = 'expenses' AND reference_number = 'EXP-' || NEW.id::text) THEN
    RETURN NEW;
  END IF;

  v_expense_account_id := get_expense_account_id(NEW.expense_category);
  IF v_expense_account_id IS NULL THEN RETURN NEW; END IF;

  IF NEW.payment_method = 'cash' THEN
    SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
    v_payment_desc := 'Cash on Hand';
  ELSIF NEW.payment_method = 'petty_cash' THEN
    SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1102' LIMIT 1;
    v_payment_desc := 'Petty Cash';
  ELSIF NEW.payment_method = 'bank_transfer' AND NEW.bank_account_id IS NOT NULL THEN
    SELECT coa_id, account_name INTO v_payment_account_id, v_payment_desc
    FROM bank_accounts WHERE id = NEW.bank_account_id;
    IF v_payment_account_id IS NULL THEN
      SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1111' LIMIT 1;
      v_payment_desc := 'Bank Account';
    END IF;
  ELSIF NEW.payment_method IS NULL THEN
    SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '2110' LIMIT 1;
    v_payment_desc := 'Accounts Payable';
  ELSE
    SELECT id INTO v_payment_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
    v_payment_desc := 'Cash on Hand';
  END IF;

  IF v_payment_account_id IS NULL THEN RETURN NEW; END IF;

  v_description := COALESCE(NEW.description, NEW.expense_category);

  INSERT INTO journal_entries (
    entry_number, entry_date, source_module, reference_number,
    description, total_debit, total_credit, is_posted, posted_at, created_by
  ) VALUES (
    generate_journal_entry_number(), NEW.expense_date, 'expenses', 'EXP-' || NEW.id::text,
    v_description, NEW.amount, NEW.amount, true, now(), NEW.created_by
  ) RETURNING id INTO v_journal_id;

  INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, debit, credit, description)
  VALUES (v_journal_id, 1, v_expense_account_id, NEW.amount, 0, v_description);

  INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, debit, credit, description)
  VALUES (v_journal_id, 2, v_payment_account_id, 0, NEW.amount, v_payment_desc);

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_auto_post_expense_accounting ON finance_expenses;
CREATE TRIGGER trigger_auto_post_expense_accounting
  AFTER INSERT ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION auto_post_expense_accounting();

-- =====================================================
-- 5. VERIFICATION
-- =====================================================

DO $$
DECLARE
  v_bank_exp INTEGER; v_bank_je INTEGER;
  v_cash_exp INTEGER; v_cash_je INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_bank_exp FROM finance_expenses WHERE payment_method = 'bank_transfer' AND bank_account_id IS NOT NULL;
  SELECT COUNT(DISTINCT je.id) INTO v_bank_je
  FROM finance_expenses e
  JOIN journal_entries je ON je.reference_number = 'EXP-' || e.id::text
  JOIN journal_entry_lines jel ON jel.journal_entry_id = je.id
  JOIN chart_of_accounts coa ON coa.id = jel.account_id
  WHERE e.payment_method = 'bank_transfer' AND coa.code LIKE '1111%' AND jel.credit > 0;
  
  SELECT COUNT(*) INTO v_cash_exp FROM finance_expenses WHERE payment_method = 'cash';
  SELECT COUNT(DISTINCT je.id) INTO v_cash_je
  FROM finance_expenses e
  JOIN journal_entries je ON je.reference_number = 'EXP-' || e.id::text
  JOIN journal_entry_lines jel ON jel.journal_entry_id = je.id
  WHERE e.payment_method = 'cash' AND jel.account_id = (SELECT id FROM chart_of_accounts WHERE code = '1101') AND jel.credit > 0;
  
  RAISE NOTICE 'Bank Expenses: % | Journal: % | Match: %', v_bank_exp, v_bank_je, (v_bank_exp = v_bank_je);
  RAISE NOTICE 'Cash Expenses: % | Journal: % | Match: %', v_cash_exp, v_cash_je, (v_cash_exp = v_cash_je);
END $$;
