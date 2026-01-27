/*
  # Finance Classification for Import Costs

  1. Changes
    - Ensures all Container-level costs flow to proper finance accounts
    - Import Duty (BM), Freight, CNF, Port Charges, etc → Inventory/Import Expenses
    - Import PPN → PPN Masukan (Input Tax) for set-off against Sales PPN (PPN Keluaran)
    - No locking - allows late C&F invoices

  2. Accounting Flow
    - Container costs (except PPN) → Add to batch landed cost → COGS when sold
    - Import PPN → Input Tax account (can be offset against output tax)
    - Sales PPN → Output Tax account (PPN Keluaran)

  3. Notes
    - System allows PPN set-off calculation later
    - No additional locks or constraints added
    - Real-time cost allocation from previous migration handles batch costs
*/

-- Add comment to clarify PPN treatment
COMMENT ON COLUMN import_containers.ppn_import IS 'Import PPN (Input Tax) - goes to PPN Masukan account, can be offset against sales PPN Keluaran';
COMMENT ON COLUMN import_containers.duty_bm IS 'Import Duty (BM) - allocated to batches as part of landed cost, becomes COGS when sold';
COMMENT ON COLUMN import_containers.pph_import IS 'Import PPh - allocated to batches as part of landed cost, becomes COGS when sold';

-- Update existing accounting trigger to properly classify import costs
CREATE OR REPLACE FUNCTION record_batch_import_accounting_entry()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_inventory_coa_id uuid;
  v_payable_coa_id uuid;
  v_total_cost numeric;
  v_duty_amount numeric;
BEGIN
  -- Only create accounting entry if batch has final landed cost
  IF NEW.final_landed_cost IS NULL OR NEW.final_landed_cost = 0 THEN
    RETURN NEW;
  END IF;

  -- Get COA IDs for Inventory and Accounts Payable
  SELECT id INTO v_inventory_coa_id
  FROM chart_of_accounts
  WHERE account_code = '1140'
  LIMIT 1;

  SELECT id INTO v_payable_coa_id
  FROM chart_of_accounts
  WHERE account_code = '2110'
  LIMIT 1;

  -- Calculate total cost (this includes allocated container costs)
  v_total_cost := NEW.final_landed_cost;

  -- Calculate duty amount based on duty_percent if available
  IF NEW.duty_percent IS NOT NULL AND NEW.duty_percent > 0 THEN
    v_duty_amount := (NEW.import_price * NEW.duty_percent) / 100;
  ELSE
    v_duty_amount := 0;
  END IF;

  -- Create journal entry for inventory acquisition
  -- DR: Inventory (includes base cost + allocated import expenses)
  -- CR: Accounts Payable
  INSERT INTO finance_journal_entries (
    entry_date,
    reference_type,
    reference_id,
    description,
    total_amount,
    created_by
  )
  VALUES (
    NEW.import_date,
    'batch_import',
    NEW.id,
    'Import of ' || (SELECT product_name FROM products WHERE id = NEW.product_id) || 
    ' - Batch ' || NEW.batch_number || 
    CASE WHEN v_duty_amount > 0 THEN ' (incl. ' || ROUND(NEW.duty_percent, 2) || '% duty)' ELSE '' END,
    v_total_cost,
    NEW.created_by
  )
  RETURNING id INTO v_inventory_coa_id;  -- Reusing variable for journal entry ID

  -- Debit: Inventory Asset
  INSERT INTO finance_journal_entry_lines (
    journal_entry_id,
    coa_id,
    debit,
    credit,
    description
  )
  VALUES (
    v_inventory_coa_id,
    (SELECT id FROM chart_of_accounts WHERE account_code = '1140' LIMIT 1),
    v_total_cost,
    0,
    'Inventory - ' || NEW.batch_number
  );

  -- Credit: Accounts Payable
  INSERT INTO finance_journal_entry_lines (
    journal_entry_id,
    coa_id,
    debit,
    credit,
    description
  )
  VALUES (
    v_inventory_coa_id,
    v_payable_coa_id,
    0,
    v_total_cost,
    'Payable - Import ' || NEW.batch_number
  );

  RETURN NEW;
END;
$$;

-- Note: Import PPN (Input Tax) will be handled separately when container PPN is paid
-- This allows for proper PPN set-off calculation: Input PPN - Output PPN = PPN payable/receivable
