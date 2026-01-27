/*
  # Add Paid By Field and Smart Auto-Matching System

  ## Changes
  
  1. New Tables
    - `bank_match_memory` - Stores learned patterns for auto-matching
      - Remembers description patterns → category mappings
      - Tracks confidence scores
  
  2. Modified Tables
    - `finance_expenses` - Add `paid_by` field (bank/cash)
    - `petty_cash_transactions` - Add `paid_by` field for consistency
  
  3. Logic
    - Cash expenses → Automatically create petty cash transaction
    - Bank expenses → Available for bank reconciliation
    - Smart matching learns from manual matches and remembers patterns
  
  ## Security
    - RLS enabled on new tables
    - Authenticated users can view
    - Admin/accounts can manage
*/

-- Add paid_by to finance_expenses
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'finance_expenses' AND column_name = 'paid_by'
  ) THEN
    ALTER TABLE finance_expenses 
    ADD COLUMN paid_by text DEFAULT 'bank' CHECK (paid_by IN ('bank', 'cash'));
  END IF;
END $$;

-- Add paid_by to petty_cash_transactions  
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'paid_by'
  ) THEN
    ALTER TABLE petty_cash_transactions 
    ADD COLUMN paid_by text DEFAULT 'cash' CHECK (paid_by IN ('bank', 'cash'));
  END IF;
END $$;

-- Create bank_match_memory table for smart auto-matching
CREATE TABLE IF NOT EXISTS bank_match_memory (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  description_pattern text NOT NULL,
  expense_category text NOT NULL,
  match_count integer DEFAULT 1,
  confidence_score numeric(5,2) DEFAULT 0,
  last_matched_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_bank_match_memory_pattern 
  ON bank_match_memory(description_pattern);

CREATE INDEX IF NOT EXISTS idx_bank_match_memory_category 
  ON bank_match_memory(expense_category);

-- RLS for bank_match_memory
ALTER TABLE bank_match_memory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view match memory"
  ON bank_match_memory FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Accounts/admin can manage match memory"
  ON bank_match_memory FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
      AND user_profiles.role IN ('admin', 'accounts')
    )
  );

-- Function to learn from manual matches and update memory
CREATE OR REPLACE FUNCTION learn_from_match(
  p_description text,
  p_expense_category text
) RETURNS void AS $$
DECLARE
  v_pattern text;
  v_existing record;
BEGIN
  -- Extract key words from description (first 3-5 meaningful words)
  v_pattern := LOWER(TRIM(SUBSTRING(p_description FROM 1 FOR 50)));
  
  -- Check if pattern already exists
  SELECT * INTO v_existing 
  FROM bank_match_memory 
  WHERE description_pattern = v_pattern 
    AND expense_category = p_expense_category;
  
  IF v_existing.id IS NOT NULL THEN
    -- Update existing pattern
    UPDATE bank_match_memory
    SET 
      match_count = match_count + 1,
      confidence_score = LEAST(confidence_score + 5, 100),
      last_matched_at = now()
    WHERE id = v_existing.id;
  ELSE
    -- Create new pattern
    INSERT INTO bank_match_memory (
      description_pattern,
      expense_category,
      match_count,
      confidence_score,
      created_by
    ) VALUES (
      v_pattern,
      p_expense_category,
      1,
      50,
      auth.uid()
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enhanced auto-match function with memory
CREATE OR REPLACE FUNCTION auto_match_with_memory()
RETURNS TABLE(matched_count int, suggested_count int) AS $$
DECLARE
  v_matched_count int := 0;
  v_suggested_count int := 0;
  v_line record;
  v_expense record;
  v_memory record;
  v_best_match_id uuid;
  v_best_score numeric;
  v_amount numeric;
BEGIN
  -- Loop through unmatched bank statement lines
  FOR v_line IN 
    SELECT * FROM bank_statement_lines 
    WHERE reconciliation_status = 'unmatched'
    ORDER BY transaction_date DESC
  LOOP
    v_amount := COALESCE(v_line.debit_amount, v_line.credit_amount, 0);
    v_best_match_id := NULL;
    v_best_score := 0;
    
    -- First: Try to match using learned patterns
    FOR v_memory IN 
      SELECT * FROM bank_match_memory
      WHERE LOWER(v_line.description) LIKE '%' || description_pattern || '%'
        AND confidence_score >= 50
      ORDER BY confidence_score DESC, match_count DESC
      LIMIT 1
    LOOP
      -- Find expense with matching category and similar amount
      FOR v_expense IN 
        SELECT *, 
          ABS(v_line.transaction_date - expense_date) as date_diff,
          ABS(amount - v_amount) as amount_diff
        FROM finance_expenses
        WHERE expense_category = v_memory.expense_category
          AND paid_by = 'bank'
          AND ABS(amount - v_amount) < 10000
          AND ABS(v_line.transaction_date - expense_date) <= 7
        ORDER BY ABS(amount - v_amount), ABS(v_line.transaction_date - expense_date)
        LIMIT 1
      LOOP
        v_best_score := v_memory.confidence_score;
        v_best_match_id := v_expense.id;
      END LOOP;
    END LOOP;
    
    -- Second: If no pattern match, try traditional matching
    IF v_best_match_id IS NULL THEN
      FOR v_expense IN 
        SELECT *, 
          ABS(v_line.transaction_date - expense_date) as date_diff,
          ABS(amount - v_amount) as amount_diff
        FROM finance_expenses
        WHERE paid_by = 'bank'
          AND ABS(amount - v_amount) < 10000
          AND ABS(v_line.transaction_date - expense_date) <= 5
        ORDER BY ABS(amount - v_amount), ABS(v_line.transaction_date - expense_date)
        LIMIT 1
      LOOP
        IF v_expense.amount_diff < 1 THEN
          v_best_score := 95;
        ELSIF v_expense.amount_diff < 100 THEN
          v_best_score := 85;
        ELSE
          v_best_score := 70;
        END IF;
        
        IF v_expense.date_diff = 0 THEN
          v_best_score := v_best_score + 10;
        END IF;
        
        v_best_match_id := v_expense.id;
      END LOOP;
    END IF;
    
    -- Apply the match if score is good enough
    IF v_best_match_id IS NOT NULL AND v_best_score >= 70 THEN
      UPDATE bank_statement_lines
      SET 
        matched_expense_id = v_best_match_id,
        reconciliation_status = CASE 
          WHEN v_best_score >= 90 THEN 'matched'
          ELSE 'needs_review'
        END,
        matched_at = now(),
        matched_by = auth.uid(),
        notes = 'Auto-matched (confidence: ' || v_best_score::text || '%)'
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION learn_from_match IS 'Learn from manual matches to improve auto-matching accuracy';
COMMENT ON FUNCTION auto_match_with_memory IS 'Auto-match bank transactions using learned patterns and traditional matching';
