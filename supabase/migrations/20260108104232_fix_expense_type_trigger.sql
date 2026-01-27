/*
  # Fix expense type trigger to use 'general' instead of 'admin'
  
  1. Updates
    - Modify validate_expense_context trigger function to set expense_type = 'general' instead of 'admin'
    - This aligns with the check constraint that expects 'import', 'sales', 'general'
*/

CREATE OR REPLACE FUNCTION validate_expense_context()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Determine expense type based on category
  IF NEW.expense_category IN (
    'duty_customs', 'ppn_import', 'pph_import', 'freight_import',
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
    -- Admin/General expenses - use 'general' not 'admin'
    NEW.expense_type := 'general';
  END IF;
  
  RETURN NEW;
END;
$$;
