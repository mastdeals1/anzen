/*
  # Fix DC Edit Duplicate Transaction Bug
  
  ## Problem
  The edit_delivery_challan() RPC function creates manual inventory_transactions 
  when adding new items (lines 164-173). Then when the DC is approved, the 
  trg_dc_approval_deduct_stock() trigger creates ANOTHER set of transactions.
  
  Result: DOUBLE transactions for the same delivery!
  
  ## Solution
  Remove the manual transaction creation from edit_delivery_challan().
  Only the approval trigger should create transactions.
  
  Reservations should be tracked via reserved_stock in batches table ONLY,
  NOT in inventory_transactions until actual approval/deduction.
*/

CREATE OR REPLACE FUNCTION edit_delivery_challan(
  p_challan_id uuid,
  p_new_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_challan record;
  v_item jsonb;
  v_count integer;
  v_old_items record;
  v_old_qty numeric;
  v_new_qty numeric;
  v_difference numeric;
  v_product_id uuid;
  v_batch_id uuid;
  v_current_stock numeric;
  v_reserved_stock numeric;
BEGIN
  -- Get challan details
  SELECT * INTO v_challan
  FROM delivery_challans
  WHERE id = p_challan_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Delivery challan not found');
  END IF;
  
  -- Cannot edit if ever approved
  IF v_challan.approved_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Cannot edit approved delivery challan'
    );
  END IF;
  
  -- Validate new items count
  SELECT count(*) INTO v_count FROM jsonb_array_elements(p_new_items);
  IF v_count = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot save DC with no items');
  END IF;
  
  -- DISABLE automatic trigger for this transaction
  PERFORM set_config('app.skip_dc_item_trigger', 'true', true);
  
  -- Step 1: Release reservations for items being REMOVED
  FOR v_old_items IN 
    SELECT dci.*, b.batch_number, b.current_stock
    FROM delivery_challan_items dci
    JOIN batches b ON dci.batch_id = b.id
    WHERE dci.challan_id = p_challan_id
    AND dci.batch_id NOT IN (
      SELECT (item->>'batch_id')::uuid 
      FROM jsonb_array_elements(p_new_items) item
    )
  LOOP
    -- Release reservation
    UPDATE batches
    SET reserved_stock = GREATEST(0, COALESCE(reserved_stock, 0) - v_old_items.quantity)
    WHERE id = v_old_items.batch_id;
    
    -- Delete the item
    DELETE FROM delivery_challan_items WHERE id = v_old_items.id;
  END LOOP;
  
  -- Step 2: Process each NEW item (update existing or insert new)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_new_items)
  LOOP
    v_product_id := (v_item->>'product_id')::uuid;
    v_batch_id := (v_item->>'batch_id')::uuid;
    v_new_qty := (v_item->>'quantity')::numeric;
    
    -- Check if this batch already exists in old items
    SELECT quantity INTO v_old_qty
    FROM delivery_challan_items
    WHERE challan_id = p_challan_id
      AND batch_id = v_batch_id;
    
    IF FOUND THEN
      -- Batch exists - calculate difference
      v_difference := v_new_qty - v_old_qty;
      
      IF v_difference != 0 THEN
        -- Get current batch state
        SELECT current_stock, reserved_stock 
        INTO v_current_stock, v_reserved_stock
        FROM batches WHERE id = v_batch_id;
        
        -- Check if we can adjust
        IF (COALESCE(v_reserved_stock, 0) + v_difference) > v_current_stock THEN
          RAISE EXCEPTION 'Insufficient stock: Batch has %kg available, currently reserved %kg, trying to add %kg more', 
            v_current_stock, COALESCE(v_reserved_stock, 0), v_difference;
        END IF;
        
        -- Adjust reservation by difference
        UPDATE batches
        SET reserved_stock = COALESCE(reserved_stock, 0) + v_difference
        WHERE id = v_batch_id;
        
        -- Update the item quantity
        UPDATE delivery_challan_items
        SET quantity = v_new_qty,
            pack_size = (v_item->>'pack_size')::numeric,
            pack_type = v_item->>'pack_type',
            number_of_packs = (v_item->>'number_of_packs')::integer
        WHERE challan_id = p_challan_id
          AND batch_id = v_batch_id;
      END IF;
      
    ELSE
      -- New batch - reserve full quantity
      SELECT current_stock, reserved_stock 
      INTO v_current_stock, v_reserved_stock
      FROM batches WHERE id = v_batch_id;
      
      -- Check if we can reserve
      IF (COALESCE(v_reserved_stock, 0) + v_new_qty) > v_current_stock THEN
        RAISE EXCEPTION 'Insufficient stock: Batch has %kg available, %kg already reserved, cannot reserve additional %kg', 
          v_current_stock, COALESCE(v_reserved_stock, 0), v_new_qty;
      END IF;
      
      -- Reserve stock MANUALLY
      UPDATE batches
      SET reserved_stock = COALESCE(reserved_stock, 0) + v_new_qty
      WHERE id = v_batch_id;
      
      -- Insert new item (trigger is disabled, won't double-reserve)
      INSERT INTO delivery_challan_items (
        challan_id, 
        product_id, 
        batch_id, 
        quantity,
        pack_size, 
        pack_type, 
        number_of_packs
      ) VALUES (
        p_challan_id,
        v_product_id,
        v_batch_id,
        v_new_qty,
        (v_item->>'pack_size')::numeric,
        v_item->>'pack_type',
        (v_item->>'number_of_packs')::integer
      );
      
      -- DO NOT create inventory_transactions here!
      -- Transactions are ONLY created on approval by trg_dc_approval_deduct_stock()
      -- Reservations are tracked via batches.reserved_stock only
      
    END IF;
  END LOOP;
  
  -- RE-ENABLE automatic trigger
  PERFORM set_config('app.skip_dc_item_trigger', 'false', true);
  
  RETURN jsonb_build_object('success', true, 'message', 'Delivery challan updated successfully');
  
EXCEPTION
  WHEN foreign_key_violation THEN
    PERFORM set_config('app.skip_dc_item_trigger', 'false', true);
    RETURN jsonb_build_object('success', false, 'error', 'Invalid product or batch selection');
  WHEN OTHERS THEN
    PERFORM set_config('app.skip_dc_item_trigger', 'false', true);
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;