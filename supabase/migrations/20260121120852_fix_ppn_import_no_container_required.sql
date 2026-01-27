/*
  # Remove PPN Import from Import Categories - No Container Required
  
  1. Changes
    - Remove 'ppn_import' from list of categories that require import_container_id
    - PPN Import is now treated as a general expense (P&L, not capitalized)
    - Unlink all existing PPN Import expenses from containers
  
  2. Notes
    - PPN Import expenses will no longer require container linking
    - Existing PPN Import expenses will have their container links removed
*/

-- Step 1: Drop the trigger temporarily
DROP TRIGGER IF EXISTS set_expense_context ON finance_expenses;

-- Step 2: Update the validation function to exclude ppn_import
CREATE OR REPLACE FUNCTION validate_expense_context()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Determine expense type based on category
  IF NEW.expense_category IN (
    'duty_customs', 'pph_import', 'freight_import',
    'clearing_forwarding', 'port_charges', 'container_handling',
    'transport_import', 'loading_import', 'bpom_ski_fees', 'other_import',
    'duty', 'freight'
  ) THEN
    NEW.expense_type := 'import';
    
    -- ENFORCE: Import expenses MUST have import_container_id
    IF NEW.import_container_id IS NULL THEN
      RAISE EXCEPTION 'Import expenses must be linked to an Import Container. Please select a container.';
    END IF;
    
  ELSIF NEW.expense_category IN ('delivery_sales', 'loading_sales', 'other_sales') THEN
    NEW.expense_type := 'sales';
    
  ELSE
    -- Admin/General expenses (including ppn_import now)
    NEW.expense_type := 'general';
  END IF;
  
  RETURN NEW;
END;
$$;

-- Step 3: Recreate the trigger
CREATE TRIGGER set_expense_context
  BEFORE INSERT OR UPDATE ON finance_expenses
  FOR EACH ROW
  EXECUTE FUNCTION validate_expense_context();

-- Step 4: Unlink all existing PPN Import expenses from containers
UPDATE finance_expenses
SET 
  import_container_id = NULL,
  expense_type = 'general'
WHERE expense_category = 'ppn_import' AND import_container_id IS NOT NULL;
