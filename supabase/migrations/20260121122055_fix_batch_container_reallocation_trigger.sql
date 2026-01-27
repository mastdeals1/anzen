/*
  # Fix Batch Container Cost Reallocation Trigger
  
  1. Problem
    - `reallocate_on_batch_container_change()` calls `allocate_container_costs_to_batches()` 
    - But that's a TRIGGER function, not a regular function
    - Trigger functions cannot be called directly
  
  2. Solution
    - Create a regular procedure `reallocate_container_costs()` that takes container_id
    - Update the batch trigger to call this procedure instead
*/

-- Create a regular function that can be called to reallocate costs for a container
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
      final_landed_cost = import_price,
      cost_per_unit = import_price / NULLIF(import_quantity, 0)
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
    UPDATE batches
    SET 
      import_cost_allocated = v_allocated_cost,
      final_landed_cost = import_price + v_allocated_cost,
      cost_per_unit = (import_price + v_allocated_cost) / NULLIF(import_quantity, 0)
    WHERE id = v_batch_record.id;
  END LOOP;
END;
$$;

-- Update the container trigger to use the new trigger function
CREATE OR REPLACE FUNCTION allocate_container_costs_to_batches()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Call the regular function to do the allocation
  PERFORM reallocate_container_costs(NEW.id);
  RETURN NEW;
END;
$$;

-- Update the batch trigger to call the regular function instead
CREATE OR REPLACE FUNCTION reallocate_on_batch_container_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- If container assignment changed, reallocate costs for OLD container
  IF TG_OP = 'UPDATE' AND OLD.import_container_id IS NOT NULL 
     AND (NEW.import_container_id IS NULL OR NEW.import_container_id != OLD.import_container_id) THEN
    PERFORM reallocate_container_costs(OLD.import_container_id);
  END IF;

  -- Reallocate costs for NEW container
  IF NEW.import_container_id IS NOT NULL THEN
    PERFORM reallocate_container_costs(NEW.import_container_id);
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION reallocate_container_costs IS 'Reallocates container import costs proportionally to all linked batches';
