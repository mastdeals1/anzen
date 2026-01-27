/*
  # Fix Expense to Petty Cash Flow

  The issue: When creating an expense with payment_method = 'petty_cash', 
  the system was crediting "Cash on Hand" (1101) instead of "Petty Cash" (1102).

  This fix:
  1. Updates the trigger to check payment_method
  2. Uses Petty Cash (1102) when payment_method = 'petty_cash'
  3. Uses Cash on Hand (1101) for other methods
  4. Creates petty_cash_transaction record automatically when using petty cash
*/

-- Drop the existing trigger function
DROP FUNCTION IF EXISTS auto_post_expense_accounting() CASCADE;

-- Recreate with proper petty cash handling
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
  WHERE code = '1130' -- Inventory
  LIMIT 1;
  
  -- Get Cash on Hand account
  SELECT id INTO v_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1101'
  LIMIT 1;
  
  -- Get Petty Cash account
  SELECT id INTO v_petty_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1102'
  LIMIT 1;
  
  -- Determine which cash account to use based on payment method
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
    ELSE code = '6900' -- Miscellaneous
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
  
  -- Create journal entry
  IF NEW.import_container_id IS NOT NULL AND v_inventory_account_id IS NOT NULL THEN
    -- Import expenses: Dr Inventory, Cr Cash/Petty Cash
    INSERT INTO journal_entries (
      entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, created_by
    ) VALUES (
      NEW.expense_date, 'expenses', NEW.id, 'EXP-' || NEW.voucher_number,
      v_description || ' (' || v_entry_type || ')', NEW.amount, NEW.amount, true, NEW.created_by
    ) RETURNING id INTO v_journal_id;
    
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES 
      (v_journal_id, v_inventory_account_id, NEW.amount, 0, 'Inventory - ' || NEW.expense_category),
      (v_journal_id, v_payment_account_id, 0, NEW.amount, 
        CASE WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash payment' ELSE 'Cash payment' END);
      
  ELSIF v_expense_account_id IS NOT NULL THEN
    -- Operating expenses: Dr Expense, Cr Cash/Petty Cash
    INSERT INTO journal_entries (
      entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, created_by
    ) VALUES (
      NEW.expense_date, 'expenses', NEW.id, 'EXP-' || NEW.voucher_number,
      v_description || ' (' || v_entry_type || ')', NEW.amount, NEW.amount, true, NEW.created_by
    ) RETURNING id INTO v_journal_id;
    
    INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
    VALUES 
      (v_journal_id, v_expense_account_id, NEW.amount, 0, 'Expense - ' || NEW.expense_category),
      (v_journal_id, v_payment_account_id, 0, NEW.amount, 
        CASE WHEN NEW.payment_method = 'petty_cash' THEN 'Petty Cash payment' ELSE 'Cash payment' END);
  END IF;
  
  -- If payment method is petty_cash, create petty cash transaction record
  IF NEW.payment_method = 'petty_cash' AND v_journal_id IS NOT NULL THEN
    -- Generate petty cash transaction number
    SELECT 'PC-' || TO_CHAR(NEW.expense_date, 'YYYYMMDD') || '-' || 
           LPAD((COUNT(*) + 1)::TEXT, 4, '0')
    INTO v_pc_number
    FROM petty_cash_transactions
    WHERE transaction_date = NEW.expense_date;
    
    -- Create petty cash transaction
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

-- Recreate the trigger
CREATE TRIGGER trigger_auto_post_expense_accounting
  AFTER INSERT ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION auto_post_expense_accounting();

COMMENT ON FUNCTION auto_post_expense_accounting IS
  'Auto-posts expense journal entries. Uses Petty Cash (1102) when payment_method=petty_cash, otherwise Cash on Hand (1101). Also creates petty_cash_transaction records automatically.';
