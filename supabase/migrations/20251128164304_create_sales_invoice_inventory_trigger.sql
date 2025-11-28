/*
  # Sales Invoice Inventory Transaction Trigger

  ## Summary
  Creates a trigger to automatically generate inventory transactions when
  sales invoice items are inserted or deleted.

  ## Changes
  - Creates trigger function to handle sales invoice item changes
  - Creates AFTER INSERT and AFTER DELETE triggers on sales_invoice_items table
  - Ensures all sales reduce stock via inventory transactions

  ## Transaction Type
  - INSERT: Creates "sale" type transaction with negative quantity (stock going out)
  - DELETE: Reverses the transaction by creating positive quantity entry
*/

-- Function to handle sales invoice inventory transactions
CREATE OR REPLACE FUNCTION trg_sales_invoice_item_inventory()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_number text;
  v_user_id uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Get invoice number and user
    SELECT si.invoice_number, si.created_by
    INTO v_invoice_number, v_user_id
    FROM sales_invoices si
    WHERE si.id = NEW.invoice_id;
    
    -- Create inventory transaction for the sale
    INSERT INTO inventory_transactions (
      product_id,
      batch_id,
      transaction_type,
      quantity,
      transaction_date,
      reference_number,
      notes,
      created_by
    ) VALUES (
      NEW.product_id,
      NEW.batch_id,
      'sale',
      -NEW.quantity,  -- Negative because stock is going out
      (SELECT invoice_date FROM sales_invoices WHERE id = NEW.invoice_id),
      v_invoice_number,
      'Sale via invoice: ' || v_invoice_number,
      v_user_id
    );
    
    -- Update batch stock
    UPDATE batches
    SET current_stock = current_stock - NEW.quantity
    WHERE id = NEW.batch_id;
    
    RETURN NEW;
    
  ELSIF TG_OP = 'DELETE' THEN
    -- Get invoice number
    SELECT si.invoice_number
    INTO v_invoice_number
    FROM sales_invoices si
    WHERE si.id = OLD.invoice_id;
    
    -- Reverse the inventory transaction
    INSERT INTO inventory_transactions (
      product_id,
      batch_id,
      transaction_type,
      quantity,
      transaction_date,
      reference_number,
      notes,
      created_by
    ) VALUES (
      OLD.product_id,
      OLD.batch_id,
      'adjustment',
      OLD.quantity,  -- Positive to restore stock
      CURRENT_DATE,
      v_invoice_number,
      'Reversed sale from deleted invoice item',
      auth.uid()
    );
    
    -- Restore batch stock
    UPDATE batches
    SET current_stock = current_stock + OLD.quantity
    WHERE id = OLD.batch_id;
    
    RETURN OLD;
  END IF;
END;
$$;

-- Create trigger for INSERT
DROP TRIGGER IF EXISTS trigger_sales_invoice_item_insert ON sales_invoice_items;
CREATE TRIGGER trigger_sales_invoice_item_insert
  AFTER INSERT ON sales_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION trg_sales_invoice_item_inventory();

-- Create trigger for DELETE
DROP TRIGGER IF EXISTS trigger_sales_invoice_item_delete ON sales_invoice_items;
CREATE TRIGGER trigger_sales_invoice_item_delete
  AFTER DELETE ON sales_invoice_items
  FOR EACH ROW
  EXECUTE FUNCTION trg_sales_invoice_item_inventory();

COMMENT ON FUNCTION trg_sales_invoice_item_inventory IS 'Automatically creates inventory transactions and updates stock when sales invoice items are added or removed';

-- Backfill: Create missing inventory transactions for existing invoices
DO $$
DECLARE
  v_item RECORD;
  v_invoice_number text;
  v_user_id uuid;
  v_invoice_date date;
BEGIN
  FOR v_item IN
    SELECT sii.*, si.invoice_number, si.created_by, si.invoice_date
    FROM sales_invoice_items sii
    JOIN sales_invoices si ON sii.invoice_id = si.id
    WHERE NOT EXISTS (
      SELECT 1 FROM inventory_transactions it
      WHERE it.reference_number = si.invoice_number
      AND it.product_id = sii.product_id
      AND it.batch_id = sii.batch_id
      AND it.transaction_type = 'sale'
    )
  LOOP
    -- Create the missing transaction
    INSERT INTO inventory_transactions (
      product_id,
      batch_id,
      transaction_type,
      quantity,
      transaction_date,
      reference_number,
      notes,
      created_by
    ) VALUES (
      v_item.product_id,
      v_item.batch_id,
      'sale',
      -v_item.quantity,
      v_item.invoice_date,
      v_item.invoice_number,
      'Backfilled: Sale via invoice ' || v_item.invoice_number,
      v_item.created_by
    );
  END LOOP;
END $$;
