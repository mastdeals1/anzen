/*
  # Fix Receipt Voucher to Use Specific Bank Account COA

  1. Problem
    - Receipt voucher trigger was using generic bank account (code 1111) for ALL bank transfers
    - This caused all receipts to show in ALL bank accounts in the ledger
    - Bank account selection was ignored

  2. Solution
    - Update trigger to use the specific bank account's linked COA (from bank_accounts.coa_id)
    - If no specific COA is linked, fall back to generic accounts
    - This ensures receipts only appear in the correct bank account ledger

  3. Changes
    - Recreate `post_receipt_voucher_journal()` function
    - Use bank_accounts.coa_id when bank_account_id is provided
*/

CREATE OR REPLACE FUNCTION post_receipt_voucher_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_je_id UUID;
  v_je_number TEXT;
  v_debit_account_id UUID;
  v_ar_account_id UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    
    -- Determine the debit account (cash/bank)
    IF NEW.bank_account_id IS NOT NULL THEN
      -- Use the specific bank account's linked COA
      SELECT coa_id INTO v_debit_account_id
      FROM bank_accounts
      WHERE id = NEW.bank_account_id;
      
      -- If bank account doesn't have a linked COA, fall back to generic bank account
      IF v_debit_account_id IS NULL THEN
        SELECT id INTO v_debit_account_id FROM chart_of_accounts WHERE code = '1111' LIMIT 1;
      END IF;
    ELSIF NEW.payment_method = 'cash' THEN
      -- Cash payment
      SELECT id INTO v_debit_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
    ELSE
      -- Generic bank account as fallback
      SELECT id INTO v_debit_account_id FROM chart_of_accounts WHERE code = '1111' LIMIT 1;
    END IF;

    -- Get Accounts Receivable account
    SELECT id INTO v_ar_account_id FROM chart_of_accounts WHERE code = '1120' LIMIT 1;

    IF v_debit_account_id IS NULL OR v_ar_account_id IS NULL THEN
      RETURN NEW;
    END IF;

    -- Generate journal entry number
    v_je_number := 'JE' || TO_CHAR(CURRENT_DATE, 'YYMM') || '-' || LPAD((
      SELECT COUNT(*) + 1 FROM journal_entries WHERE entry_number LIKE 'JE' || TO_CHAR(CURRENT_DATE, 'YYMM') || '%'
    )::TEXT, 4, '0');

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_number, entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, posted_by
    ) VALUES (
      v_je_number, NEW.voucher_date, 'receipt', NEW.id, NEW.voucher_number,
      'Receipt Voucher: ' || NEW.voucher_number,
      NEW.amount, NEW.amount, true, NEW.created_by
    ) RETURNING id INTO v_je_id;

    -- Debit: Cash/Specific Bank Account
    INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, description, debit, credit, customer_id)
    VALUES (v_je_id, 1, v_debit_account_id, 'Cash Receipt - ' || NEW.voucher_number, NEW.amount, 0, NEW.customer_id);

    -- Credit: Accounts Receivable
    INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, description, debit, credit, customer_id)
    VALUES (v_je_id, 2, v_ar_account_id, 'A/R Payment - ' || NEW.voucher_number, 0, NEW.amount, NEW.customer_id);

    -- Link journal entry to voucher
    NEW.journal_entry_id := v_je_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS trg_post_receipt_voucher ON receipt_vouchers;
CREATE TRIGGER trg_post_receipt_voucher
  BEFORE INSERT ON receipt_vouchers
  FOR EACH ROW EXECUTE FUNCTION post_receipt_voucher_journal();