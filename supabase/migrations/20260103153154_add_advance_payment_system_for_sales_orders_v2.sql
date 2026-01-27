/*
  # Complete Advance Payment System for Sales Orders
  
  ## Summary
  This migration adds full support for advance payments against Sales Orders, allowing businesses to:
  1. Receive advance payments and link them to Sales Orders
  2. Auto-apply advances when converting SO → Invoice
  3. Track partial/full advance payment status
  4. Real-time ledger updates
  
  ## New Features
  
  ### 1. Voucher Allocations Enhancement
  - Add `sales_order_id` column to support advance payments
  - Update CHECK constraint to allow Receipt → Sales Order linking
  - Add indexes for performance
  
  ### 2. Sales Order Payment Tracking
  - Add `advance_payment_amount` to track total advances received
  - Add `advance_payment_status` (none, partial, full)
  - Auto-calculate based on voucher allocations
  
  ### 3. Auto-Apply Advance to Invoice
  - When invoice created from SO with advance payments
  - Automatically transfer advance allocation to invoice
  - Update both SO and Invoice payment statuses
  
  ### 4. Views and Functions
  - Customer advance balance view
  - Sales Order advance tracking
  - Real-time ledger reflection
  
  ## Database Changes
  
  ### Modified Tables
  - `voucher_allocations`: Added sales_order_id
  - `sales_orders`: Added advance payment tracking fields
  
  ### New Functions
  - `apply_advance_to_invoice()`: Auto-transfers advance when invoice created
  - `update_so_advance_status()`: Updates SO advance payment status
  
  ### New Triggers
  - Auto-update SO advance status on voucher allocation changes
  - Auto-apply advances when invoice created from SO
*/

-- =====================================================
-- 1. ADD SALES ORDER SUPPORT TO VOUCHER ALLOCATIONS
-- =====================================================

-- Add sales_order_id column
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'voucher_allocations' AND column_name = 'sales_order_id'
  ) THEN
    ALTER TABLE voucher_allocations 
    ADD COLUMN sales_order_id UUID REFERENCES sales_orders(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_va_sales_order ON voucher_allocations(sales_order_id);

-- Drop old CHECK constraint
ALTER TABLE voucher_allocations 
DROP CONSTRAINT IF EXISTS voucher_allocations_check;

-- Add new CHECK constraint to support both invoice and sales order
ALTER TABLE voucher_allocations
ADD CONSTRAINT voucher_allocations_check CHECK (
  (voucher_type = 'receipt' AND receipt_voucher_id IS NOT NULL AND 
   (sales_invoice_id IS NOT NULL OR sales_order_id IS NOT NULL)) OR
  (voucher_type = 'payment' AND payment_voucher_id IS NOT NULL AND purchase_invoice_id IS NOT NULL)
);

-- =====================================================
-- 2. ADD ADVANCE PAYMENT TRACKING TO SALES ORDERS
-- =====================================================

-- Add advance payment fields to sales_orders
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales_orders' AND column_name = 'advance_payment_amount'
  ) THEN
    ALTER TABLE sales_orders
    ADD COLUMN advance_payment_amount DECIMAL(18,2) DEFAULT 0;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales_orders' AND column_name = 'advance_payment_status'
  ) THEN
    ALTER TABLE sales_orders
    ADD COLUMN advance_payment_status VARCHAR(20) DEFAULT 'none' 
      CHECK (advance_payment_status IN ('none', 'partial', 'full'));
  END IF;
END $$;

-- Update existing records
UPDATE sales_orders 
SET advance_payment_amount = 0, 
    advance_payment_status = 'none'
WHERE advance_payment_amount IS NULL 
   OR advance_payment_status IS NULL;

-- =====================================================
-- 3. FUNCTION TO UPDATE SO ADVANCE STATUS
-- =====================================================

CREATE OR REPLACE FUNCTION update_so_advance_status()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_sales_order_id UUID;
  v_total_advance DECIMAL(18,2);
  v_order_total DECIMAL(18,2);
BEGIN
  -- Determine which sales_order_id to update
  IF TG_OP = 'DELETE' THEN
    v_sales_order_id := OLD.sales_order_id;
  ELSE
    v_sales_order_id := NEW.sales_order_id;
  END IF;

  -- Only process if sales_order_id exists
  IF v_sales_order_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Calculate total advance payments for this SO
  SELECT COALESCE(SUM(va.allocated_amount), 0)
  INTO v_total_advance
  FROM voucher_allocations va
  WHERE va.sales_order_id = v_sales_order_id
    AND va.voucher_type = 'receipt';

  -- Get SO total
  SELECT total_amount INTO v_order_total
  FROM sales_orders
  WHERE id = v_sales_order_id;

  -- Update SO with advance status
  UPDATE sales_orders
  SET 
    advance_payment_amount = v_total_advance,
    advance_payment_status = CASE
      WHEN v_total_advance = 0 THEN 'none'
      WHEN v_total_advance >= v_order_total THEN 'full'
      ELSE 'partial'
    END,
    updated_at = now()
  WHERE id = v_sales_order_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Create trigger on voucher_allocations
DROP TRIGGER IF EXISTS trg_update_so_advance ON voucher_allocations;

CREATE TRIGGER trg_update_so_advance
AFTER INSERT OR UPDATE OR DELETE ON voucher_allocations
FOR EACH ROW
EXECUTE FUNCTION update_so_advance_status();

-- =====================================================
-- 4. AUTO-APPLY ADVANCE WHEN INVOICE CREATED FROM SO
-- =====================================================

CREATE OR REPLACE FUNCTION apply_advance_to_invoice()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
  v_advance_allocations RECORD;
  v_total_advance DECIMAL(18,2) := 0;
  v_remaining_invoice_amount DECIMAL(18,2);
  v_amount_to_apply DECIMAL(18,2);
BEGIN
  -- Only process if invoice is linked to a sales order
  IF NEW.sales_order_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get all advance payments for this SO
  FOR v_advance_allocations IN
    SELECT va.id, va.receipt_voucher_id, va.allocated_amount
    FROM voucher_allocations va
    WHERE va.sales_order_id = NEW.sales_order_id
      AND va.voucher_type = 'receipt'
  LOOP
    -- Calculate how much of this advance to apply
    v_remaining_invoice_amount := NEW.total_amount - v_total_advance;
    
    IF v_remaining_invoice_amount <= 0 THEN
      EXIT; -- Invoice fully paid by advances
    END IF;

    v_amount_to_apply := LEAST(v_advance_allocations.allocated_amount, v_remaining_invoice_amount);

    -- Create new allocation linking receipt to invoice
    INSERT INTO voucher_allocations (
      voucher_type,
      receipt_voucher_id,
      sales_invoice_id,
      allocated_amount
    ) VALUES (
      'receipt',
      v_advance_allocations.receipt_voucher_id,
      NEW.id,
      v_amount_to_apply
    );

    -- Remove or reduce the SO allocation
    IF v_amount_to_apply >= v_advance_allocations.allocated_amount THEN
      -- Fully consumed, delete SO allocation
      DELETE FROM voucher_allocations WHERE id = v_advance_allocations.id;
    ELSE
      -- Partially consumed, reduce SO allocation
      UPDATE voucher_allocations
      SET allocated_amount = allocated_amount - v_amount_to_apply
      WHERE id = v_advance_allocations.id;
    END IF;

    v_total_advance := v_total_advance + v_amount_to_apply;
  END LOOP;

  -- Update invoice payment status if advances were applied
  IF v_total_advance > 0 THEN
    UPDATE sales_invoices
    SET 
      paid_amount = v_total_advance,
      balance_amount = total_amount - v_total_advance,
      payment_status = CASE
        WHEN v_total_advance >= total_amount THEN 'paid'
        ELSE 'partial'
      END,
      updated_at = now()
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

-- Create trigger on sales_invoices
DROP TRIGGER IF EXISTS trg_apply_advance_to_invoice ON sales_invoices;

CREATE TRIGGER trg_apply_advance_to_invoice
AFTER INSERT ON sales_invoices
FOR EACH ROW
EXECUTE FUNCTION apply_advance_to_invoice();

-- =====================================================
-- 5. VIEW: CUSTOMER ADVANCE BALANCES
-- =====================================================

CREATE OR REPLACE VIEW customer_advance_balances AS
SELECT 
  c.id as customer_id,
  c.company_name,
  COALESCE(SUM(va.allocated_amount), 0) as total_advances,
  COUNT(DISTINCT va.sales_order_id) as orders_with_advance
FROM customers c
LEFT JOIN sales_orders so ON so.customer_id = c.id
LEFT JOIN voucher_allocations va ON va.sales_order_id = so.id AND va.voucher_type = 'receipt'
WHERE va.sales_order_id IS NOT NULL
GROUP BY c.id, c.company_name;

GRANT SELECT ON customer_advance_balances TO authenticated;

-- =====================================================
-- 6. VIEW: SALES ORDER ADVANCE DETAILS
-- =====================================================

CREATE OR REPLACE VIEW sales_order_advance_details AS
SELECT 
  so.id as sales_order_id,
  so.so_number,
  so.customer_id,
  c.company_name,
  so.total_amount as order_total,
  so.advance_payment_amount,
  so.advance_payment_status,
  (so.total_amount - so.advance_payment_amount) as balance_due,
  ARRAY_AGG(
    jsonb_build_object(
      'voucher_id', rv.id,
      'voucher_number', rv.voucher_number,
      'voucher_date', rv.voucher_date,
      'amount', va.allocated_amount
    )
  ) FILTER (WHERE va.id IS NOT NULL) as advance_payments
FROM sales_orders so
JOIN customers c ON c.id = so.customer_id
LEFT JOIN voucher_allocations va ON va.sales_order_id = so.id AND va.voucher_type = 'receipt'
LEFT JOIN receipt_vouchers rv ON rv.id = va.receipt_voucher_id
WHERE so.advance_payment_amount > 0
GROUP BY so.id, so.so_number, so.customer_id, c.company_name, 
         so.total_amount, so.advance_payment_amount, so.advance_payment_status;

GRANT SELECT ON sales_order_advance_details TO authenticated;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '✅ Advance Payment System for Sales Orders Complete!';
  RAISE NOTICE '📝 Features Added:';
  RAISE NOTICE '   - Receipt Vouchers can link to Sales Orders (advance payments)';
  RAISE NOTICE '   - Sales Orders track advance_payment_amount and status';
  RAISE NOTICE '   - Auto-apply advances when Invoice created from SO';
  RAISE NOTICE '   - Real-time ledger updates via triggers';
  RAISE NOTICE '   - Customer advance balance views';
  RAISE NOTICE '';
  RAISE NOTICE '💡 Usage:';
  RAISE NOTICE '   1. Create Receipt Voucher → Link to Sales Order (advance)';
  RAISE NOTICE '   2. Create Invoice from SO → Advances auto-applied';
  RAISE NOTICE '   3. Check views: customer_advance_balances, sales_order_advance_details';
END $$;
