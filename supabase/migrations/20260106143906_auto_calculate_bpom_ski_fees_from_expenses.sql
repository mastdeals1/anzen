/*
  # Auto-Calculate BPOM/SKI Fees from Expenses

  1. New Function
    - `update_container_bpom_fees()` - Automatically sums all 'bpom_ski_fees' expenses
      linked to a container and updates the container's `bpom_ski_fees` field
      
  2. Trigger
    - When expense with category 'bpom_ski_fees' is added/updated/deleted
    - Recalculates the total for that container
    - Updates the container's `bpom_ski_fees` field
    - This triggers existing cost allocation to batches
    
  3. Purpose
    - Users can add BPOM/SKI regulatory fees and they automatically flow to container costs
    - No manual entry needed - it's dynamically calculated
    - All BPOM/SKI expenses are tracked and reflected in inventory costs
*/

-- Function to update container's bpom_ski_fees from linked expenses
CREATE OR REPLACE FUNCTION update_container_bpom_fees()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_container_id uuid;
  v_total_bpom_fees numeric;
  v_is_bpom_fees boolean := false;
BEGIN
  -- Check if this expense is 'bpom_ski_fees' category
  IF TG_OP = 'DELETE' THEN
    v_is_bpom_fees := (OLD.expense_category = 'bpom_ski_fees');
    v_container_id := OLD.import_container_id;
  ELSIF TG_OP = 'UPDATE' THEN
    v_is_bpom_fees := (NEW.expense_category = 'bpom_ski_fees' OR OLD.expense_category = 'bpom_ski_fees');
    v_container_id := NEW.import_container_id;
  ELSE -- INSERT
    v_is_bpom_fees := (NEW.expense_category = 'bpom_ski_fees');
    v_container_id := NEW.import_container_id;
  END IF;
  
  -- Skip if not 'bpom_ski_fees' category
  IF NOT v_is_bpom_fees THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    ELSE
      RETURN NEW;
    END IF;
  END IF;
  
  -- Skip if no container linked
  IF v_container_id IS NULL AND (TG_OP != 'UPDATE' OR OLD.import_container_id IS NULL) THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    ELSE
      RETURN NEW;
    END IF;
  END IF;
  
  -- Calculate total of all 'bpom_ski_fees' expenses for this container
  IF v_container_id IS NOT NULL THEN
    SELECT COALESCE(SUM(amount), 0) 
    INTO v_total_bpom_fees
    FROM finance_expenses
    WHERE import_container_id = v_container_id
      AND expense_category = 'bpom_ski_fees';
    
    -- Update the container's bpom_ski_fees field
    UPDATE import_containers
    SET bpom_ski_fees = v_total_bpom_fees
    WHERE id = v_container_id;
  END IF;
  
  -- If updating and container changed, also update the old container
  IF TG_OP = 'UPDATE' AND OLD.import_container_id IS NOT NULL 
     AND (NEW.import_container_id IS NULL OR OLD.import_container_id != NEW.import_container_id) THEN
    SELECT COALESCE(SUM(amount), 0) 
    INTO v_total_bpom_fees
    FROM finance_expenses
    WHERE import_container_id = OLD.import_container_id
      AND expense_category = 'bpom_ski_fees';
      
    UPDATE import_containers
    SET bpom_ski_fees = v_total_bpom_fees
    WHERE id = OLD.import_container_id;
  END IF;
  
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Trigger to auto-update container BPOM fees when 'bpom_ski_fees' expenses change
DROP TRIGGER IF EXISTS trigger_update_container_bpom_fees ON finance_expenses;
CREATE TRIGGER trigger_update_container_bpom_fees
  AFTER INSERT OR UPDATE OR DELETE ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_container_bpom_fees();

-- Recalculate bpom_ski_fees for all existing containers based on existing expenses
UPDATE import_containers ic
SET bpom_ski_fees = COALESCE((
  SELECT SUM(amount)
  FROM finance_expenses fe
  WHERE fe.import_container_id = ic.id
    AND fe.expense_category = 'bpom_ski_fees'
), 0);