/*
  # Add Inventory Transaction Tracking for Stock Reservations

  ## Summary
  Updates stock reservation functions to create inventory transactions
  so that reserved stock is visible in the Inventory module.

  ## Changes
  - Updates `fn_reserve_stock_for_so` to create "reservation" type transactions
  - Updates `fn_release_stock_reservations` to create "release_reservation" type transactions
  - Updates `fn_approve_delivery_challan` to create "delivery" type transactions

  ## New Transaction Types
  - `reservation` - Stock reserved for sales order
  - `release_reservation` - Reserved stock released back to available
  - `delivery` - Stock delivered to customer (from challan approval)
*/

-- Update the stock reservation function to create inventory transactions
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
    
    RETURN QUERY SELECT false, 'Partial stock reserved - shortage detected', v_shortage_list;
  ELSE
    UPDATE sales_orders 
    SET status = 'stock_reserved', updated_at = now()
    WHERE id = p_so_id;
    
    RETURN QUERY SELECT true, 'Stock reserved successfully', '[]'::jsonb;
  END IF;
END;
$$;

-- Update release function to create inventory transactions
CREATE OR REPLACE FUNCTION fn_release_stock_reservations(
  p_so_id uuid,
  p_reason text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reservation RECORD;
  v_so_number text;
BEGIN
  -- Get SO number
  SELECT so_number INTO v_so_number FROM sales_orders WHERE id = p_so_id;
  
  -- Create release transactions for each active reservation
  FOR v_reservation IN
    SELECT * FROM stock_reservations
    WHERE sales_order_id = p_so_id
    AND status = 'active'
  LOOP
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
      v_reservation.product_id,
      v_reservation.batch_id,
      'release_reservation',
      v_reservation.reserved_quantity,
      CURRENT_DATE,
      v_so_number,
      'Reservation released: ' || p_reason,
      auth.uid()
    );
  END LOOP;
  
  -- Update reservation status
  UPDATE stock_reservations
  SET 
    status = 'released',
    released_at = now(),
    released_by = auth.uid(),
    release_reason = p_reason
  WHERE sales_order_id = p_so_id
  AND status = 'active';
  
  RETURN true;
END;
$$;

-- Update delivery challan approval to create proper inventory transactions
CREATE OR REPLACE FUNCTION fn_approve_delivery_challan(
  p_dc_id uuid,
  p_approver_id uuid,
  p_remarks text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_so_id uuid;
  v_dc_item RECORD;
  v_dc_number text;
BEGIN
  -- Get SO ID and DC number
  SELECT sales_order_id, challan_number INTO v_so_id, v_dc_number 
  FROM delivery_challans WHERE id = p_dc_id;
  
  -- Update DC to approved
  UPDATE delivery_challans
  SET 
    approval_status = 'approved',
    approved_by = p_approver_id,
    approved_at = now()
  WHERE id = p_dc_id;
  
  -- Loop through DC items
  FOR v_dc_item IN
    SELECT dci.product_id, dci.quantity, dci.batch_id
    FROM delivery_challan_items dci
    WHERE dci.delivery_challan_id = p_dc_id
  LOOP
    -- Create inventory transaction for delivery
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
      v_dc_item.product_id,
      v_dc_item.batch_id,
      'delivery',
      -v_dc_item.quantity,  -- Negative because stock is going out
      CURRENT_DATE,
      v_dc_number,
      'Delivered via DC: ' || v_dc_number,
      p_approver_id
    );
    
    -- If linked to SO, update delivered quantities and consume reservations
    IF v_so_id IS NOT NULL THEN
      UPDATE sales_order_items
      SET delivered_quantity = delivered_quantity + v_dc_item.quantity
      WHERE sales_order_id = v_so_id
      AND product_id = v_dc_item.product_id;
      
      -- Mark reservations as consumed
      UPDATE stock_reservations
      SET status = 'consumed'
      WHERE sales_order_id = v_so_id
      AND product_id = v_dc_item.product_id
      AND batch_id = v_dc_item.batch_id
      AND status = 'active';
    END IF;
  END LOOP;
  
  -- If linked to SO, check delivery status
  IF v_so_id IS NOT NULL THEN
    UPDATE sales_orders
    SET status = CASE
      WHEN (SELECT SUM(quantity) FROM sales_order_items WHERE sales_order_id = v_so_id) =
           (SELECT SUM(delivered_quantity) FROM sales_order_items WHERE sales_order_id = v_so_id)
      THEN 'delivered'
      ELSE 'partially_delivered'
    END
    WHERE id = v_so_id;
  END IF;
  
  RETURN true;
END;
$$;

COMMENT ON FUNCTION fn_reserve_stock_for_so IS 'Reserves stock for sales order and creates inventory transactions';
COMMENT ON FUNCTION fn_release_stock_reservations IS 'Releases stock reservations and creates inventory transactions';
COMMENT ON FUNCTION fn_approve_delivery_challan IS 'Approves delivery challan, creates inventory transactions, and updates stock';
