/*
  # Add Office Shifting & Renovation Expense Category

  1. Changes
    - Add 'office_shifting_renovation' to expense categories
    - Covers: office shifting, partition work, electrical, cabling, interior renovation

  2. Security
    - Maintains existing RLS policies
    - No impact on existing data
    - This is a P&L expense (not capitalized to inventory)
*/

-- Drop and recreate the constraint with office_shifting_renovation added
ALTER TABLE finance_expenses
  DROP CONSTRAINT IF EXISTS finance_expenses_expense_category_check;

ALTER TABLE finance_expenses
  ADD CONSTRAINT finance_expenses_expense_category_check
  CHECK (expense_category IN (
    -- Import categories (require container) - CAPITALIZED to inventory
    'duty_customs',
    'ppn_import',
    'pph_import',
    'freight_import',
    'clearing_forwarding',
    'port_charges',
    'container_handling',
    'transport_import',
    'loading_import',
    -- Sales categories (optional DC) - P&L EXPENSE
    'delivery_sales',
    'loading_sales',
    -- Staff categories - P&L EXPENSE
    'salary',
    'staff_overtime',
    'staff_welfare',
    'travel_conveyance',
    -- Operations categories - P&L EXPENSE
    'warehouse_rent',
    'utilities',
    'bank_charges',
    -- Admin categories - P&L EXPENSE
    'office_admin',
    'office_shifting_renovation',
    -- Legacy categories (keep for backward compatibility)
    'duty',
    'freight',
    'office',
    'other'
  ));