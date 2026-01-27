/*
  # Fix Payment Voucher to Use Specific Bank Account COA

  1. Problem
    - Payment voucher trigger was using generic bank account (code 1111) for ALL bank transfers
    - Same issue as receipt vouchers

  2. Solution
    - Update trigger to use the specific bank account's linked COA (from bank_accounts.coa_id)
    - Ensures payments only appear in the correct bank account ledger
*/

CREATE OR REPLACE FUNCTION post_payment_voucher_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_je_id UUID;
  v_je_number TEXT;
  v_credit_account_id UUID;
  v_ap_account_id UUID;
  v_pph_account_id UUID;
  v_net_amount DECIMAL(18,2);
BEGIN
  IF TG_OP = 'INSERT' THEN
    
    -- Determine the credit account (cash/bank)
    IF NEW.bank_account_id IS NOT NULL THEN
      -- Use the specific bank account's linked COA
      SELECT coa_id INTO v_credit_account_id
      FROM bank_accounts
      WHERE id = NEW.bank_account_id;
      
      -- If bank account doesn't have a linked COA, fall back to generic bank account
      IF v_credit_account_id IS NULL THEN
        SELECT id INTO v_credit_account_id FROM chart_of_accounts WHERE code = '1111' LIMIT 1;
      END IF;
    ELSIF NEW.payment_method = 'cash' THEN
      -- Cash payment
      SELECT id INTO v_credit_account_id FROM chart_of_accounts WHERE code = '1101' LIMIT 1;
    ELSE
      -- Generic bank account as fallback
      SELECT id INTO v_credit_account_id FROM chart_of_accounts WHERE code = '1111' LIMIT 1;
    END IF;

    -- Get other accounts
    SELECT id INTO v_ap_account_id FROM chart_of_accounts WHERE code = '2110' LIMIT 1;
    SELECT id INTO v_pph_account_id FROM chart_of_accounts WHERE code = '2132' LIMIT 1;

    IF v_credit_account_id IS NULL OR v_ap_account_id IS NULL THEN
      RETURN NEW;
    END IF;

    v_net_amount := NEW.amount - COALESCE(NEW.pph_amount, 0);

    -- Generate journal entry number
    v_je_number := 'JE' || TO_CHAR(CURRENT_DATE, 'YYMM') || '-' || LPAD((
      SELECT COUNT(*) + 1 FROM journal_entries WHERE entry_number LIKE 'JE' || TO_CHAR(CURRENT_DATE, 'YYMM') || '%'
    )::TEXT, 4, '0');

    -- Create journal entry
    INSERT INTO journal_entries (
      entry_number, entry_date, source_module, reference_id, reference_number,
      description, total_debit, total_credit, is_posted, posted_by
    ) VALUES (
      v_je_number, NEW.voucher_date, 'payment', NEW.id, NEW.voucher_number,
      'Payment Voucher: ' || NEW.voucher_number,
      NEW.amount, NEW.amount, true, NEW.created_by
    ) RETURNING id INTO v_je_id;

    -- Debit: Accounts Payable
    INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, description, debit, credit, supplier_id)
    VALUES (v_je_id, 1, v_ap_account_id, 'A/P Payment - ' || NEW.voucher_number, NEW.amount, 0, NEW.supplier_id);

    -- Credit: Withholding Tax PPh (if applicable)
    IF NEW.pph_amount > 0 AND v_pph_account_id IS NOT NULL THEN
      INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, description, debit, credit, supplier_id)
      VALUES (v_je_id, 2, v_pph_account_id, 'PPh Withholding - ' || NEW.voucher_number, 0, NEW.pph_amount, NEW.supplier_id);
    END IF;

    -- Credit: Cash/Specific Bank Account (net amount)
    INSERT INTO journal_entry_lines (journal_entry_id, line_number, account_id, description, debit, credit, supplier_id)
    VALUES (v_je_id, 3, v_credit_account_id, 'Cash Payment - ' || NEW.voucher_number, 0, v_net_amount, NEW.supplier_id);

    -- Link journal entry to voucher
    NEW.journal_entry_id := v_je_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS trg_post_payment_voucher ON payment_vouchers;
CREATE TRIGGER trg_post_payment_voucher
  BEFORE INSERT ON payment_vouchers
  FOR EACH ROW EXECUTE FUNCTION post_payment_voucher_journal();