/*
  # Fix Fund Transfer Trigger - Handle UPDATE Operations

  1. Problem
    - Trigger only runs on INSERT, not UPDATE
    - If user edits fund transfer to add bank statement line IDs, bank statements don't get updated
    - Bank reconciliation shows "unmatched" even when fund transfer is linked
    
  2. Solution
    - Add trigger for UPDATE operations
    - Create separate function to handle bank statement line updates
    - Update existing unlinked records

  3. Changes
    - Create update_fund_transfer_bank_links() function
    - Add AFTER UPDATE trigger
    - Fix existing fund transfers
*/

-- Function to update bank statement line links
CREATE OR REPLACE FUNCTION update_fund_transfer_bank_links()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Handle from_bank_statement_line_id
  IF NEW.from_bank_statement_line_id IS NOT NULL THEN
    -- If it's different from OLD, update the bank statement
    IF (TG_OP = 'INSERT') OR (OLD.from_bank_statement_line_id IS DISTINCT FROM NEW.from_bank_statement_line_id) THEN
      UPDATE bank_statement_lines
      SET
        matched_fund_transfer_id = NEW.id,
        reconciliation_status = 'matched',
        matched_at = now(),
        matched_by = COALESCE(NEW.posted_by, NEW.created_by),
        notes = 'Linked to Fund Transfer ' || NEW.transfer_number
      WHERE id = NEW.from_bank_statement_line_id;
    END IF;
  END IF;

  -- Handle to_bank_statement_line_id
  IF NEW.to_bank_statement_line_id IS NOT NULL THEN
    IF (TG_OP = 'INSERT') OR (OLD.to_bank_statement_line_id IS DISTINCT FROM NEW.to_bank_statement_line_id) THEN
      UPDATE bank_statement_lines
      SET
        matched_fund_transfer_id = NEW.id,
        reconciliation_status = 'matched',
        matched_at = now(),
        matched_by = COALESCE(NEW.posted_by, NEW.created_by),
        notes = 'Linked to Fund Transfer ' || NEW.transfer_number
      WHERE id = NEW.to_bank_statement_line_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger for INSERT operations (in case fund transfer is created with bank links)
DROP TRIGGER IF EXISTS trigger_fund_transfer_bank_links_insert ON fund_transfers;
CREATE TRIGGER trigger_fund_transfer_bank_links_insert
  AFTER INSERT ON fund_transfers
  FOR EACH ROW
  EXECUTE FUNCTION update_fund_transfer_bank_links();

-- Create trigger for UPDATE operations (when user edits to add bank links)
DROP TRIGGER IF EXISTS trigger_fund_transfer_bank_links_update ON fund_transfers;
CREATE TRIGGER trigger_fund_transfer_bank_links_update
  AFTER UPDATE ON fund_transfers
  FOR EACH ROW
  WHEN (OLD.from_bank_statement_line_id IS DISTINCT FROM NEW.from_bank_statement_line_id
     OR OLD.to_bank_statement_line_id IS DISTINCT FROM NEW.to_bank_statement_line_id)
  EXECUTE FUNCTION update_fund_transfer_bank_links();

-- Fix existing fund transfers that have bank statement line IDs but bank statements aren't linked
DO $$
DECLARE
  v_transfer RECORD;
BEGIN
  FOR v_transfer IN
    SELECT 
      ft.id,
      ft.transfer_number,
      ft.from_bank_statement_line_id,
      ft.to_bank_statement_line_id,
      ft.created_by,
      ft.posted_by
    FROM fund_transfers ft
    WHERE (ft.from_bank_statement_line_id IS NOT NULL 
       OR ft.to_bank_statement_line_id IS NOT NULL)
      AND ft.status = 'posted'
  LOOP
    -- Update from bank statement line
    IF v_transfer.from_bank_statement_line_id IS NOT NULL THEN
      UPDATE bank_statement_lines
      SET
        matched_fund_transfer_id = v_transfer.id,
        reconciliation_status = 'matched',
        matched_at = now(),
        matched_by = COALESCE(v_transfer.posted_by, v_transfer.created_by),
        notes = 'Linked to Fund Transfer ' || v_transfer.transfer_number
      WHERE id = v_transfer.from_bank_statement_line_id
        AND matched_fund_transfer_id IS NULL;
    END IF;

    -- Update to bank statement line
    IF v_transfer.to_bank_statement_line_id IS NOT NULL THEN
      UPDATE bank_statement_lines
      SET
        matched_fund_transfer_id = v_transfer.id,
        reconciliation_status = 'matched',
        matched_at = now(),
        matched_by = COALESCE(v_transfer.posted_by, v_transfer.created_by),
        notes = 'Linked to Fund Transfer ' || v_transfer.transfer_number
      WHERE id = v_transfer.to_bank_statement_line_id
        AND matched_fund_transfer_id IS NULL;
    END IF;
  END LOOP;
END $$;
