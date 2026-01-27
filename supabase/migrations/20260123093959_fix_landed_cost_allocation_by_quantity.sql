/*
  # Fix Container Cost Allocation - Use Quantity Instead of Value

  1. Change
    - Current allocation uses TOTAL BATCH VALUE (import_price × quantity)
    - User wants allocation based on QUANTITY only

  2. New Allocation Formula
    - Sum all batches QUANTITY: Σ(quantity)
    - Container total expenses (excluding taxes)
    - Batch proportion: (batch_quantity / sum_quantities)
    - Allocated to batch: container_total × proportion
    - Per unit allocated: allocated / quantity
    - Landed cost per unit: import_price_per_unit + per_unit_charges + (allocated / qty)

  3. Auto-update triggers
    - When container costs change
    - When batch is added/removed from container
    - When batch quantity changes
*/

CREATE OR REPLACE FUNCTION reallocate_container_costs(p_container_id UUID)
RETURNS VOID
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_batch_record RECORD;
  v_total_quantity numeric := 0;
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

  -- Calculate TOTAL QUANTITY of all batches
  SELECT COALESCE(SUM(import_quantity), 0) INTO v_total_quantity
  FROM batches
  WHERE import_container_id = p_container_id;

  -- If no batches linked or no quantity, clear allocations
  IF v_total_quantity = 0 THEN
    UPDATE batches
    SET
      import_cost_allocated = 0,
      final_landed_cost = (import_price + duty_charges + freight_charges + other_charges) * import_quantity,
      landed_cost_per_unit = import_price + duty_charges + freight_charges + other_charges
    WHERE import_container_id = p_container_id;
    RETURN;
  END IF;

  -- Allocate costs to each batch proportionally based on QUANTITY
  FOR v_batch_record IN
    SELECT
      id,
      import_price,
      import_price_per_unit,
      import_quantity,
      duty_charges,
      freight_charges,
      other_charges
    FROM batches
    WHERE import_container_id = p_container_id
  LOOP
    -- Calculate this batch's proportion of total quantity
    v_batch_percentage := (v_batch_record.import_quantity / v_total_quantity);

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

COMMENT ON FUNCTION reallocate_container_costs IS 'Allocates container costs proportionally by QUANTITY (not value)';

-- Create trigger to auto-reallocate when container costs change
CREATE OR REPLACE FUNCTION trigger_reallocate_on_container_update()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only reallocate if cost-related fields change
  IF (OLD.total_import_expenses IS DISTINCT FROM NEW.total_import_expenses OR
      OLD.duty_bm IS DISTINCT FROM NEW.duty_bm OR
      OLD.ppn_import IS DISTINCT FROM NEW.ppn_import OR
      OLD.pph_import IS DISTINCT FROM NEW.pph_import OR
      OLD.freight_charges IS DISTINCT FROM NEW.freight_charges OR
      OLD.other_import_costs IS DISTINCT FROM NEW.other_import_costs OR
      OLD.bpom_fees IS DISTINCT FROM NEW.bpom_fees OR
      OLD.ski_fees IS DISTINCT FROM NEW.ski_fees) THEN
    PERFORM reallocate_container_costs(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_reallocate_container_costs ON import_containers;
CREATE TRIGGER auto_reallocate_container_costs
  AFTER UPDATE ON import_containers
  FOR EACH ROW
  EXECUTE FUNCTION trigger_reallocate_on_container_update();

-- Create trigger to auto-reallocate when batch container link changes
CREATE OR REPLACE FUNCTION trigger_reallocate_on_batch_container_change()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  -- If container link added/changed
  IF NEW.import_container_id IS NOT NULL AND (OLD.import_container_id IS NULL OR OLD.import_container_id != NEW.import_container_id) THEN
    PERFORM reallocate_container_costs(NEW.import_container_id);
  END IF;

  -- If container link removed
  IF OLD.import_container_id IS NOT NULL AND (NEW.import_container_id IS NULL OR OLD.import_container_id != NEW.import_container_id) THEN
    PERFORM reallocate_container_costs(OLD.import_container_id);
  END IF;

  -- If quantity changed and has container
  IF NEW.import_container_id IS NOT NULL AND OLD.import_quantity != NEW.import_quantity THEN
    PERFORM reallocate_container_costs(NEW.import_container_id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_reallocate_on_batch_change ON batches;
CREATE TRIGGER auto_reallocate_on_batch_change
  AFTER INSERT OR UPDATE ON batches
  FOR EACH ROW
  EXECUTE FUNCTION trigger_reallocate_on_batch_container_change();

-- Create trigger to reallocate when batch is deleted
CREATE OR REPLACE FUNCTION trigger_reallocate_on_batch_delete()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.import_container_id IS NOT NULL THEN
    PERFORM reallocate_container_costs(OLD.import_container_id);
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS auto_reallocate_on_batch_delete ON batches;
CREATE TRIGGER auto_reallocate_on_batch_delete
  AFTER DELETE ON batches
  FOR EACH ROW
  EXECUTE FUNCTION trigger_reallocate_on_batch_delete();

-- Recalculate all existing containers
DO $$
DECLARE
  v_container_id UUID;
BEGIN
  FOR v_container_id IN SELECT id FROM import_containers LOOP
    PERFORM reallocate_container_costs(v_container_id);
  END LOOP;
END $$;
