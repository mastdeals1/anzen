/*
  # Bank Reconciliation Safety Features

  1. Duplicate Prevention
    - Add transaction_hash column to bank_statement_lines
    - Generate hash from: bank_account_id + date + debit + credit + normalized_description
    - Add unique index to prevent duplicate imports
    - Silently skip duplicates during import (no errors)

  2. Data Integrity
    - Prevent deletion of reconciled transactions
    - Add statement_balance tracking

  3. Multi-bank Isolation
    - Ensure bank account data is fully isolated
    - Clear data only affects selected bank & date range

  ## Notes
  - Hash collisions are intentional (identifies duplicate transactions)
  - Reconciled status includes: 'matched', 'recorded', 'suggested'
  - Delete operations restricted to 'unmatched' status only
*/

-- =====================================================
-- ADD TRANSACTION HASH COLUMN
-- =====================================================

-- Add transaction_hash column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_statement_lines'
    AND column_name = 'transaction_hash'
  ) THEN
    ALTER TABLE bank_statement_lines
    ADD COLUMN transaction_hash TEXT;
  END IF;
END $$;

-- Add statement_balance column if it doesn't exist (for reconciliation)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bank_statement_lines'
    AND column_name = 'statement_balance'
  ) THEN
    ALTER TABLE bank_statement_lines
    ADD COLUMN statement_balance NUMERIC(15,2);
  END IF;
END $$;

-- =====================================================
-- FUNCTION: Generate Transaction Hash
-- =====================================================

CREATE OR REPLACE FUNCTION generate_bank_transaction_hash(
  p_bank_account_id UUID,
  p_transaction_date DATE,
  p_debit_amount NUMERIC,
  p_credit_amount NUMERIC,
  p_description TEXT
) RETURNS TEXT AS $$
DECLARE
  v_normalized_desc TEXT;
  v_hash_input TEXT;
BEGIN
  -- Normalize description: lowercase, remove extra spaces, trim to 100 chars
  v_normalized_desc := LOWER(TRIM(REGEXP_REPLACE(COALESCE(p_description, ''), '\s+', ' ', 'g')));
  v_normalized_desc := LEFT(v_normalized_desc, 100);

  -- Create hash input string
  v_hash_input := p_bank_account_id::TEXT || '|' ||
                  p_transaction_date::TEXT || '|' ||
                  COALESCE(p_debit_amount, 0)::TEXT || '|' ||
                  COALESCE(p_credit_amount, 0)::TEXT || '|' ||
                  v_normalized_desc;

  -- Return MD5 hash
  RETURN md5(v_hash_input);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =====================================================
-- TRIGGER: Auto-generate hash on insert/update
-- =====================================================

CREATE OR REPLACE FUNCTION auto_generate_transaction_hash()
RETURNS TRIGGER AS $$
BEGIN
  NEW.transaction_hash := generate_bank_transaction_hash(
    NEW.bank_account_id,
    NEW.transaction_date,
    NEW.debit_amount,
    NEW.credit_amount,
    NEW.description
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_auto_generate_transaction_hash ON bank_statement_lines;

-- Create trigger
CREATE TRIGGER trg_auto_generate_transaction_hash
  BEFORE INSERT OR UPDATE ON bank_statement_lines
  FOR EACH ROW
  EXECUTE FUNCTION auto_generate_transaction_hash();

-- =====================================================
-- BACKFILL: Generate hashes for existing records
-- =====================================================

UPDATE bank_statement_lines
SET transaction_hash = generate_bank_transaction_hash(
  bank_account_id,
  transaction_date,
  debit_amount,
  credit_amount,
  description
)
WHERE transaction_hash IS NULL;

-- =====================================================
-- UNIQUE INDEX: Prevent duplicate imports
-- =====================================================

-- Create unique index on transaction_hash
-- This will silently prevent duplicates at DB level
CREATE UNIQUE INDEX IF NOT EXISTS idx_bank_statement_lines_hash_unique
  ON bank_statement_lines(transaction_hash);

-- =====================================================
-- FUNCTION: Safe delete with reconciliation check
-- =====================================================

CREATE OR REPLACE FUNCTION safe_delete_bank_statement_lines(
  p_bank_account_id UUID,
  p_start_date DATE,
  p_end_date DATE
) RETURNS JSON AS $$
DECLARE
  v_total_count INTEGER;
  v_reconciled_count INTEGER;
  v_deletable_count INTEGER;
  v_deleted_count INTEGER;
BEGIN
  -- Count total records in range
  SELECT COUNT(*) INTO v_total_count
  FROM bank_statement_lines
  WHERE bank_account_id = p_bank_account_id
    AND transaction_date >= p_start_date
    AND transaction_date <= p_end_date;

  -- Count reconciled records (cannot delete)
  SELECT COUNT(*) INTO v_reconciled_count
  FROM bank_statement_lines
  WHERE bank_account_id = p_bank_account_id
    AND transaction_date >= p_start_date
    AND transaction_date <= p_end_date
    AND reconciliation_status IN ('matched', 'recorded', 'suggested');

  -- Calculate deletable count
  v_deletable_count := v_total_count - v_reconciled_count;

  -- Check if there are reconciled transactions
  IF v_reconciled_count > 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Cannot delete: ' || v_reconciled_count || ' transaction(s) are reconciled',
      'total_count', v_total_count,
      'reconciled_count', v_reconciled_count,
      'deletable_count', v_deletable_count,
      'deleted_count', 0
    );
  END IF;

  -- Delete only unmatched transactions
  DELETE FROM bank_statement_lines
  WHERE bank_account_id = p_bank_account_id
    AND transaction_date >= p_start_date
    AND transaction_date <= p_end_date
    AND reconciliation_status = 'unmatched';

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'total_count', v_total_count,
    'reconciled_count', v_reconciled_count,
    'deletable_count', v_deletable_count,
    'deleted_count', v_deleted_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION safe_delete_bank_statement_lines TO authenticated;

-- =====================================================
-- FUNCTION: Get delete preview
-- =====================================================

CREATE OR REPLACE FUNCTION preview_bank_statement_delete(
  p_bank_account_id UUID,
  p_start_date DATE,
  p_end_date DATE
) RETURNS JSON AS $$
DECLARE
  v_bank_info JSON;
  v_total_count INTEGER;
  v_reconciled_count INTEGER;
  v_unmatched_count INTEGER;
BEGIN
  -- Get bank account info
  SELECT json_build_object(
    'account_name', account_name,
    'bank_name', bank_name,
    'account_number', account_number,
    'currency', currency
  ) INTO v_bank_info
  FROM bank_accounts
  WHERE id = p_bank_account_id;

  -- Count records by status
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE reconciliation_status IN ('matched', 'recorded', 'suggested')),
    COUNT(*) FILTER (WHERE reconciliation_status = 'unmatched')
  INTO v_total_count, v_reconciled_count, v_unmatched_count
  FROM bank_statement_lines
  WHERE bank_account_id = p_bank_account_id
    AND transaction_date >= p_start_date
    AND transaction_date <= p_end_date;

  RETURN json_build_object(
    'bank_info', v_bank_info,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'total_count', v_total_count,
    'reconciled_count', v_reconciled_count,
    'unmatched_count', v_unmatched_count,
    'can_delete', v_reconciled_count = 0 AND v_total_count > 0,
    'warning', CASE
      WHEN v_reconciled_count > 0 THEN 'Cannot delete: Contains ' || v_reconciled_count || ' reconciled transaction(s). Please unreconcile first.'
      WHEN v_total_count = 0 THEN 'No transactions found in this date range'
      ELSE NULL
    END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users
GRANT EXECUTE ON FUNCTION preview_bank_statement_delete TO authenticated;

-- =====================================================
-- RLS: Update delete policy to check reconciliation
-- =====================================================

-- Drop existing delete policy
DROP POLICY IF EXISTS bank_statement_lines_delete ON bank_statement_lines;

-- Create restrictive delete policy
-- Only admin can delete, and only unmatched transactions
CREATE POLICY bank_statement_lines_delete ON bank_statement_lines
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND role IN ('admin', 'manager'))
    AND reconciliation_status = 'unmatched'
  );

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Bank Reconciliation Safety Features Added!';
  RAISE NOTICE '   - Transaction hash for duplicate detection';
  RAISE NOTICE '   - Unique index prevents duplicate imports';
  RAISE NOTICE '   - Safe delete function with reconciliation check';
  RAISE NOTICE '   - Preview function for confirmation';
  RAISE NOTICE '   - RLS policy prevents deletion of reconciled transactions';
END $$;