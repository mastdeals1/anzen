/*
  # Add Duty % Auto-Fill and Real-Time Cost Allocation

  1. Changes to Batches Table
    - Add `duty_percent` column to store Form A1 duty %
    - Auto-fills from product.duty_percent on batch creation
    - Manual override allowed

  2. Real-Time Container Cost Allocation
    - When container costs change, all linked batches recalculate automatically
    - When batch is linked/unlinked from container, costs redistribute
    - No locking - allows late C&F invoices

  3. Finance Classification Preparation
    - Ensures proper cost tracking for accounting integration
*/

-- Add duty_percent column to batches
ALTER TABLE batches 
ADD COLUMN IF NOT EXISTS duty_percent numeric(5,2) DEFAULT 0 CHECK (duty_percent >= 0 AND duty_percent <= 100);

-- Create function to auto-fill duty % from product
CREATE OR REPLACE FUNCTION auto_fill_batch_duty_percent()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_product_duty_percent numeric(5,2);
BEGIN
  -- Get duty % from product if not manually set
  IF NEW.duty_percent IS NULL OR NEW.duty_percent = 0 THEN
    SELECT duty_percent INTO v_product_duty_percent
    FROM products
    WHERE id = NEW.product_id;
    
    NEW.duty_percent := COALESCE(v_product_duty_percent, 0);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to auto-fill duty % on batch insert/update
DROP TRIGGER IF EXISTS trigger_auto_fill_batch_duty_percent ON batches;
CREATE TRIGGER trigger_auto_fill_batch_duty_percent
  BEFORE INSERT OR UPDATE OF product_id ON batches
  FOR EACH ROW
  EXECUTE FUNCTION auto_fill_batch_duty_percent();

-- Create function to calculate and allocate container costs to batches in real-time
CREATE OR REPLACE FUNCTION allocate_container_costs_to_batches()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_batch_record RECORD;
  v_total_batch_value numeric := 0;
  v_batch_value numeric;
  v_batch_percentage numeric;
  v_total_container_costs numeric := 0;
  v_allocated_cost numeric;
BEGIN
  -- Calculate total container costs (excluding PPN as it's input tax)
  v_total_container_costs := 
    COALESCE(NEW.duty_bm, 0) + 
    COALESCE(NEW.freight_charges, 0) + 
    COALESCE(NEW.clearing_forwarding, 0) + 
    COALESCE(NEW.port_charges, 0) + 
    COALESCE(NEW.container_handling, 0) + 
    COALESCE(NEW.transportation, 0) + 
    COALESCE(NEW.other_import_costs, 0) +
    COALESCE(NEW.pph_import, 0);  -- PPh is also expense

  -- Calculate total value of all batches in this container
  SELECT COALESCE(SUM(import_price), 0) INTO v_total_batch_value
  FROM batches
  WHERE import_container_id = NEW.id;

  -- If no batches linked, nothing to allocate
  IF v_total_batch_value = 0 THEN
    RETURN NEW;
  END IF;

  -- Allocate costs to each batch proportionally
  FOR v_batch_record IN 
    SELECT id, import_price, import_quantity
    FROM batches
    WHERE import_container_id = NEW.id
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

  RETURN NEW;
END;
$$;

-- Trigger on container insert/update to reallocate costs
DROP TRIGGER IF EXISTS trigger_allocate_container_costs_on_change ON import_containers;
CREATE TRIGGER trigger_allocate_container_costs_on_change
  AFTER INSERT OR UPDATE OF 
    duty_bm, ppn_import, pph_import, freight_charges, 
    clearing_forwarding, port_charges, container_handling, 
    transportation, other_import_costs
  ON import_containers
  FOR EACH ROW
  EXECUTE FUNCTION allocate_container_costs_to_batches();

-- Function to trigger cost reallocation when batch is linked/unlinked to container
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
    PERFORM allocate_container_costs_to_batches() FROM import_containers WHERE id = OLD.import_container_id;
  END IF;

  -- Reallocate costs for NEW container
  IF NEW.import_container_id IS NOT NULL THEN
    PERFORM allocate_container_costs_to_batches() FROM import_containers WHERE id = NEW.import_container_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger on batch insert/update to reallocate when container link changes
DROP TRIGGER IF EXISTS trigger_reallocate_on_batch_container_change ON batches;
CREATE TRIGGER trigger_reallocate_on_batch_container_change
  AFTER INSERT OR UPDATE OF import_container_id, import_price
  ON batches
  FOR EACH ROW
  EXECUTE FUNCTION reallocate_on_batch_container_change();

COMMENT ON COLUMN batches.duty_percent IS 'Import duty % (Form A1) - auto-filled from product, manual override allowed';
COMMENT ON COLUMN batches.import_cost_allocated IS 'Proportional share of container costs allocated to this batch';
COMMENT ON COLUMN batches.final_landed_cost IS 'Total landed cost = import_price + import_cost_allocated';
