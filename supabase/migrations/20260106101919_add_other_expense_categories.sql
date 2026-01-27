/*
  # Add Other Expense Categories for Import and Sales

  1. Updates
    - Add 'other_import' to expense_category check constraint
    - Add 'other_sales' to expense_category check constraint
    
  2. Purpose
    - Allows users to record miscellaneous import costs that will be capitalized to inventory
    - Allows users to record miscellaneous sales/distribution costs
    - All "other_import" expenses are linked to containers and included in cost calculations
    - All expenses can now be paid by cash (will auto-create petty cash entries)
    
  3. Notes
    - Other Import expenses require container linkage (capitalized to inventory)
    - Other Sales expenses are P&L expenses (not capitalized)
*/

-- Drop existing check constraint
ALTER TABLE finance_expenses DROP CONSTRAINT IF EXISTS finance_expenses_expense_category_check;

-- Recreate with new categories
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