/*
  # Fix Batch Accounting Trigger Column References
  
  1. Problem
    - Trigger function references non-existent columns
    - `quantity_purchased` should be `import_quantity`
    - `purchase_date` should be `import_date`
    - `cost_per_unit` exists but needs proper calculation
  
  2. Solution
    - Update trigger function to use correct column names
    - Calculate cost_per_unit if not provided
*/

CREATE OR REPLACE FUNCTION post_batch_purchase_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_je_id UUID;
  v_je_number TEXT;
  v_inventory_account_id UUID;
  v_ap_account_id UUID;
  v_ppn_account_id UUID;
  v_purchase_value DECIMAL(18,2);
  v_ppn_amount DECIMAL(18,2);
  v_total_amount DECIMAL(18,2);
  v_cost_per_unit DECIMAL(18,2);
BEGIN
  -- Only post on insert for batches with supplier
  IF TG_OP = 'INSERT' AND NEW.supplier_id IS NOT NULL THEN
    
    -- Calculate cost per unit if not provided
    v_cost_per_unit := COALESCE(NEW.cost_per_unit, 
                                 CASE WHEN NEW.import_quantity > 0 
                                      THEN NEW.import_price / NEW.import_quantity 
                                      ELSE 0 
                                 END);
    
    -- Calculate purchase value
    v_purchase_value := NEW.import_quantity * v_cost_per_unit;
    v_ppn_amount := v_purchase_value * 0.11; -- 11% PPN
    v_total_amount := v_purchase_value + v_ppn_amount;
    
    -- Skip if amount is zero
    IF v_total_amount <= 0 THEN
      RETURN NEW;
    END IF;
    
    -- Get account IDs
    SELECT id INTO v_inventory_account_id FROM chart_of_accounts WHERE code = '1130' LIMIT 1;
    SELECT id INTO v_ap_account_id FROM chart_of_accounts WHERE code = '2110' LIMIT 1;
    SELECT id INTO v_ppn_account_id FROM chart_of_accounts WHERE code = '1150' LIMIT 1;
    
    IF v_inventory_account_id IS NULL OR v_ap_account_id IS NULL THEN
      -- If accounts don't exist, skip accounting (don't fail the batch creation)
      RETURN NEW;
    END IF;
    
    -- Generate journal entry number
    v_je_number := 'JE' || TO_CHAR(CURRENT_DATE, 'YYMM') || '-' || LPAD((
      SELECT COUNT(*) + 1 FROM journal_entries WHERE entry_number LIKE 'JE' || TO_CHAR(CURRENT_DATE, 'YYMM') || '%'
    )::TEXT, 4, '0');
    
    -- Create journal entry
    INSERT INTO journal_entries (
      entry_number, 
      entry_date, 
      source_module, 
      reference_id, 
      reference_number,
      description, 
      total_debit, 
      total_credit, 
      is_posted, 
      posted_by
    ) VALUES (
      v_je_number, 
      NEW.import_date, 
      'batch_purchase', 
      NEW.id, 
      NEW.batch_number,
      'Goods Received - Batch: ' || NEW.batch_number,
      v_total_amount, 
      v_total_amount, 
      true, 
      NEW.created_by
    ) RETURNING id INTO v_je_id;
    
    -- Debit: Inventory (purchase value)
    INSERT INTO journal_entry_lines (
      journal_entry_id, 
      line_number, 
      account_id, 
      description, 
      debit, 
      credit, 
      supplier_id,
      batch_id
    ) VALUES (
      v_je_id, 
      1, 
      v_inventory_account_id, 
      'Inventory - Batch ' || NEW.batch_number, 
      v_purchase_value, 
      0, 
      NEW.supplier_id,
      NEW.id
    );
    
    -- Debit: PPN Input (if applicable)
    IF v_ppn_amount > 0 AND v_ppn_account_id IS NOT NULL THEN
      INSERT INTO journal_entry_lines (
        journal_entry_id, 
        line_number, 
        account_id, 
        description, 
        debit, 
        credit, 
        supplier_id,
        batch_id
      ) VALUES (
        v_je_id, 
        2, 
        v_ppn_account_id, 
        'PPN Input - Batch ' || NEW.batch_number, 
        v_ppn_amount, 
        0, 
        NEW.supplier_id,
        NEW.id
      );
    END IF;
    
    -- Credit: Accounts Payable (total amount)
    INSERT INTO journal_entry_lines (
      journal_entry_id, 
      line_number, 
      account_id, 
      description, 
      debit, 
      credit, 
      supplier_id,
      batch_id
    ) VALUES (
      v_je_id, 
      3, 
      v_ap_account_id, 
      'A/P - Batch ' || NEW.batch_number, 
      0, 
      v_total_amount, 
      NEW.supplier_id,
      NEW.id
    );
    
  END IF;
  
  RETURN NEW;
END;
$$;
