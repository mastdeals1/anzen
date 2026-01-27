/*
  # Enhance Petty Cash with Container and DC Links, Remove Expense Link
  
  1. Changes to petty_cash_transactions
    - Add import_container_id (link to import containers like expenses have)
    - Add delivery_challan_id (link to delivery challans like expenses have)
    - Add document_urls array (for document attachments)
    - Add voucher_number (for tracking)
    - Remove finance_expense_id (break bidirectional link to expenses)
  
  2. Purpose
    - Make petty cash standalone for cash expenses
    - Same linking capabilities as finance_expenses (container, DC)
    - Cash transactions tracked purely in petty cash
    - No dependency on expense tracker
  
  3. Security
    - Add foreign key constraints with proper indexes
    - Maintain existing RLS policies
*/

-- Add new columns to petty_cash_transactions
DO $$
BEGIN
  -- Add import_container_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'import_container_id'
  ) THEN
    ALTER TABLE petty_cash_transactions 
    ADD COLUMN import_container_id UUID REFERENCES import_containers(id) ON DELETE SET NULL;
  END IF;

  -- Add delivery_challan_id
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'delivery_challan_id'
  ) THEN
    ALTER TABLE petty_cash_transactions 
    ADD COLUMN delivery_challan_id UUID REFERENCES delivery_challans(id) ON DELETE SET NULL;
  END IF;

  -- Add document_urls array
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'document_urls'
  ) THEN
    ALTER TABLE petty_cash_transactions 
    ADD COLUMN document_urls TEXT[];
  END IF;

  -- Add voucher_number if doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'voucher_number'
  ) THEN
    ALTER TABLE petty_cash_transactions 
    ADD COLUMN voucher_number VARCHAR(50);
  END IF;
END $$;

-- Remove finance_expense_id column (break link to expense tracker)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'petty_cash_transactions' AND column_name = 'finance_expense_id'
  ) THEN
    ALTER TABLE petty_cash_transactions DROP COLUMN finance_expense_id;
  END IF;
END $$;

-- Create indexes for foreign keys (performance)
CREATE INDEX IF NOT EXISTS idx_petty_cash_import_container 
  ON petty_cash_transactions(import_container_id) 
  WHERE import_container_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_petty_cash_delivery_challan 
  ON petty_cash_transactions(delivery_challan_id) 
  WHERE delivery_challan_id IS NOT NULL;

-- Comment for clarity
COMMENT ON COLUMN petty_cash_transactions.import_container_id IS 'Links petty cash expense to import container for cost allocation';
COMMENT ON COLUMN petty_cash_transactions.delivery_challan_id IS 'Links petty cash expense to delivery challan';
COMMENT ON COLUMN petty_cash_transactions.document_urls IS 'Array of document URLs (receipts, invoices, photos)';
