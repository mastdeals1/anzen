-- ==========================================
-- INVENTORY AUDIT AND REPAIR SCRIPT
-- ==========================================
--
-- PURPOSE: Find and fix all inventory inconsistencies
-- USAGE:
--   1. Run this entire script in Supabase SQL Editor
--   2. Review the audit results
--   3. Run repair functions with dry_run=true first
--   4. Run repair functions with dry_run=false to apply fixes
--
-- IMPORTANT: This script is SAFE to run multiple times
-- ==========================================

-- Function to audit a specific batch
CREATE OR REPLACE FUNCTION fn_audit_batch_stock(p_batch_id uuid)
RETURNS TABLE (
  issue_type text,
  expected_value numeric,
  actual_value numeric,
  difference numeric,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch RECORD;
  v_import_qty numeric;
  v_current_stock numeric;
  v_transaction_sum numeric;
  v_purchase_sum numeric;
  v_sale_sum numeric;
  v_dc_sum numeric;
  v_adjustment_sum numeric;
  v_transaction_count integer;
BEGIN
  SELECT
    b.id, b.batch_number, b.product_id,
    p.product_name, b.import_quantity, b.current_stock,
    b.import_date, b.created_at
  INTO v_batch
  FROM batches b
  JOIN products p ON b.product_id = p.id
  WHERE b.id = p_batch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Batch not found: %', p_batch_id;
  END IF;

  v_import_qty := v_batch.import_quantity;
  v_current_stock := v_batch.current_stock;

  SELECT
    COUNT(*),
    COALESCE(SUM(quantity), 0),
    COALESCE(SUM(quantity) FILTER (WHERE transaction_type = 'purchase'), 0),
    COALESCE(SUM(quantity) FILTER (WHERE transaction_type IN ('sale', 'delivery_challan')), 0),
    COALESCE(SUM(quantity) FILTER (WHERE transaction_type = 'delivery_challan'), 0),
    COALESCE(SUM(quantity) FILTER (WHERE transaction_type = 'adjustment'), 0)
  INTO
    v_transaction_count,
    v_transaction_sum,
    v_purchase_sum,
    v_sale_sum,
    v_dc_sum,
    v_adjustment_sum
  FROM inventory_transactions
  WHERE batch_id = p_batch_id;

  IF v_purchase_sum != v_import_qty THEN
    RETURN QUERY SELECT
      'PURCHASE_MISMATCH'::text,
      v_import_qty,
      v_purchase_sum,
      v_purchase_sum - v_import_qty,
      jsonb_build_object(
        'batch_number', v_batch.batch_number,
        'product', v_batch.product_name,
        'message', 'Purchase transactions do not match import quantity',
        'import_quantity', v_import_qty,
        'purchase_sum', v_purchase_sum
      );
  END IF;

  IF v_current_stock != v_transaction_sum THEN
    RETURN QUERY SELECT
      'STOCK_MISMATCH'::text,
      v_transaction_sum,
      v_current_stock,
      v_current_stock - v_transaction_sum,
      jsonb_build_object(
        'batch_number', v_batch.batch_number,
        'product', v_batch.product_name,
        'message', 'Current stock does not match transaction sum',
        'expected_stock', v_transaction_sum,
        'actual_stock', v_current_stock,
        'transaction_count', v_transaction_count,
        'purchase_sum', v_purchase_sum,
        'sale_sum', v_sale_sum,
        'dc_sum', v_dc_sum,
        'adjustment_sum', v_adjustment_sum
      );
  END IF;

  IF v_current_stock < 0 THEN
    RETURN QUERY SELECT
      'NEGATIVE_STOCK'::text,
      0::numeric,
      v_current_stock,
      v_current_stock,
      jsonb_build_object(
        'batch_number', v_batch.batch_number,
        'product', v_batch.product_name,
        'message', 'Batch has negative stock',
        'current_stock', v_current_stock
      );
  END IF;

  IF v_transaction_count = 0 OR v_purchase_sum = 0 THEN
    RETURN QUERY SELECT
      'MISSING_PURCHASE'::text,
      v_import_qty,
      0::numeric,
      -v_import_qty,
      jsonb_build_object(
        'batch_number', v_batch.batch_number,
        'product', v_batch.product_name,
        'message', 'Batch has no purchase transaction',
        'import_quantity', v_import_qty,
        'created_at', v_batch.created_at
      );
  END IF;

  RETURN;
END;
$$;

-- Function to audit ALL batches
CREATE OR REPLACE FUNCTION fn_audit_all_batches()
RETURNS TABLE (
  batch_id uuid,
  batch_number text,
  product_name text,
  issue_type text,
  expected_value numeric,
  actual_value numeric,
  difference numeric,
  details jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch RECORD;
BEGIN
  FOR v_batch IN SELECT id FROM batches WHERE is_active = true
  LOOP
    RETURN QUERY
    SELECT
      v_batch.id,
      (SELECT b.batch_number FROM batches b WHERE b.id = v_batch.id),
      (SELECT p.product_name FROM batches b JOIN products p ON b.product_id = p.id WHERE b.id = v_batch.id),
      a.issue_type,
      a.expected_value,
      a.actual_value,
      a.difference,
      a.details
    FROM fn_audit_batch_stock(v_batch.id) a
    WHERE a.issue_type != 'OK';
  END LOOP;

  RETURN;
END;
$$;

-- Function to repair a specific batch
CREATE OR REPLACE FUNCTION fn_repair_batch_stock(p_batch_id uuid, p_dry_run boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch RECORD;
  v_transaction_count integer;
  v_purchase_count integer;
  v_import_qty numeric;
  v_calculated_stock numeric;
  v_actions jsonb := '[]'::jsonb;
  v_action jsonb;
BEGIN
  SELECT
    b.id, b.batch_number, b.product_id, b.import_quantity,
    b.current_stock, b.import_date, b.created_by
  INTO v_batch
  FROM batches b
  WHERE b.id = p_batch_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Batch not found', 'batch_id', p_batch_id);
  END IF;

  v_import_qty := v_batch.import_quantity;

  SELECT COUNT(*) INTO v_transaction_count
  FROM inventory_transactions
  WHERE batch_id = p_batch_id;

  SELECT COUNT(*) INTO v_purchase_count
  FROM inventory_transactions
  WHERE batch_id = p_batch_id AND transaction_type = 'purchase';

  IF v_purchase_count = 0 THEN
    v_action := jsonb_build_object(
      'action', 'ADD_PURCHASE_TRANSACTION',
      'quantity', v_import_qty,
      'batch_number', v_batch.batch_number,
      'dry_run', p_dry_run
    );
    v_actions := v_actions || jsonb_build_array(v_action);

    IF NOT p_dry_run THEN
      INSERT INTO inventory_transactions (
        product_id, batch_id, transaction_type, quantity,
        transaction_date, reference_number, notes, created_by
      ) VALUES (
        v_batch.product_id, v_batch.id, 'purchase', v_import_qty,
        v_batch.import_date, v_batch.batch_number,
        'SYSTEM FIX: Added missing purchase transaction for batch import',
        COALESCE(v_batch.created_by, (SELECT id FROM user_profiles LIMIT 1))
      );
    END IF;
  END IF;

  SELECT COALESCE(SUM(quantity), 0)
  INTO v_calculated_stock
  FROM inventory_transactions
  WHERE batch_id = p_batch_id;

  IF p_dry_run AND v_purchase_count = 0 THEN
    v_calculated_stock := v_calculated_stock + v_import_qty;
  END IF;

  IF v_batch.current_stock != v_calculated_stock THEN
    v_action := jsonb_build_object(
      'action', 'UPDATE_CURRENT_STOCK',
      'old_value', v_batch.current_stock,
      'new_value', v_calculated_stock,
      'difference', v_calculated_stock - v_batch.current_stock,
      'batch_number', v_batch.batch_number,
      'dry_run', p_dry_run
    );
    v_actions := v_actions || jsonb_build_array(v_action);

    IF NOT p_dry_run THEN
      UPDATE batches
      SET current_stock = v_calculated_stock,
          updated_at = now()
      WHERE id = p_batch_id;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'batch_id', v_batch.id,
    'batch_number', v_batch.batch_number,
    'import_quantity', v_import_qty,
    'old_stock', v_batch.current_stock,
    'new_stock', v_calculated_stock,
    'transaction_count', v_transaction_count,
    'actions_taken', v_actions,
    'dry_run', p_dry_run,
    'status', CASE WHEN jsonb_array_length(v_actions) = 0 THEN 'NO_ACTION_NEEDED' ELSE 'FIXED' END
  );
END;
$$;

-- Function to repair ALL batches
CREATE OR REPLACE FUNCTION fn_repair_all_batches(p_dry_run boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_batch RECORD;
  v_result jsonb;
  v_results jsonb := '[]'::jsonb;
  v_fixed_count integer := 0;
  v_error_count integer := 0;
BEGIN
  FOR v_batch IN SELECT id FROM batches WHERE is_active = true ORDER BY created_at
  LOOP
    BEGIN
      v_result := fn_repair_batch_stock(v_batch.id, p_dry_run);

      IF v_result->>'status' = 'FIXED' THEN
        v_fixed_count := v_fixed_count + 1;
        v_results := v_results || jsonb_build_array(v_result);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_error_count := v_error_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'batch_id', v_batch.id,
        'error', SQLERRM
      ));
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'dry_run', p_dry_run,
    'total_batches', (SELECT COUNT(*) FROM batches WHERE is_active = true),
    'batches_fixed', v_fixed_count,
    'errors', v_error_count,
    'details', v_results
  );
END;
$$;

-- ==========================================
-- USAGE EXAMPLES
-- ==========================================

-- 1. Audit all batches and see issues
-- SELECT * FROM fn_audit_all_batches();

-- 2. Audit specific batch (Ibuprofen)
-- SELECT * FROM fn_audit_batch_stock('batch-id-here');

-- 3. Preview fixes for all batches (DRY RUN - no changes made)
-- SELECT fn_repair_all_batches(true);

-- 4. APPLY FIXES to all batches (WILL MAKE CHANGES!)
-- SELECT fn_repair_all_batches(false);

-- 5. Fix specific batch only
-- SELECT fn_repair_batch_stock('batch-id-here', false);