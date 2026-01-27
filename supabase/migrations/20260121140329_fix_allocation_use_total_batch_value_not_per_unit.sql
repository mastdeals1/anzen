/*
  # Fix Container Cost Allocation - Use Total Batch Value
  
  1. Problem
    - Current allocation uses import_price which is PER UNIT
    - Should use import_price × quantity = TOTAL batch value
    
  2. Example: Ibuprofen
    - Per unit: $9.15 × 16,743 = Rp 153,198.45/kg
    - Quantity: 1,000 kg
    - Total batch value: 153,198.45 × 1,000 = Rp 153,198,450
    
  3. Correct Allocation Formula
    - Sum all batches TOTAL value: Σ(import_price × qty)
    - Container total: 34,299,504
    - Batch proportion: (batch_total_value / sum_total_values)
    - Allocated to batch: container_total × proportion
    - Per unit allocated: allocated / quantity
    - Landed cost per unit: import_price_per_unit + (allocated / qty)
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
  v_batch_total_value numeric;
  v_batch_percentage numeric;
  v_total_container_costs numeric := 0;
  v_allocated_cost numeric;
  v_allocated_per_unit numeric;
  v_final_total_cost numeric;
  v_landed_cost_per_unit numeric;
BEGIN
  -- Get container costs (EXCLUDE only tax items: duty_bm, ppn_import, pph_import)
  SELECT 
    COALESCE(total_import_expenses, 0) - 
    COALESCE(duty_bm, 0) - 
    COALESCE(ppn_import, 0) - 
    COALESCE(pph_import, 0)
  INTO v_total_container_costs
  FROM import_containers
  WHERE id = p_container_id;

  -- Calculate TOTAL VALUE of all batches (import_price × quantity for each batch)
  SELECT COALESCE(SUM(import_price * import_quantity), 0) INTO v_total_batch_value
  FROM batches
  WHERE import_container_id = p_container_id;

  -- If no batches linked or no value, clear allocations
  IF v_total_batch_value = 0 THEN
    UPDATE batches
    SET 
      import_cost_allocated = 0,
      final_landed_cost = (import_price + duty_charges + freight_charges + other_charges) * import_quantity,
      landed_cost_per_unit = import_price + duty_charges + freight_charges + other_charges
    WHERE import_container_id = p_container_id;
    RETURN;
  END IF;

  -- Allocate costs to each batch proportionally based on TOTAL batch value
  FOR v_batch_record IN 
    SELECT 
      id, 
      import_price, 
      import_price_per_unit, 
      import_quantity, 
      duty_charges, 
      freight_charges, 
      other_charges,
      (import_price * import_quantity) as batch_total_value
    FROM batches
    WHERE import_container_id = p_container_id
  LOOP
    -- This batch's total value
    v_batch_total_value := v_batch_record.batch_total_value;
    
    -- Calculate this batch's proportion of total value
    v_batch_percentage := (v_batch_total_value / v_total_batch_value);
    
    -- Allocate costs proportionally (TOTAL allocated cost for this batch)
    v_allocated_cost := v_total_container_costs * v_batch_percentage;
    
    -- Calculate per-unit allocated cost
    v_allocated_per_unit := v_allocated_cost / NULLIF(v_batch_record.import_quantity, 0);
    
    -- Landed cost per unit = import_price_per_unit + (batch charges / qty) + (allocated / qty)
    v_landed_cost_per_unit := v_batch_record.import_price + 
                             (v_batch_record.duty_charges / NULLIF(v_batch_record.import_quantity, 0)) +
                             (v_batch_record.freight_charges / NULLIF(v_batch_record.import_quantity, 0)) +
                             (v_batch_record.other_charges / NULLIF(v_batch_record.import_quantity, 0)) +
                             v_allocated_per_unit;
    
    -- Final TOTAL landed cost = (import_price + batch charges) × qty + allocated container costs
    v_final_total_cost := (v_batch_record.import_price + 
                          (v_batch_record.duty_charges / NULLIF(v_batch_record.import_quantity, 0)) + 
                          (v_batch_record.freight_charges / NULLIF(v_batch_record.import_quantity, 0)) + 
                          (v_batch_record.other_charges / NULLIF(v_batch_record.import_quantity, 0))) * 
                          v_batch_record.import_quantity + 
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

COMMENT ON FUNCTION reallocate_container_costs IS 'Allocates container costs proportionally by TOTAL batch value (import_price × quantity)';

-- Trigger reallocation for 20FCL Nov25
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
