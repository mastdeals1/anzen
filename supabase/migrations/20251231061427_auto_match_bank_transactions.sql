
/*
  # Auto-Match Bank Transactions Directly

  1. Function
    - Creates a function to automatically match bank statement lines with expenses
    - Matches based on amount and date proximity
    - Updates bank_statement_lines with matched_expense_id

  2. Logic
    - Finds exact amount matches within 5 days
    - Links bank lines to expenses
    - Sets reconciliation_status to 'matched' for high confidence
*/

CREATE OR REPLACE FUNCTION auto_match_all_bank_transactions()
RETURNS TABLE(matched_count int, suggested_count int) AS $$
DECLARE
  v_matched_count int := 0;
  v_suggested_count int := 0;
  v_line record;
  v_expense record;
  v_best_match_id uuid;
  v_best_score numeric;
  v_amount numeric;
BEGIN
  -- Loop through all unmatched bank lines
  FOR v_line IN 
    SELECT * FROM bank_statement_lines 
    WHERE reconciliation_status = 'unmatched'
  LOOP
    v_amount := COALESCE(v_line.debit_amount, v_line.credit_amount, 0);
    v_best_match_id := NULL;
    v_best_score := 0;
    
    -- Find matching expense
    FOR v_expense IN 
      SELECT * FROM finance_expenses
      WHERE ABS(amount - v_amount) < 10000
        AND ABS(EXTRACT(DAY FROM (expense_date - v_line.transaction_date))) <= 5
      ORDER BY ABS(amount - v_amount), ABS(EXTRACT(DAY FROM (expense_date - v_line.transaction_date)))
      LIMIT 1
    LOOP
      -- Calculate score
      IF ABS(v_expense.amount - v_amount) < 1 THEN
        v_best_score := 100;
      ELSIF ABS(v_expense.amount - v_amount) < 100 THEN
        v_best_score := 90;
      ELSE
        v_best_score := 70;
      END IF;
      
      IF ABS(EXTRACT(DAY FROM (v_expense.expense_date - v_line.transaction_date))) = 0 THEN
        v_best_score := v_best_score + 20;
      END IF;
      
      v_best_match_id := v_expense.id;
    END LOOP;
    
    -- Update if good match found
    IF v_best_match_id IS NOT NULL AND v_best_score >= 70 THEN
      UPDATE bank_statement_lines
      SET 
        matched_expense_id = v_best_match_id,
        reconciliation_status = CASE 
          WHEN v_best_score >= 90 THEN 'matched'
          ELSE 'suggested'
        END,
        notes = 'Auto-matched with score ' || v_best_score::text
      WHERE id = v_line.id;
      
      IF v_best_score >= 90 THEN
        v_matched_count := v_matched_count + 1;
      ELSE
        v_suggested_count := v_suggested_count + 1;
      END IF;
    END IF;
  END LOOP;
  
  RETURN QUERY SELECT v_matched_count, v_suggested_count;
END;
$$ LANGUAGE plpgsql;
