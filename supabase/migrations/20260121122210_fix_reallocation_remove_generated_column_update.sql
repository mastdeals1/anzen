/*
  # Fix Reallocation - Remove Generated Column Update
  
  1. Problem
    - Trying to update `cost_per_unit` which is a GENERATED column
    - Generated columns cannot be manually updated
  
  2. Solution
    - Remove `cost_per_unit` from UPDATE statement
    - It will calculate automatically based on other columns
*/

CREATE OR REPLACE FUNCTION reallocate_container_costs(p_container_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_batch_record RECORD;
  v_total_batch_value numeric := 0;
  v_batch_percentage numeric;
  v_total_container_costs numeric := 0;
  v_allocated_cost numeric;
BEGIN
  -- Get container costs
  SELECT 
    COALESCE(duty_bm, 0) + 
    COALESCE(freight_charges, 0) + 
    COALESCE(clearing_forwarding, 0) + 
    COALESCE(port_charges, 0) + 
    COALESCE(container_handling, 0) + 
    COALESCE(transportation, 0) + 
    COALESCE(other_import_costs, 0) +
    COALESCE(pph_import, 0)
  INTO v_total_container_costs
  FROM import_containers
  WHERE id = p_container_id;

  -- Calculate total value of all batches in this container
  SELECT COALESCE(SUM(import_price), 0) INTO v_total_batch_value
  FROM batches
  WHERE import_container_id = p_container_id;

  -- If no batches linked or no value, clear allocations
  IF v_total_batch_value = 0 THEN
    UPDATE batches
    SET 
      import_cost_allocated = 0,
      final_landed_cost = import_price
    WHERE import_container_id = p_container_id;
    RETURN;
  END IF;

  -- Allocate costs to each batch proportionally
  FOR v_batch_record IN 
    SELECT id, import_price, import_quantity
    FROM batches
    WHERE import_container_id = p_container_id
  LOOP
    -- Calculate this batch's proportion of total value
    v_batch_percentage := (v_batch_record.import_price / v_total_batch_value);
    
    -- Allocate costs proportionally
    v_allocated_cost := v_total_container_costs * v_batch_percentage;
    
    -- Update batch with allocated costs and final landed cost
    -- Do NOT update cost_per_unit - it's a generated column
    UPDATE batches
    SET 
      import_cost_allocated = v_allocated_cost,
      final_landed_cost = import_price + v_allocated_cost
    WHERE id = v_batch_record.id;
  END LOOP;
END;
$$;
