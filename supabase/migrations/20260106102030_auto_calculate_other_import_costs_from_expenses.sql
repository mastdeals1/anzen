/*
  # Auto-Calculate Other Import Costs from Expenses

  1. New Function
    - `update_container_other_costs()` - Automatically sums all 'other_import' expenses
      linked to a container and updates the container's `other_import_costs` field
      
  2. Trigger
    - When expense with category 'other_import' is added/updated/deleted
    - Recalculates the total for that container
    - Updates the container's `other_import_costs` field
    - This triggers existing cost allocation to batches
    
  3. Purpose
    - Users can add misc import expenses and they automatically flow to container costs
    - No manual entry needed - it's dynamically calculated
    - All "Other" expenses are tracked and reflected in inventory costs
*/

-- Function to update container's other_import_costs from linked expenses
CREATE OR REPLACE FUNCTION update_container_other_costs()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_container_id uuid;
  v_total_other_costs numeric;
  v_is_other_import boolean := false;
BEGIN
  -- Check if this expense is 'other_import' category
  IF TG_OP = 'DELETE' THEN
    v_is_other_import := (OLD.expense_category = 'other_import');
    v_container_id := OLD.import_container_id;
  ELSIF TG_OP = 'UPDATE' THEN
    v_is_other_import := (NEW.expense_category = 'other_import' OR OLD.expense_category = 'other_import');
    v_container_id := NEW.import_container_id;
  ELSE -- INSERT
    v_is_other_import := (NEW.expense_category = 'other_import');
    v_container_id := NEW.import_container_id;
  END IF;
  
  -- Skip if not 'other_import' category
  IF NOT v_is_other_import THEN
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
  
  -- Calculate total of all 'other_import' expenses for this container
  IF v_container_id IS NOT NULL THEN
    SELECT COALESCE(SUM(amount), 0) 
    INTO v_total_other_costs
    FROM finance_expenses
    WHERE import_container_id = v_container_id
      AND expense_category = 'other_import';
    
    -- Update the container's other_import_costs field
    UPDATE import_containers
    SET other_import_costs = v_total_other_costs
    WHERE id = v_container_id;
  END IF;
  
  -- If updating and container changed, also update the old container
  IF TG_OP = 'UPDATE' AND OLD.import_container_id IS NOT NULL 
     AND (NEW.import_container_id IS NULL OR OLD.import_container_id != NEW.import_container_id) THEN
    SELECT COALESCE(SUM(amount), 0) 
    INTO v_total_other_costs
    FROM finance_expenses
    WHERE import_container_id = OLD.import_container_id
      AND expense_category = 'other_import';
      
    UPDATE import_containers
    SET other_import_costs = v_total_other_costs
    WHERE id = OLD.import_container_id;
  END IF;
  
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Trigger to auto-update container costs when 'other_import' expenses change
DROP TRIGGER IF EXISTS trigger_update_container_other_costs ON finance_expenses;
CREATE TRIGGER trigger_update_container_other_costs
  AFTER INSERT OR UPDATE OR DELETE ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_container_other_costs();

-- Recalculate other_import_costs for all existing containers based on existing expenses
UPDATE import_containers ic
SET other_import_costs = COALESCE((
  SELECT SUM(amount)
  FROM finance_expenses fe
  WHERE fe.import_container_id = ic.id
    AND fe.expense_category = 'other_import'
), 0);