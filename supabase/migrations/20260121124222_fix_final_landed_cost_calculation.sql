/*
  # Fix Final Landed Cost Calculation
  
  1. Problem
    - final_landed_cost showing only allocated cost, not total
    - Should be: import_price + import_cost_allocated
    - Currently showing: only import_cost_allocated
  
  2. Solution
    - Use batch record's import_price explicitly in calculation
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
  v_final_cost numeric;
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
    
    -- Calculate final landed cost = import price + allocated costs
    v_final_cost := v_batch_record.import_price + v_allocated_cost;
    
    -- Update batch with allocated costs and final landed cost
    UPDATE batches
    SET 
      import_cost_allocated = v_allocated_cost,
      final_landed_cost = v_final_cost
    WHERE id = v_batch_record.id;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION reallocate_container_costs IS 'Reallocates container import costs proportionally to all linked batches - FIXED to properly sum import_price + allocated costs';
