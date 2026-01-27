/*
  # Fix Petty Cash Trigger - Remove finance_expense_id Reference
  
  1. What This Does
    - Updates post_petty_cash_to_journal() trigger function
    - Removes reference to finance_expense_id column (which we deleted)
    - Keeps the source-based check for skipping journal creation
  
  2. Purpose
    - Allow petty cash transactions to be created without finance_expense_id
    - Maintain journal entry logic for standalone petty cash transactions
*/

CREATE OR REPLACE FUNCTION post_petty_cash_to_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_journal_id UUID;
  v_entry_number TEXT;
  v_petty_cash_account_id UUID;
  v_bank_account_coa_id UUID;
  v_expense_account_id UUID;
  v_line_num INT;
BEGIN
  -- CRITICAL: Skip journal creation if this transaction is linked to an expense
  -- that already has its own journal entry
  IF NEW.source IN ('moved_from_tracker', 'finance_expense') THEN
    RETURN NEW;
  END IF;

  -- Only create journal entries for:
  -- - 'withdraw' type (cash withdrawal from bank to petty cash)
  -- - 'expense' type with no source or other sources (standalone petty cash expenses)

  -- Generate entry number
  SELECT 'JE-' || TO_CHAR(NEW.transaction_date, 'YYYYMMDD') || '-' ||
         LPAD((COUNT(*) + 1)::TEXT, 4, '0')
  INTO v_entry_number
  FROM journal_entries;

  -- Get petty cash account
  SELECT id INTO v_petty_cash_account_id
  FROM chart_of_accounts
  WHERE code = '1102' OR code LIKE '1-103%' OR LOWER(name) LIKE '%petty%cash%'
  LIMIT 1;

  -- Create petty cash account if missing
  IF v_petty_cash_account_id IS NULL THEN
    INSERT INTO chart_of_accounts (code, name, account_type, is_active)
    VALUES ('1102', 'Petty Cash', 'asset', true)
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

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_number,
      entry_date,
      source_module,
      reference_id,
      description,
      is_posted,
      created_by,
      posted_at
    ) VALUES (
      v_entry_number,
      NEW.transaction_date,
      'petty_cash',
      NEW.id,
      'Petty cash withdrawal: ' || COALESCE(NEW.description, ''),
      true,
      NEW.created_by,
      NOW()
    ) RETURNING id INTO v_journal_id;

    v_line_num := 1;

    -- Dr Petty Cash
    INSERT INTO journal_entry_lines (
      journal_entry_id,
      line_number,
      account_id,
      debit,
      credit,
      description
    ) VALUES (
      v_journal_id,
      v_line_num,
      v_petty_cash_account_id,
      NEW.amount,
      0,
      'Cash withdrawal'
    );

    -- Cr Bank
    IF v_bank_account_coa_id IS NOT NULL THEN
      v_line_num := v_line_num + 1;
      INSERT INTO journal_entry_lines (
        journal_entry_id,
        line_number,
        account_id,
        debit,
        credit,
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
    -- Only for standalone petty cash expenses (not from finance_expenses)

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

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_number,
      entry_date,
      source_module,
      reference_id,
      description,
      is_posted,
      created_by,
      posted_at
    ) VALUES (
      v_entry_number,
      NEW.transaction_date,
      'petty_cash',
      NEW.id,
      'Petty cash expense: ' || COALESCE(NEW.description, ''),
      true,
      NEW.created_by,
      NOW()
    ) RETURNING id INTO v_journal_id;

    v_line_num := 1;

    -- Dr Expense
    IF v_expense_account_id IS NOT NULL THEN
      INSERT INTO journal_entry_lines (
        journal_entry_id,
        line_number,
        account_id,
        debit,
        credit,
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

    -- Cr Petty Cash
    INSERT INTO journal_entry_lines (
      journal_entry_id,
      line_number,
      account_id,
      debit,
      credit,
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
