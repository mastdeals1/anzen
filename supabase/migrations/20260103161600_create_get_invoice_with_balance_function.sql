/*
  # Create function to get invoices with calculated balance
  
  1. New Function
    - `get_invoices_with_balance(customer_uuid)` - Returns invoices with calculated paid_amount and balance_amount
    
  2. Purpose
    - Calculate paid_amount from invoice_payment_allocations + voucher_allocations
    - Calculate balance_amount = total_amount - paid_amount
    - Used by receipt voucher manager to show unpaid/partially paid invoices
*/

CREATE OR REPLACE FUNCTION get_invoices_with_balance(customer_uuid uuid)
RETURNS TABLE (
  id uuid,
  invoice_number text,
  invoice_date date,
  total_amount numeric,
  paid_amount numeric,
  balance_amount numeric
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    si.id,
    si.invoice_number,
    si.invoice_date,
    si.total_amount,
    COALESCE(
      (SELECT SUM(ipa.allocated_amount) 
       FROM invoice_payment_allocations ipa 
       WHERE ipa.invoice_id = si.id), 0
    ) + COALESCE(
      (SELECT SUM(va.allocated_amount) 
       FROM voucher_allocations va 
       WHERE va.sales_invoice_id = si.id), 0
    ) as paid_amount,
    si.total_amount - (
      COALESCE(
        (SELECT SUM(ipa.allocated_amount) 
         FROM invoice_payment_allocations ipa 
         WHERE ipa.invoice_id = si.id), 0
      ) + COALESCE(
        (SELECT SUM(va.allocated_amount) 
         FROM voucher_allocations va 
         WHERE va.sales_invoice_id = si.id), 0
      )
    ) as balance_amount
  FROM sales_invoices si
  WHERE si.customer_id = customer_uuid
  AND si.is_draft = false
  ORDER BY si.invoice_date;
END;
$$;
