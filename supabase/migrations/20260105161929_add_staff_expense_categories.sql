/*
  # Add Staff-Related Expense Categories

  1. Changes
    - Add 'staff_overtime' to expense categories (Staff Overtime P&L expense)
    - Add 'staff_welfare' to expense categories (Staff Welfare / Allowances P&L expense)
    - Add 'travel_conveyance' to expense categories (Travel & Conveyance P&L expense)
    - Add 'loading_import' to expense categories (missing from previous migrations)

  2. Security
    - Maintains existing RLS policies
    - No impact on existing data
    - All new categories are P&L expenses (not capitalized to inventory)
*/

-- Drop and recreate the constraint with new staff categories added
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
    -- Legacy categories (keep for backward compatibility)
    'duty',
    'freight',
    'office',
    'other'
  ));