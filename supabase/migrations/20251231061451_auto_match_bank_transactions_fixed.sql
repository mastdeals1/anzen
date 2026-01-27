
/*
  # Auto-Match Bank Transactions - Fixed

  1. Function
    - Fixed date difference calculation
    - Matches bank lines with expenses
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
  v_date_diff numeric;
BEGIN
  FOR v_line IN 
    SELECT * FROM bank_statement_lines 
    WHERE reconciliation_status = 'unmatched'
  LOOP
    v_amount := COALESCE(v_line.debit_amount, v_line.credit_amount, 0);
    v_best_match_id := NULL;
    v_best_score := 0;
    
    FOR v_expense IN 
      SELECT *, 
        ABS(v_line.transaction_date - expense_date) as date_diff,
        ABS(amount - v_amount) as amount_diff
      FROM finance_expenses
      WHERE ABS(amount - v_amount) < 10000
        AND ABS(v_line.transaction_date - expense_date) <= 5
      ORDER BY ABS(amount - v_amount), ABS(v_line.transaction_date - expense_date)
      LIMIT 1
    LOOP
      IF v_expense.amount_diff < 1 THEN
        v_best_score := 100;
      ELSIF v_expense.amount_diff < 100 THEN
        v_best_score := 90;
      ELSE
        v_best_score := 70;
      END IF;
      
      IF v_expense.date_diff = 0 THEN
        v_best_score := v_best_score + 20;
      END IF;
      
      v_best_match_id := v_expense.id;
    END LOOP;
    
    IF v_best_match_id IS NOT NULL AND v_best_score >= 70 THEN
      UPDATE bank_statement_lines
      SET 
        matched_expense_id = v_best_match_id,
        reconciliation_status = CASE 
          WHEN v_best_score >= 90 THEN 'matched'
          ELSE 'suggested'
        END,
        notes = 'Auto-matched (score: ' || v_best_score::text || '%)'
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
