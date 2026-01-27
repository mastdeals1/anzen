/*
  # Fix Sales Invoice Atomic Update - Add Missing Fields

  1. Problem
    - RPC function update_sales_invoice_atomic missing fields: po_number, discount_amount, payment_terms_days
    - When editing invoice, these fields are not updated in database

  2. Solution
    - Add missing fields to UPDATE statement in RPC function

  3. Fields Added
    - po_number (text)
    - discount_amount (numeric)
    - payment_terms_days (integer)
*/

CREATE OR REPLACE FUNCTION update_sales_invoice_atomic(
  p_invoice_id UUID,
  p_invoice_updates JSONB,
  p_new_items JSONB[]
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
  v_result UUID;
BEGIN
  -- Step 1: Delete old items (triggers will restore stock automatically)
  DELETE FROM sales_invoice_items
  WHERE invoice_id = p_invoice_id;

  -- Step 2: Update invoice header (with all fields)
  UPDATE sales_invoices
  SET
    invoice_date = COALESCE((p_invoice_updates->>'invoice_date')::date, invoice_date),
    due_date = COALESCE((p_invoice_updates->>'due_date')::date, due_date),
    customer_id = COALESCE((p_invoice_updates->>'customer_id')::uuid, customer_id),
    subtotal = COALESCE((p_invoice_updates->>'subtotal')::numeric, subtotal),
    tax_amount = COALESCE((p_invoice_updates->>'tax_amount')::numeric, tax_amount),
    total_amount = COALESCE((p_invoice_updates->>'total_amount')::numeric, total_amount),
    discount_amount = COALESCE((p_invoice_updates->>'discount_amount')::numeric, discount_amount),
    po_number = COALESCE(p_invoice_updates->>'po_number', po_number),
    payment_terms_days = COALESCE((p_invoice_updates->>'payment_terms_days')::integer, payment_terms_days),
    notes = COALESCE(p_invoice_updates->>'notes', notes),
    payment_terms = COALESCE(p_invoice_updates->>'payment_terms', payment_terms),
    updated_at = NOW()
  WHERE id = p_invoice_id
  RETURNING id INTO v_result;

  -- Step 3: Insert new items (triggers will deduct stock automatically)
  INSERT INTO sales_invoice_items (
    invoice_id,
    product_id,
    batch_id,
    quantity,
    unit_price,
    tax_rate,
    total_amount,
    delivery_challan_item_id,
    max_quantity
  )
  SELECT
    p_invoice_id,
    (item->>'product_id')::uuid,
    (item->>'batch_id')::uuid,
    (item->>'quantity')::numeric,
    (item->>'unit_price')::numeric,
    (item->>'tax_rate')::numeric,
    (item->>'total_amount')::numeric,
    NULLIF(item->>'delivery_challan_item_id', '')::uuid,
    (item->>'max_quantity')::numeric
  FROM unnest(p_new_items) AS item;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION update_sales_invoice_atomic IS 'Atomically updates sales invoice and items in single transaction. Prevents race conditions during edit. Includes all invoice fields: po_number, discount_amount, payment_terms_days.';