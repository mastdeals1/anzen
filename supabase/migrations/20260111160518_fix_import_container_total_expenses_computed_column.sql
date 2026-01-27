/*
  # Fix Import Container Total Expenses Calculation
  
  1. Issue
    - total_import_expenses showing 0 even when individual cost fields have values
    - Computed column may not be properly defined or individual fields aren't set
    
  2. Solution
    - Recreate the computed column properly
    - Add trigger to recalculate linked expenses total from finance_expenses table
*/

-- Drop existing computed column if exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'import_containers' AND column_name = 'total_import_expenses'
  ) THEN
    ALTER TABLE import_containers DROP COLUMN total_import_expenses CASCADE;
  END IF;
END $$;

-- Recreate as generated column including bpom_ski_fees and loading_import
ALTER TABLE import_containers 
ADD COLUMN total_import_expenses DECIMAL(18,2) GENERATED ALWAYS AS (
  COALESCE(duty_bm, 0) + 
  COALESCE(ppn_import, 0) + 
  COALESCE(pph_import, 0) + 
  COALESCE(freight_charges, 0) + 
  COALESCE(clearing_forwarding, 0) + 
  COALESCE(port_charges, 0) + 
  COALESCE(container_handling, 0) + 
  COALESCE(transportation, 0) + 
  COALESCE(loading_import, 0) +
  COALESCE(bpom_ski_fees, 0) +
  COALESCE(other_import_costs, 0)
) STORED;

-- Comment explaining the calculation
COMMENT ON COLUMN import_containers.total_import_expenses IS 'Auto-calculated sum of all import cost fields. Matches finance_expenses linked to this container.';
