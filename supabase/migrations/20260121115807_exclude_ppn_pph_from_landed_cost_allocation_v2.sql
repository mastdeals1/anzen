/*
  # Exclude PPN and PPh Import from Landed Cost Allocation
  
  ## Problem
  PPN Input and PPh Import were being included in the landed cost allocation
  to batches, inflating the product COGS artificially.
  
  ## Reasoning
  1. **PPN Import (Input Tax)** - This is RECOVERABLE input tax
     - Can be offset against PPN Keluaran (Output Tax)
     - Should NOT be part of product cost
     - Should be recorded in "PPN Masukan" (Input VAT) account
  
  2. **PPh Import (Withholding Tax)** - This is withholding tax on imports
     - Tax is withheld at source
     - Should NOT be part of product cost
     - Should be recorded separately for tax filing purposes
  
  ## Solution
  Remove PPN and PPh from:
  1. total_import_expenses computed column (used for display/reporting)
  2. allocate_import_costs_to_batches() function (used for cost allocation)
  
  These will still be tracked in finance_expenses for tax reporting,
  but will NOT inflate product costs or COGS.
*/

-- =====================================================
-- 1. FIX COMPUTED COLUMN - Exclude PPN and PPh
-- =====================================================

-- Drop existing computed column
ALTER TABLE import_containers DROP COLUMN IF EXISTS total_import_expenses CASCADE;

-- Recreate WITHOUT ppn_import and pph_import
ALTER TABLE import_containers 
ADD COLUMN total_import_expenses DECIMAL(18,2) GENERATED ALWAYS AS (
  COALESCE(duty_bm, 0) + 
  COALESCE(freight_charges, 0) + 
  COALESCE(clearing_forwarding, 0) + 
  COALESCE(port_charges, 0) + 
  COALESCE(container_handling, 0) + 
  COALESCE(transportation, 0) + 
  COALESCE(loading_import, 0) +
  COALESCE(bpom_ski_fees, 0) +
  COALESCE(other_import_costs, 0)
) STORED;

COMMENT ON COLUMN import_containers.total_import_expenses IS 'Auto-calculated sum of import costs that become part of inventory landed cost. EXCLUDES PPN (recoverable input tax) and PPh (withholding tax).';

-- =====================================================
-- 2. FIX ALLOCATION FUNCTION - Exclude PPN and PPh
-- =====================================================

CREATE OR REPLACE FUNCTION allocate_import_costs_to_batches(
  p_container_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_container RECORD;
  v_batch RECORD;
  v_total_invoice_value DECIMAL(18,2);
  v_total_import_cost DECIMAL(18,2);
  v_allocation_percentage DECIMAL(10,6);
  v_allocated_cost DECIMAL(18,2);
  v_batches_allocated INTEGER := 0;
BEGIN
  -- Get container details
  SELECT * INTO v_container
  FROM import_containers
  WHERE id = p_container_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Container not found');
  END IF;

  IF v_container.status != 'draft' THEN
    RETURN json_build_object('success', false, 'error', 'Container already allocated or locked');
  END IF;

  -- Calculate total import cost from individual components
  -- ONLY costs that become part of inventory COGS
  -- EXCLUDING PPN (recoverable) and PPh (withholding tax)
  v_total_import_cost := 
    COALESCE(v_container.duty_bm, 0) + 
    COALESCE(v_container.freight_charges, 0) + 
    COALESCE(v_container.clearing_forwarding, 0) + 
    COALESCE(v_container.port_charges, 0) + 
    COALESCE(v_container.container_handling, 0) + 
    COALESCE(v_container.transportation, 0) + 
    COALESCE(v_container.other_import_costs, 0);

  IF v_total_import_cost = 0 THEN
    RETURN json_build_object('success', false, 'error', 'No import costs to allocate');
  END IF;

  -- Calculate total invoice value for this container batches
  SELECT COALESCE(SUM(import_price * import_quantity), 0) INTO v_total_invoice_value
  FROM batches
  WHERE import_container_id = p_container_id;

  IF v_total_invoice_value = 0 THEN
    RETURN json_build_object('success', false, 'error', 'No batches linked to this container');
  END IF;

  -- Allocate costs to each batch
  FOR v_batch IN
    SELECT id, import_price, import_quantity, (import_price * import_quantity) as batch_invoice_value
    FROM batches
    WHERE import_container_id = p_container_id
      AND COALESCE(cost_locked, false) = false
  LOOP
    -- Calculate allocation percentage and cost
    v_allocation_percentage := (v_batch.batch_invoice_value / v_total_invoice_value) * 100;
    v_allocated_cost := (v_total_import_cost * v_batch.batch_invoice_value) / v_total_invoice_value;

    -- Create or update allocation record
    INSERT INTO import_container_allocations (
      container_id,
      batch_id,
      batch_invoice_value,
      allocation_percentage,
      allocated_cost,
      allocated_by
    ) VALUES (
      p_container_id,
      v_batch.id,
      v_batch.batch_invoice_value,
      v_allocation_percentage,
      v_allocated_cost,
      auth.uid()
    )
    ON CONFLICT (container_id, batch_id) 
    DO UPDATE SET 
      allocation_percentage = EXCLUDED.allocation_percentage,
      allocated_cost = EXCLUDED.allocated_cost;

    -- Update batch with allocated cost
    UPDATE batches
    SET import_cost_allocated = v_allocated_cost,
        final_landed_cost = import_price + v_allocated_cost,
        cost_locked = true
    WHERE id = v_batch.id;

    v_batches_allocated := v_batches_allocated + 1;
  END LOOP;

  -- Update container status
  UPDATE import_containers
  SET status = 'allocated',
      locked_at = now(),
      locked_by = auth.uid(),
      allocated_expenses = v_total_import_cost
  WHERE id = p_container_id;

  RETURN json_build_object(
    'success', true,
    'batches_allocated', v_batches_allocated,
    'total_cost', v_total_import_cost,
    'note', 'PPN and PPh excluded from cost allocation'
  );
END;
$$;

-- =====================================================
-- 3. ADD EXPLANATORY COMMENTS
-- =====================================================

COMMENT ON COLUMN import_containers.ppn_import IS 'PPN Import (Input Tax 11%) - Recorded separately for tax reporting. NOT included in inventory landed cost as it is RECOVERABLE against PPN Keluaran.';

COMMENT ON COLUMN import_containers.pph_import IS 'PPh Import (Withholding Tax 2.5% or 7.5%) - Recorded separately for tax reporting. NOT included in inventory landed cost.';

COMMENT ON COLUMN import_containers.duty_bm IS 'Import Duty (BM) - Allocated to batches as part of landed cost. Becomes COGS when inventory is sold.';

-- =====================================================
-- 4. SUCCESS MESSAGE
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '================================================';
  RAISE NOTICE 'PPN and PPh EXCLUDED from landed cost allocation';
  RAISE NOTICE '================================================';
  RAISE NOTICE ' ';
  RAISE NOTICE 'PPN: Recoverable input tax - NOT part of product cost';
  RAISE NOTICE 'PPh: Withholding tax - NOT part of product cost';
  RAISE NOTICE 'Both still tracked in finance_expenses for tax reporting';
  RAISE NOTICE ' ';
  RAISE NOTICE 'Updated: total_import_expenses computed column';
  RAISE NOTICE 'Updated: allocate_import_costs_to_batches() function';
END $$;