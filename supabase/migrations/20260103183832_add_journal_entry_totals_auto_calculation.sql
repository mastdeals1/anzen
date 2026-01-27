/*
  # Fix Journal Entry Totals - Missing Critical Trigger
  
  1. Problem Identified
    - journal_entries has total_debit and total_credit columns
    - But they are ALWAYS 0 because no trigger updates them
    - When lines are added, the totals are not calculated
    
  2. Accounting Logic
    - Every journal entry MUST have balanced totals
    - Total Debit = Sum of all debit amounts in lines
    - Total Credit = Sum of all credit amounts in lines
    - Total Debit MUST EQUAL Total Credit (balanced entry)
    
  3. Solution
    - Create trigger to auto-calculate totals after INSERT/UPDATE/DELETE of lines
    - Update all existing entries with correct totals
    - Add validation to ensure balanced entries
*/

-- Step 1: Create function to recalculate journal entry totals
CREATE OR REPLACE FUNCTION recalculate_journal_entry_totals()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_entry_id UUID;
  v_total_debit NUMERIC;
  v_total_credit NUMERIC;
BEGIN
  -- Determine which journal entry to update
  IF (TG_OP = 'DELETE') THEN
    v_entry_id := OLD.journal_entry_id;
  ELSE
    v_entry_id := NEW.journal_entry_id;
  END IF;

  -- Calculate totals from all lines
  SELECT 
    COALESCE(SUM(debit), 0),
    COALESCE(SUM(credit), 0)
  INTO v_total_debit, v_total_credit
  FROM journal_entry_lines
  WHERE journal_entry_id = v_entry_id;

  -- Update the journal entry totals
  UPDATE journal_entries
  SET 
    total_debit = v_total_debit,
    total_credit = v_total_credit
  WHERE id = v_entry_id;

  -- Return appropriate record
  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Step 2: Create triggers for INSERT, UPDATE, DELETE
DROP TRIGGER IF EXISTS trg_journal_entry_lines_totals_insert ON journal_entry_lines;
DROP TRIGGER IF EXISTS trg_journal_entry_lines_totals_update ON journal_entry_lines;
DROP TRIGGER IF EXISTS trg_journal_entry_lines_totals_delete ON journal_entry_lines;

CREATE TRIGGER trg_journal_entry_lines_totals_insert
  AFTER INSERT ON journal_entry_lines
  FOR EACH ROW
  EXECUTE FUNCTION recalculate_journal_entry_totals();

CREATE TRIGGER trg_journal_entry_lines_totals_update
  AFTER UPDATE ON journal_entry_lines
  FOR EACH ROW
  EXECUTE FUNCTION recalculate_journal_entry_totals();

CREATE TRIGGER trg_journal_entry_lines_totals_delete
  AFTER DELETE ON journal_entry_lines
  FOR EACH ROW
  EXECUTE FUNCTION recalculate_journal_entry_totals();

-- Step 3: Fix ALL existing journal entries with incorrect totals
UPDATE journal_entries je
SET 
  total_debit = COALESCE((
    SELECT SUM(debit)
    FROM journal_entry_lines
    WHERE journal_entry_id = je.id
  ), 0),
  total_credit = COALESCE((
    SELECT SUM(credit)
    FROM journal_entry_lines
    WHERE journal_entry_id = je.id
  ), 0)
WHERE EXISTS (
  SELECT 1 
  FROM journal_entry_lines 
  WHERE journal_entry_id = je.id
);

-- Step 4: Add check constraint to ensure balanced entries (optional but recommended)
-- This ensures data integrity at database level
ALTER TABLE journal_entries
DROP CONSTRAINT IF EXISTS chk_journal_entry_balanced;

ALTER TABLE journal_entries
ADD CONSTRAINT chk_journal_entry_balanced 
CHECK (
  ABS(total_debit - total_credit) < 0.01 OR
  (total_debit = 0 AND total_credit = 0)
);

COMMENT ON CONSTRAINT chk_journal_entry_balanced ON journal_entries 
IS 'Ensures journal entries are balanced: total debits must equal total credits';

COMMENT ON FUNCTION recalculate_journal_entry_totals() 
IS 'Automatically recalculates and updates journal entry totals when lines are added/modified/deleted - CRITICAL for accounting accuracy';

-- Verification query
SELECT 
  'Fixed ' || COUNT(*) || ' journal entries' as status,
  SUM(total_debit) as total_debits,
  SUM(total_credit) as total_credits
FROM journal_entries
WHERE total_debit > 0 OR total_credit > 0;
