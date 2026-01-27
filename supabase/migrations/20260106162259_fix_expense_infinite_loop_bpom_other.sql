/*
  # Fix Infinite Loop - Stop Auto-Creating BPOM and Other Import Expenses

  ## Problem
  1. User creates expense with category 'bpom_ski_fees' or 'other_import'
  2. Trigger updates import_containers.bpom_ski_fees or other_import_costs
  3. auto_create_import_expenses() sees the change and creates ANOTHER expense
  4. Infinite loop → "stack depth limit exceeded" error

  ## Solution
  - Remove BPOM/SKI and Other Import from auto_create_import_expenses()
  - These categories are USER-ENTERED expenses, not auto-generated from container fields
  - The container fields (bpom_ski_fees, other_import_costs) are calculated FROM expenses,
    not the other way around

  ## Changes
  - Remove lines that create 'bpom_ski_fees' expenses
  - Remove lines that create 'other_import' expenses  
  - These are now ONLY created manually by users
*/

CREATE OR REPLACE FUNCTION auto_create_import_expenses()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expense_date DATE;
  v_created_by UUID;
BEGIN
  -- Use import date as expense date
  v_expense_date := NEW.import_date;
  v_created_by := COALESCE(NEW.created_by, auth.uid());

  -- Only process if this is a new record or cost fields changed
  -- NOTE: bpom_ski_fees and other_import_costs are EXCLUDED - they're calculated from expenses
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       OLD.duty_bm IS DISTINCT FROM NEW.duty_bm OR
       OLD.ppn_import IS DISTINCT FROM NEW.ppn_import OR
       OLD.pph_import IS DISTINCT FROM NEW.pph_import OR
       OLD.freight_charges IS DISTINCT FROM NEW.freight_charges OR
       OLD.clearing_forwarding IS DISTINCT FROM NEW.clearing_forwarding OR
       OLD.port_charges IS DISTINCT FROM NEW.port_charges OR
       OLD.container_handling IS DISTINCT FROM NEW.container_handling OR
       OLD.transportation IS DISTINCT FROM NEW.transportation OR
       OLD.loading_import IS DISTINCT FROM NEW.loading_import
     )) THEN

    -- Delete old expense entries for this container (if update)
    -- BUT ONLY delete expenses that are NOT linked to bank statements
    -- AND NOT user-created bpom_ski_fees or other_import
    IF TG_OP = 'UPDATE' THEN
      DELETE FROM finance_expenses fe
      WHERE fe.import_container_id = NEW.id
        AND fe.expense_category NOT IN ('bpom_ski_fees', 'other_import')
        -- Only delete if NOT referenced by bank_statement_lines
        AND NOT EXISTS (
          SELECT 1 
          FROM bank_statement_lines bsl 
          WHERE bsl.matched_expense_id = fe.id
        );
    END IF;

    -- Create expense entry for BM (Duty) - only if not already reconciled
    IF NEW.duty_bm > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'duty_customs'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'duty_customs',
        'import',
        NEW.duty_bm,
        v_expense_date,
        'BM (Duty) - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for PPN Import - only if not already reconciled
    IF NEW.ppn_import > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'ppn_import'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'ppn_import',
        'import',
        NEW.ppn_import,
        v_expense_date,
        'PPN Import (11%) - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for PPh Import - only if not already reconciled
    IF NEW.pph_import > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'pph_import'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'pph_import',
        'import',
        NEW.pph_import,
        v_expense_date,
        'PPh Import - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for Freight - only if not already reconciled
    IF NEW.freight_charges > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'freight_import'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'freight_import',
        'import',
        NEW.freight_charges,
        v_expense_date,
        'Freight Charges - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for Clearing & Forwarding - only if not already reconciled
    IF NEW.clearing_forwarding > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'clearing_forwarding'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'clearing_forwarding',
        'import',
        NEW.clearing_forwarding,
        v_expense_date,
        'Clearing & Forwarding - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for Port Charges - only if not already reconciled
    IF NEW.port_charges > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'port_charges'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'port_charges',
        'import',
        NEW.port_charges,
        v_expense_date,
        'Port Charges - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for Container Handling - only if not already reconciled
    IF NEW.container_handling > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'container_handling'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'container_handling',
        'import',
        NEW.container_handling,
        v_expense_date,
        'Container Handling - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for Transportation - only if not already reconciled
    IF NEW.transportation > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'transport_import'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'transport_import',
        'import',
        NEW.transportation,
        v_expense_date,
        'Transportation - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- Create expense entry for Loading/Unloading - only if not already reconciled
    IF NEW.loading_import > 0 AND NOT EXISTS (
      SELECT 1 FROM finance_expenses fe
      JOIN bank_statement_lines bsl ON bsl.matched_expense_id = fe.id
      WHERE fe.import_container_id = NEW.id 
        AND fe.expense_category = 'loading_import'
    ) THEN
      INSERT INTO finance_expenses (
        expense_category,
        expense_type,
        amount,
        expense_date,
        description,
        import_container_id,
        created_by
      ) VALUES (
        'loading_import',
        'import',
        NEW.loading_import,
        v_expense_date,
        'Loading/Unloading - Container ' || NEW.container_ref,
        NEW.id,
        v_created_by
      );
    END IF;

    -- NOTE: bpom_ski_fees and other_import expenses are NOT auto-created
    -- They are user-entered and the container fields are calculated FROM them

  END IF;

  RETURN NEW;
END;
$$;
