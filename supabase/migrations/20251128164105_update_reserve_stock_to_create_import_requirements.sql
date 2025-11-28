/*
  # Update Stock Reservation to Auto-Create Import Requirements

  ## Summary
  Updates the fn_reserve_stock_for_so function to automatically create
  import requirements when shortage is detected.

  ## Changes
  - Modifies fn_reserve_stock_for_so to call fn_create_import_requirements when shortage occurs
  - Ensures import requirements are created immediately when SO is approved with shortage
*/

CREATE OR REPLACE FUNCTION fn_reserve_stock_for_so(p_so_id uuid)
RETURNS TABLE(
  success boolean,
  message text,
  shortage_items jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item RECORD;
  v_batch RECORD;
  v_remaining_qty numeric;
  v_reserve_qty numeric;
  v_user_id uuid;
  v_so_number text;
  v_shortage_list jsonb := '[]'::jsonb;
  v_has_shortage boolean := false;
BEGIN
  -- Get user ID and SO number
  SELECT created_by, so_number INTO v_user_id, v_so_number 
  FROM sales_orders WHERE id = p_so_id;
  
  -- Loop through each SO item
  FOR v_item IN 
    SELECT * FROM sales_order_items 
    WHERE sales_order_id = p_so_id 
    ORDER BY created_at
  LOOP
    v_remaining_qty := v_item.quantity;
    
    -- Find available batches using FIFO (earliest expiry first)
    FOR v_batch IN
      SELECT 
        b.id,
        b.batch_number,
        fn_get_free_stock(b.id) as free_stock
      FROM batches b
      WHERE b.product_id = v_item.product_id
      AND b.current_stock > 0
      ORDER BY b.expiry_date ASC, b.created_at ASC
    LOOP
      EXIT WHEN v_remaining_qty <= 0;
      
      IF v_batch.free_stock > 0 THEN
        -- Reserve from this batch
        v_reserve_qty := LEAST(v_remaining_qty, v_batch.free_stock);
        
        INSERT INTO stock_reservations (
          sales_order_id,
          sales_order_item_id,
          batch_id,
          product_id,
          reserved_quantity,
          reserved_by,
          status
        ) VALUES (
          p_so_id,
          v_item.id,
          v_batch.id,
          v_item.product_id,
          v_reserve_qty,
          v_user_id,
          'active'
        );
        
        -- Create inventory transaction for reservation
        INSERT INTO inventory_transactions (
          product_id,
          batch_id,
          transaction_type,
          quantity,
          transaction_date,
          reference_number,
          notes,
          created_by
        ) VALUES (
          v_item.product_id,
          v_batch.id,
          'reservation',
          v_reserve_qty,
          CURRENT_DATE,
          v_so_number,
          'Stock reserved for SO: ' || v_so_number,
          v_user_id
        );
        
        v_remaining_qty := v_remaining_qty - v_reserve_qty;
      END IF;
    END LOOP;
    
    -- Check if there's still shortage
    IF v_remaining_qty > 0 THEN
      v_has_shortage := true;
      v_shortage_list := v_shortage_list || jsonb_build_object(
        'product_id', v_item.product_id,
        'required_qty', v_item.quantity,
        'shortage_qty', v_remaining_qty
      );
    END IF;
  END LOOP;
  
  -- Update SO status
  IF v_has_shortage THEN
    UPDATE sales_orders 
    SET status = 'shortage', updated_at = now()
    WHERE id = p_so_id;
    
    -- Auto-create import requirements for shortage
    PERFORM fn_create_import_requirements(p_so_id, v_shortage_list);
    
    RETURN QUERY SELECT false, 'Partial stock reserved - shortage detected. Import requirements created.', v_shortage_list;
  ELSE
    UPDATE sales_orders 
    SET status = 'stock_reserved', updated_at = now()
    WHERE id = p_so_id;
    
    RETURN QUERY SELECT true, 'Stock reserved successfully', '[]'::jsonb;
  END IF;
END;
$$;

COMMENT ON FUNCTION fn_reserve_stock_for_so IS 'Reserves stock for SO, creates inventory transactions, and auto-generates import requirements on shortage';
