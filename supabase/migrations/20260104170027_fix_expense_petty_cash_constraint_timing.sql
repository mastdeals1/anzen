/*
  # Fix Expense to Petty Cash - Constraint Timing Issue

  ## The Problem:
  When creating a journal entry, we set total_debit and total_credit to the amount.
  But when we insert the FIRST line, the recalculate trigger runs and recalculates 
  totals with only ONE line, making it unbalanced and failing the constraint check.

  ## The Solution:
  Set total_debit = 0 and total_credit = 0 initially. The constraint allows this:
  `(total_debit = 0 AND total_credit = 0)`
  
  Then the recalculate trigger will properly calculate totals after ALL lines are inserted.
*/

DROP FUNCTION IF EXISTS auto_post_expense_accounting() CASCADE;

CREATE OR REPLACE FUNCTION auto_post_expense_accounting()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_description TEXT;
  v_inventory_account_id UUID;
  v_expense_account_id UUID;
  v_cash_account_id UUID;
  v_petty_cash_account_id UUID;
  v_payment_account_id UUID;
  v_journal_id UUID;
  v_entry_type TEXT;
  v_pc_number TEXT;
BEGIN
  -- Get account IDs
  SELECT id INTO v_inventory_account_id
  FROM chart_of_accounts
  WHERE code = '1130'
  LIMIT 1;
  
  SELECT id INTO v_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1101'
  LIMIT 1;
  
  SELECT id INTO v_petty_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1102'
  LIMIT 1;
  
  -- Determine payment account based on payment_method
  IF NEW.payment_method = 'petty_cash' THEN
    v_payment_account_id := v_petty_cash_account_id;
  ELSE
    v_payment_account_id := v_cash_account_id;
  END IF;
  
  -- Determine expense account based on category
  SELECT id INTO v_expense_account_id
  FROM chart_of_accounts
  WHERE CASE 
    WHEN NEW.expense_category IN ('duty_customs', 'ppn_import', 'pph_import') THEN code = '5200'
    WHEN NEW.expense_category IN ('freight_import', 'clearing_forwarding') THEN code = '5300'
    WHEN NEW.expense_category IN ('container_handling', 'port_charges', 'transport_import') THEN code = '5400'
    WHEN NEW.expense_category = 'salary' THEN code = '6100'
    WHEN NEW.expense_category = 'warehouse_rent' THEN code = '6210'
    WHEN NEW.expense_category = 'utilities' THEN code = '6300'
    ELSE code = '6900'
  END
  LIMIT 1;
  
  -- Build description
  v_description := 'Expense: ' || NEW.expense_category;
  IF NEW.description IS NOT NULL THEN
    v_description := v_description || ' - ' || NEW.description;
  END IF;
  
  -- Determine entry type
  IF NEW.import_container_id IS NOT NULL THEN
    v_entry_type := 'CAPITALIZED TO INVENTORY';
  ELSE
    v_entry_type := 'EXPENSED TO P&L';
  END IF;
  
  -- Create journal entry with ZERO totals (will be recalculated by trigger)
  IF NEW.import_container_id IS NOT NULL AND v_inventory_account_id IS NOT NULL THEN
    INSERT INTO journal_entries (
      entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, created_by
    ) VALUES (
      NEW.expense_date, 'expenses', NEW.id, 'EXP-' || COALESCE(NEW.voucher_number, NEW.id::text),
      v_description || ' (' || v_entry_type || ')', 0, 0, true, NEW.created_by
    ) RETURNING id INTO v_journal_id;
    
    -- Insert lines (trigger will recalculate totals)
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES 
      (v_journal_id, v_inventory_account_id, NEW.amount, 0, 'Inventory - ' || NEW.expense_category),
      (v_journal_id, v_payment_account_id, 0, NEW.amount, 
        CASE WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash payment' ELSE 'Cash payment' END);
      
  ELSIF v_expense_account_id IS NOT NULL THEN
    INSERT INTO journal_entries (
      entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, created_by
    ) VALUES (
      NEW.expense_date, 'expenses', NEW.id, 'EXP-' || COALESCE(NEW.voucher_number, NEW.id::text),
      v_description || ' (' || v_entry_type || ')', 0, 0, true, NEW.created_by
    ) RETURNING id INTO v_journal_id;
    
    -- Insert lines (trigger will recalculate totals)
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES 
      (v_journal_id, v_expense_account_id, NEW.amount, 0, 'Expense - ' || NEW.expense_category),
      (v_journal_id, v_payment_account_id, 0, NEW.amount, 
        CASE WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash payment' ELSE 'Cash payment' END);
  END IF;
  
  -- Create petty cash transaction if needed
  IF NEW.payment_method = 'petty_cash' AND v_journal_id IS NOT NULL THEN
    SELECT 'PC-' || TO_CHAR(NEW.expense_date, 'YYYYMMDD') || '-' || 
           LPAD((COUNT(*) + 1)::TEXT, 4, '0')
    INTO v_pc_number
    FROM petty_cash_transactions
    WHERE transaction_date = NEW.expense_date;
    
    INSERT INTO petty_cash_transactions (
      transaction_number,
      transaction_date,
      transaction_type,
      amount,
      description,
      expense_category,
      bank_account_id,
      created_by,
      source,
      paid_to,
      paid_by
    ) VALUES (
      v_pc_number,
      NEW.expense_date,
      'expense',
      NEW.amount,
      v_description,
      NEW.expense_category,
      NEW.bank_account_id,
      NEW.created_by,
      'finance_expense',
      NEW.description,
      NEW.paid_by
    );
  END IF;
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error auto-posting expense accounting: %', SQLERRM;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trigger_auto_post_expense_accounting
  AFTER INSERT ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION auto_post_expense_accounting();

COMMENT ON FUNCTION auto_post_expense_accounting IS
  'Auto-posts expense journal entries. Sets totals to 0 initially, then recalculate trigger updates them from lines. Uses Petty Cash (1102) when payment_method=petty_cash, otherwise Cash on Hand (1101).';
