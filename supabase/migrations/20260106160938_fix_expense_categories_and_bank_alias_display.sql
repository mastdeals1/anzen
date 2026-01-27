/*
  # Fix Missing 'bpom_ski_fees' Category and Update Trigger

  1. Problem
    - Frontend has 'bpom_ski_fees' expense category
    - Database check constraint is missing 'bpom_ski_fees'
    - This causes "violates check constraint" errors when saving expenses

  2. Solution
    - Add 'bpom_ski_fees' to the expense_category CHECK constraint
    - Update validate_expense_context trigger to handle 'bpom_ski_fees' as import expense

  3. Security
    - Maintains existing RLS policies
*/

-- Drop old check constraint
ALTER TABLE finance_expenses DROP CONSTRAINT IF EXISTS finance_expenses_expense_category_check;

-- Recreate with bpom_ski_fees included
ALTER TABLE finance_expenses ADD CONSTRAINT finance_expenses_expense_category_check 
CHECK (expense_category = ANY (ARRAY[
  'duty_customs'::text,
  'ppn_import'::text,
  'pph_import'::text,
  'freight_import'::text,
  'clearing_forwarding'::text,
  'port_charges'::text,
  'container_handling'::text,
  'transport_import'::text,
  'loading_import'::text,
  'bpom_ski_fees'::text,
  'other_import'::text,
  'delivery_sales'::text,
  'loading_sales'::text,
  'other_sales'::text,
  'salary'::text,
  'staff_overtime'::text,
  'staff_welfare'::text,
  'travel_conveyance'::text,
  'warehouse_rent'::text,
  'utilities'::text,
  'bank_charges'::text,
  'office_admin'::text,
  'office_shifting_renovation'::text,
  'duty'::text,
  'freight'::text,
  'office'::text,
  'other'::text
]));

-- Update validate_expense_context trigger to handle bpom_ski_fees
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
    -- Admin/General expenses
    NEW.expense_type := 'admin';
  END IF;

  RETURN NEW;
END;
$$;
