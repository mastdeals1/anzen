/*
  # Fix auto_match_smart Function Search Path

  ## Security Issue
  - Function is SECURITY DEFINER without search_path set
  - Vulnerable to search_path attacks

  ## Fix
  - Add SET search_path = public, pg_temp
*/

DROP FUNCTION IF EXISTS auto_match_smart();

CREATE OR REPLACE FUNCTION auto_match_smart()
RETURNS TABLE(matched_count int, suggested_count int, skipped_count int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_matched_count int := 0;
  v_suggested_count int := 0;
  v_skipped_count int := 0;
  v_line record;
  v_expense record;
  v_best_match_id uuid;
  v_best_score numeric;
  v_amount numeric;
  v_already_matched boolean;
BEGIN
  -- Loop through unmatched bank statement lines (only debits for expenses)
  FOR v_line IN 
    SELECT * FROM bank_statement_lines 
    WHERE reconciliation_status = 'unmatched'
      AND debit_amount > 0  -- Only process debits (outgoing = expenses)
      AND matched_expense_id IS NULL
      AND matched_receipt_id IS NULL
      AND matched_petty_cash_id IS NULL
      AND matched_entry_id IS NULL
      AND matched_fund_transfer_id IS NULL
    ORDER BY transaction_date DESC
  LOOP
    v_amount := v_line.debit_amount;
    v_best_match_id := NULL;
    v_best_score := 0;
    
    -- Find best matching expense
    FOR v_expense IN 
      SELECT 
        fe.id,
        fe.amount,
        fe.expense_date,
        fe.bank_account_id,
        fe.expense_category,
        ABS(EXTRACT(EPOCH FROM (v_line.transaction_date - fe.expense_date)) / 86400) as date_diff_days,
        ABS(fe.amount - v_amount) as amount_diff,
        -- Check if already matched to another bank statement
        EXISTS (
          SELECT 1 FROM bank_statement_lines bsl 
          WHERE bsl.matched_expense_id = fe.id 
            AND bsl.id != v_line.id
        ) as already_matched
      FROM finance_expenses fe
      WHERE fe.paid_by = 'bank'  -- Only bank-paid expenses
        AND ABS(fe.amount - v_amount) <= 10000  -- Amount tolerance: ±10,000
        AND ABS(EXTRACT(EPOCH FROM (v_line.transaction_date - fe.expense_date)) / 86400) <= 7  -- Date tolerance: ±7 days
        -- If bank account specified on both sides, must match
        AND (
          v_line.bank_account_id IS NULL 
          OR fe.bank_account_id IS NULL 
          OR v_line.bank_account_id = fe.bank_account_id
        )
      ORDER BY 
        ABS(fe.amount - v_amount),  -- Closest amount first
        ABS(EXTRACT(EPOCH FROM (v_line.transaction_date - fe.expense_date)) / 86400)  -- Then closest date
      LIMIT 1
    LOOP
      -- Skip if already matched
      IF v_expense.already_matched THEN
        v_skipped_count := v_skipped_count + 1;
        CONTINUE;
      END IF;
      
      -- Calculate confidence score
      v_best_score := 0;
      
      -- Amount matching score (0-60 points)
      IF v_expense.amount_diff < 1 THEN
        v_best_score := v_best_score + 60;  -- Perfect match
      ELSIF v_expense.amount_diff <= 100 THEN
        v_best_score := v_best_score + 50;  -- Very close
      ELSIF v_expense.amount_diff <= 1000 THEN
        v_best_score := v_best_score + 35;  -- Close
      ELSE
        v_best_score := v_best_score + 20;  -- Within tolerance
      END IF;
      
      -- Date matching score (0-30 points)
      IF v_expense.date_diff_days = 0 THEN
        v_best_score := v_best_score + 30;  -- Same day
      ELSIF v_expense.date_diff_days <= 1 THEN
        v_best_score := v_best_score + 25;  -- Next/previous day
      ELSIF v_expense.date_diff_days <= 3 THEN
        v_best_score := v_best_score + 15;  -- Within 3 days
      ELSE
        v_best_score := v_best_score + 5;   -- Within 7 days
      END IF;
      
      -- Bank account matching bonus (0-10 points)
      IF v_line.bank_account_id IS NOT NULL 
         AND v_expense.bank_account_id IS NOT NULL 
         AND v_line.bank_account_id = v_expense.bank_account_id THEN
        v_best_score := v_best_score + 10;
      END IF;
      
      v_best_match_id := v_expense.id;
    END LOOP;
    
    -- Apply the match if score is good enough
    -- Score >= 85: Auto-match with high confidence
    -- Score >= 70: Suggest for review
    IF v_best_match_id IS NOT NULL AND v_best_score >= 70 THEN
      UPDATE bank_statement_lines
      SET 
        matched_expense_id = v_best_match_id,
        reconciliation_status = CASE 
          WHEN v_best_score >= 85 THEN 'matched'
          ELSE 'needs_review'
        END,
        matched_at = now(),
        matched_by = (select auth.uid()),
        notes = 'Auto-matched (confidence: ' || ROUND(v_best_score)::text || '%)'
      WHERE id = v_line.id;
      
      IF v_best_score >= 85 THEN
        v_matched_count := v_matched_count + 1;
      ELSE
        v_suggested_count := v_suggested_count + 1;
      END IF;
    END IF;
  END LOOP;
  
  RETURN QUERY SELECT v_matched_count, v_suggested_count, v_skipped_count;
END;
$$;

COMMENT ON FUNCTION auto_match_smart IS 
  'Smart auto-matching with strict 7-day date tolerance, amount matching, and bank account verification. 
   Returns: (matched_count, suggested_count, skipped_count)
   - matched_count: High confidence matches (85%+)
   - suggested_count: Needs review (70-84%)
   - skipped_count: Already matched expenses';
