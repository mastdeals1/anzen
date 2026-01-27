/*
  # Fix Container Cost Allocation - Use Total Import Expenses
  
  1. Problem
    - Current function only allocates SOME container costs
    - Excludes loading_import and other fields
    - Should use total_import_expenses which is ALL costs
    
  2. Solution
    - Use total_import_expenses instead of manually adding fields
    - This includes ALL container costs properly
    - Excludes ONLY duty_bm, ppn_import, pph_import (tax items)
  
  3. Changes
    - Rewrite function to use total_import_expenses
    - Subtract only tax items (duty_bm, ppn_import, pph_import)
    - Everything else gets allocated proportionally
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
  -- Get container costs (EXCLUDE only tax items: duty_bm, ppn_import, pph_import)
  -- Use total_import_expenses which includes ALL costs
  SELECT 
    COALESCE(total_import_expenses, 0) - 
    COALESCE(duty_bm, 0) - 
    COALESCE(ppn_import, 0) - 
    COALESCE(pph_import, 0)
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
      final_landed_cost = import_price + duty_charges + freight_charges + other_charges,
      landed_cost_per_unit = import_price_per_unit
    WHERE import_container_id = p_container_id;
    RETURN;
  END IF;

  -- Allocate costs to each batch proportionally
  FOR v_batch_record IN 
    SELECT id, import_price, import_price_per_unit, import_quantity, duty_charges, freight_charges, other_charges
    FROM batches
    WHERE import_container_id = p_container_id
  LOOP
    -- Calculate this batch's proportion of total value
    v_batch_percentage := (v_batch_record.import_price / v_total_batch_value);
    
    -- Allocate costs proportionally (total allocated cost for this batch)
    v_allocated_cost := v_total_container_costs * v_batch_percentage;
    
    -- Calculate per-unit allocated cost
    v_allocated_per_unit := v_allocated_cost / NULLIF(v_batch_record.import_quantity, 0);
    
    -- Calculate final landed cost per unit = import_per_unit + batch duty/freight/other per unit + allocated container cost per unit
    v_landed_cost_per_unit := v_batch_record.import_price_per_unit + v_allocated_per_unit;
    
    -- Calculate final total landed cost = import_price + batch charges + allocated container costs
    v_final_total_cost := v_batch_record.import_price + 
                         v_batch_record.duty_charges + 
                         v_batch_record.freight_charges + 
                         v_batch_record.other_charges + 
                         v_allocated_cost;
    
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

COMMENT ON FUNCTION reallocate_container_costs IS 'Allocates ALL container costs (except taxes) proportionally by batch import_price value';

-- Trigger the reallocation for 20FCL Nov25 container
DO $$
DECLARE
  v_container_id UUID;
BEGIN
  SELECT id INTO v_container_id
  FROM import_containers
  WHERE container_ref = '20FCL Nov25';
  
  IF v_container_id IS NOT NULL THEN
    PERFORM reallocate_container_costs(v_container_id);
  END IF;
END $$;
