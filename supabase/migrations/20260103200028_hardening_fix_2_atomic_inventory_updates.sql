/*
  # Hardening Fix #2: Atomic Inventory Stock Updates
  
  1. Problem
    - Client reads current_stock, calculates new value, writes back
    - Two simultaneous updates cause data loss
    
  2. Solution
    - DB-side atomic increment/decrement
    - UPDATE batches SET current_stock = current_stock + qty
    
  3. Business Logic Preserved
    - Same stock movement logic
    - Execution becomes race-condition safe
*/

CREATE OR REPLACE FUNCTION adjust_batch_stock_atomic(
  p_batch_id UUID,
  p_quantity_change NUMERIC,
  p_transaction_type TEXT,
  p_reference_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_created_by UUID DEFAULT NULL
)
RETURNS TABLE(new_stock NUMERIC, transaction_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_transaction_id UUID;
  v_new_stock NUMERIC;
  v_product_id UUID;
BEGIN
  -- Get product_id for transaction record
  SELECT product_id INTO v_product_id
  FROM batches
  WHERE id = p_batch_id;
  
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'Batch not found: %', p_batch_id;
  END IF;
  
  -- Atomically update batch stock
  UPDATE batches
  SET current_stock = current_stock + p_quantity_change
  WHERE id = p_batch_id
  RETURNING current_stock INTO v_new_stock;
  
  -- Create inventory transaction record
  INSERT INTO inventory_transactions (
    product_id,
    batch_id,
    transaction_type,
    quantity,
    reference_id,
    notes,
    created_by
  ) VALUES (
    v_product_id,
    p_batch_id,
    p_transaction_type,
    ABS(p_quantity_change),
    p_reference_id,
    p_notes,
    p_created_by
  )
  RETURNING id INTO v_transaction_id;
  
  RETURN QUERY SELECT v_new_stock, v_transaction_id;
END;
$$;

COMMENT ON FUNCTION adjust_batch_stock_atomic IS 'Atomically adjusts batch stock with DB-side calculation. Prevents race conditions in concurrent updates.';
