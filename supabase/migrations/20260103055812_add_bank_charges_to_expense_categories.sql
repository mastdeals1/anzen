/*
  # Add bank_charges to expense categories

  1. Changes
    - Add 'bank_charges' to the finance_expenses expense_category constraint
    - This is needed for bank reconciliation transactions

  2. Security
    - Maintains existing RLS policies
    - No impact on existing data
*/

-- Drop and recreate the constraint with bank_charges added
ALTER TABLE finance_expenses
  DROP CONSTRAINT IF EXISTS finance_expenses_expense_category_check;

ALTER TABLE finance_expenses
  ADD CONSTRAINT finance_expenses_expense_category_check
  CHECK (expense_category IN (
    -- Import categories (require container)
    'duty_customs',
    'ppn_import',
    'pph_import',
    'freight_import',
    'clearing_forwarding',
    'port_charges',
    'container_handling',
    'transport_import',
    -- Sales categories (optional DC)
    'delivery_sales',
    'loading_sales',
    -- Admin categories (no linkage)
    'warehouse_rent',
    'utilities',
    'salary',
    'office_admin',
    'bank_charges',
    -- Legacy categories (keep for backward compatibility)
    'duty',
    'freight',
    'office',
    'other'
  ));
