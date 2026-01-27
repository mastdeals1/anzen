/*
  # Hardening Fix #3: Atomic Delivered Quantity Update
  
  1. Problem
    - JS loop reads delivered_quantity, calculates, writes back
    - Multiple DCs updating same SO causes wrong totals
    
  2. Solution
    - Single atomic DB update using CASE expressions
    - No loops, no race conditions
    
  3. Business Logic Preserved
    - Same delivered_quantity tracking
    - Same SO status updates
*/

CREATE OR REPLACE FUNCTION update_so_delivered_quantity_atomic(
  p_sales_order_id UUID,
  p_dc_items JSONB[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
  -- Atomically increment delivered_quantity for matching products
  UPDATE sales_order_items soi
  SET delivered_quantity = COALESCE(soi.delivered_quantity, 0) + COALESCE(
    (
      SELECT SUM((item->>'quantity')::numeric)
      FROM unnest(p_dc_items) AS item
      WHERE (item->>'product_id')::uuid = soi.product_id
    ), 0
  )
  WHERE soi.sales_order_id = p_sales_order_id;
  
  -- Check if all items are fully delivered
  UPDATE sales_orders
  SET status = CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM sales_order_items
      WHERE sales_order_id = p_sales_order_id
      AND COALESCE(delivered_quantity, 0) < quantity
    ) THEN 'delivered'
    ELSE 'partial'
  END
  WHERE id = p_sales_order_id;
END;
$$;

COMMENT ON FUNCTION update_so_delivered_quantity_atomic IS 'Atomically updates delivered quantities for sales order. Prevents race conditions from concurrent DC creation.';
