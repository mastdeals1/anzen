/*
  # Fix Landed Cost Per-Unit Allocation
  
  1. Problem
    - Allocation calculates totals correctly
    - But landed_cost_per_unit not updated properly
    
  2. Solution
    - Allocate based on total import_price
    - Calculate per-unit allocated = allocated_cost / qty
    - landed_cost_per_unit = import_price_per_unit + (allocated_cost / qty)
    - final_landed_cost = total (for accounting)
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
  v_allocated_per_unit numeric;
  v_final_total_cost numeric;
  v_landed_cost_per_unit numeric;
BEGIN
  -- Get container costs (EXCLUDE PPN and Duty BM from allocation - they're separate)
  SELECT 
    COALESCE(freight_charges, 0) + 
    COALESCE(clearing_forwarding, 0) + 
    COALESCE(port_charges, 0) + 
    COALESCE(container_handling, 0) + 
    COALESCE(transportation, 0) + 
    COALESCE(other_import_costs, 0) +
    COALESCE(bpom_ski_fees, 0)
  INTO v_total_container_costs
  FROM import_containers
  WHERE id = p_container_id;

  -- Calculate total value of all batches in this container (sum of import_price which is total)
  SELECT COALESCE(SUM(import_price), 0) INTO v_total_batch_value
  FROM batches
  WHERE import_container_id = p_container_id;

  -- If no batches linked or no value, clear allocations
  IF v_total_batch_value = 0 THEN
    UPDATE batches
    SET 
      import_cost_allocated = 0,
      final_landed_cost = import_price,
      landed_cost_per_unit = import_price_per_unit
    WHERE import_container_id = p_container_id;
    RETURN;
  END IF;

  -- Allocate costs to each batch proportionally
  FOR v_batch_record IN 
    SELECT id, import_price, import_price_per_unit, import_quantity
    FROM batches
    WHERE import_container_id = p_container_id
  LOOP
    -- Calculate this batch's proportion of total value
    v_batch_percentage := (v_batch_record.import_price / v_total_batch_value);
    
    -- Allocate costs proportionally (total allocated cost for this batch)
    v_allocated_cost := v_total_container_costs * v_batch_percentage;
    
    -- Calculate per-unit allocated cost
    v_allocated_per_unit := v_allocated_cost / NULLIF(v_batch_record.import_quantity, 0);
    
    -- Calculate final landed cost per unit
    v_landed_cost_per_unit := v_batch_record.import_price_per_unit + v_allocated_per_unit;
    
    -- Calculate final total landed cost
    v_final_total_cost := v_batch_record.import_price + v_allocated_cost;
    
    -- Update batch
    UPDATE batches
    SET 
      import_cost_allocated = v_allocated_cost,
      final_landed_cost = v_final_total_cost,
      landed_cost_per_unit = v_landed_cost_per_unit
    WHERE id = v_batch_record.id;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION reallocate_container_costs IS 'Allocates container costs proportionally and calculates per-unit landed cost = import_price_per_unit + (allocated_cost / qty)';
