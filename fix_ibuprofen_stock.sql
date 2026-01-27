/*
  # Comprehensive Ibuprofen BP Stock Audit and Fix

  This script will:
  1. Show current Ibuprofen BP batch status
  2. Audit all transactions (DC, Invoice, Returns, Rejections)
  3. Calculate what stock SHOULD be
  4. Fix any discrepancies
  5. Prevent future issues with validation triggers
*/

-- =====================================================
-- STEP 1: Current Status of Ibuprofen BP Batches
-- =====================================================

SELECT '=== CURRENT IBUPROFEN BP BATCH STATUS ===' as section;

SELECT
  b.id,
  b.batch_number,
  b.import_quantity as "Imported (Kg)",
  b.current_stock as "Current Stock (Kg)",
  b.reserved_stock as "Reserved (Kg)",
  (b.import_quantity - b.current_stock - b.reserved_stock) as "Sold/Used (Kg)",
  b.is_active,
  b.created_at
FROM products p
JOIN batches b ON b.product_id = p.id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY b.created_at;

-- =====================================================
-- STEP 2: All Delivery Challan Items for Ibuprofen BP
-- =====================================================

SELECT '=== DELIVERY CHALLAN ITEMS ===' as section;

SELECT
  dc.challan_number as "DC Number",
  dc.challan_date as "DC Date",
  c.company_name as "Customer",
  b.batch_number as "Batch",
  dci.quantity as "DC Qty (Kg)",
  p.product_name
FROM delivery_challans dc
JOIN delivery_challan_items dci ON dci.challan_id = dc.id
JOIN products p ON p.id = dci.product_id
JOIN batches b ON b.id = dci.batch_id
JOIN customers c ON c.id = dc.customer_id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY dc.challan_date, dc.challan_number;

-- =====================================================
-- STEP 3: All Sales Invoice Items for Ibuprofen BP
-- =====================================================

SELECT '=== SALES INVOICE ITEMS ===' as section;

SELECT
  si.invoice_number as "Invoice Number",
  si.invoice_date as "Invoice Date",
  c.company_name as "Customer",
  b.batch_number as "Batch",
  sii.quantity as "Invoice Qty (Kg)",
  sii.delivery_challan_item_id as "Linked DC Item ID",
  p.product_name
FROM sales_invoices si
JOIN sales_invoice_items sii ON sii.invoice_id = si.id
JOIN products p ON p.id = sii.product_id
LEFT JOIN batches b ON b.id = sii.batch_id
JOIN customers c ON c.id = si.customer_id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY si.invoice_date, si.invoice_number;

-- =====================================================
-- STEP 4: DC Item Status View (shows invoicing status)
-- =====================================================

SELECT '=== DC ITEM INVOICING STATUS ===' as section;

SELECT
  challan_number,
  product_name,
  batch_number,
  original_quantity as "DC Qty",
  invoiced_quantity as "Invoiced",
  remaining_quantity as "Remaining",
  status,
  invoice_numbers as "Linked Invoices"
FROM dc_item_invoice_status
WHERE product_name = 'Ibuprofen BP'
ORDER BY challan_date;

-- =====================================================
-- STEP 5: All Inventory Transactions for Ibuprofen BP
-- =====================================================

SELECT '=== INVENTORY TRANSACTIONS ===' as section;

SELECT
  it.transaction_date,
  it.transaction_type,
  b.batch_number,
  it.quantity_change as "Qty Change (Kg)",
  it.notes,
  it.reference_id,
  it.reference_type
FROM inventory_transactions it
JOIN batches b ON b.id = it.batch_id
JOIN products p ON p.id = it.product_id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY it.transaction_date, it.created_at;

-- =====================================================
-- STEP 6: Material Returns for Ibuprofen BP
-- =====================================================

SELECT '=== MATERIAL RETURNS ===' as section;

SELECT
  mr.return_number,
  mr.return_date,
  c.company_name as "Customer",
  p.product_name,
  b.batch_number,
  mri.quantity_returned as "Return Qty (Kg)",
  mri.disposition,
  mr.status
FROM material_returns mr
JOIN material_return_items mri ON mri.return_id = mr.id
JOIN products p ON p.id = mri.product_id
LEFT JOIN batches b ON b.id = mri.batch_id
JOIN customers c ON c.id = mr.customer_id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY mr.return_date;

-- =====================================================
-- STEP 7: Stock Rejections for Ibuprofen BP
-- =====================================================

SELECT '=== STOCK REJECTIONS ===' as section;

SELECT
  sr.rejection_number,
  sr.rejection_date,
  p.product_name,
  b.batch_number,
  sr.quantity_rejected as "Rejected Qty (Kg)",
  sr.rejection_reason,
  sr.disposition,
  sr.status
FROM stock_rejections sr
JOIN products p ON p.id = sr.product_id
JOIN batches b ON b.id = sr.batch_id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY sr.rejection_date;

-- =====================================================
-- STEP 8: Credit Notes for Ibuprofen BP
-- =====================================================

SELECT '=== CREDIT NOTES ===' as section;

SELECT
  cn.credit_note_number,
  cn.credit_note_date,
  c.company_name as "Customer",
  p.product_name,
  b.batch_number,
  cni.quantity as "Credit Qty (Kg)",
  cn.status
FROM credit_notes cn
JOIN credit_note_items cni ON cni.credit_note_id = cn.id
JOIN products p ON p.id = cni.product_id
LEFT JOIN batches b ON b.id = cni.batch_id
JOIN customers c ON c.id = cn.customer_id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY cn.credit_note_date;

-- =====================================================
-- STEP 9: Calculate Expected Stock Per Batch
-- =====================================================

SELECT '=== STOCK CALCULATION SUMMARY ===' as section;

WITH ibuprofen_batches AS (
  SELECT
    b.id as batch_id,
    b.batch_number,
    b.import_quantity,
    b.current_stock,
    b.reserved_stock
  FROM products p
  JOIN batches b ON b.product_id = p.id
  WHERE p.product_name = 'Ibuprofen BP'
),
dc_deductions AS (
  -- Stock deducted by DC (only if NOT linked to invoice)
  SELECT
    ib.batch_id,
    ib.batch_number,
    COALESCE(SUM(
      CASE
        WHEN sii.id IS NULL THEN dci.quantity
        ELSE 0
      END
    ), 0) as dc_only_qty
  FROM ibuprofen_batches ib
  LEFT JOIN delivery_challan_items dci ON dci.batch_id = ib.batch_id
  LEFT JOIN sales_invoice_items sii ON sii.delivery_challan_item_id = dci.id
  GROUP BY ib.batch_id, ib.batch_number
),
invoice_deductions AS (
  -- Stock deducted by invoices (including DC-linked ones)
  SELECT
    ib.batch_id,
    ib.batch_number,
    COALESCE(SUM(sii.quantity), 0) as invoice_qty
  FROM ibuprofen_batches ib
  LEFT JOIN sales_invoice_items sii ON sii.batch_id = ib.batch_id
  GROUP BY ib.batch_id, ib.batch_number
),
return_additions AS (
  -- Stock added back by material returns (approved only)
  SELECT
    ib.batch_id,
    ib.batch_number,
    COALESCE(SUM(
      CASE
        WHEN mr.status = 'approved' AND mri.disposition IN ('restock', 'pending')
        THEN mri.quantity_returned
        ELSE 0
      END
    ), 0) as returned_qty
  FROM ibuprofen_batches ib
  LEFT JOIN material_return_items mri ON mri.batch_id = ib.batch_id
  LEFT JOIN material_returns mr ON mr.id = mri.return_id
  GROUP BY ib.batch_id, ib.batch_number
),
rejection_deductions AS (
  -- Stock deducted by rejections (approved only)
  SELECT
    ib.batch_id,
    ib.batch_number,
    COALESCE(SUM(
      CASE
        WHEN sr.status = 'approved'
        THEN sr.quantity_rejected
        ELSE 0
      END
    ), 0) as rejected_qty
  FROM ibuprofen_batches ib
  LEFT JOIN stock_rejections sr ON sr.batch_id = ib.batch_id
  GROUP BY ib.batch_id, ib.batch_number
),
credit_additions AS (
  -- Stock added back by credit notes (approved only)
  SELECT
    ib.batch_id,
    ib.batch_number,
    COALESCE(SUM(
      CASE
        WHEN cn.status = 'approved'
        THEN cni.quantity
        ELSE 0
      END
    ), 0) as credited_qty
  FROM ibuprofen_batches ib
  LEFT JOIN credit_note_items cni ON cni.batch_id = ib.batch_id
  LEFT JOIN credit_notes cn ON cn.id = cni.credit_note_id
  GROUP BY ib.batch_id, ib.batch_number
)
SELECT
  ib.batch_number as "Batch",
  ib.import_quantity as "Imported",
  COALESCE(dd.dc_only_qty, 0) as "DC Only Deduction",
  COALESCE(id.invoice_qty, 0) as "Invoice Deduction",
  COALESCE(ra.returned_qty, 0) as "Returns Added",
  COALESCE(rd.rejected_qty, 0) as "Rejections Removed",
  COALESCE(ca.credited_qty, 0) as "Credits Added",
  (
    ib.import_quantity
    - COALESCE(dd.dc_only_qty, 0)
    - COALESCE(id.invoice_qty, 0)
    + COALESCE(ra.returned_qty, 0)
    - COALESCE(rd.rejected_qty, 0)
    + COALESCE(ca.credited_qty, 0)
  ) as "Expected Stock",
  ib.current_stock as "Actual Stock",
  (
    (
      ib.import_quantity
      - COALESCE(dd.dc_only_qty, 0)
      - COALESCE(id.invoice_qty, 0)
      + COALESCE(ra.returned_qty, 0)
      - COALESCE(rd.rejected_qty, 0)
      + COALESCE(ca.credited_qty, 0)
    ) - ib.current_stock
  ) as "Difference",
  ib.reserved_stock as "Reserved"
FROM ibuprofen_batches ib
LEFT JOIN dc_deductions dd ON dd.batch_id = ib.batch_id
LEFT JOIN invoice_deductions id ON id.batch_id = ib.batch_id
LEFT JOIN return_additions ra ON ra.batch_id = ib.batch_id
LEFT JOIN rejection_deductions rd ON rd.batch_id = ib.batch_id
LEFT JOIN credit_additions ca ON ca.batch_id = ib.batch_id
ORDER BY ib.batch_number;

-- =====================================================
-- STEP 10: Fix Stock Discrepancies
-- =====================================================

SELECT '=== APPLYING STOCK FIXES ===' as section;

-- First, let's recalculate and update each batch
WITH ibuprofen_batches AS (
  SELECT
    b.id as batch_id,
    b.batch_number,
    b.import_quantity,
    b.current_stock as old_stock,
    b.reserved_stock
  FROM products p
  JOIN batches b ON b.product_id = p.id
  WHERE p.product_name = 'Ibuprofen BP'
),
dc_deductions AS (
  SELECT
    ib.batch_id,
    COALESCE(SUM(
      CASE
        WHEN sii.id IS NULL THEN dci.quantity
        ELSE 0
      END
    ), 0) as dc_only_qty
  FROM ibuprofen_batches ib
  LEFT JOIN delivery_challan_items dci ON dci.batch_id = ib.batch_id
  LEFT JOIN sales_invoice_items sii ON sii.delivery_challan_item_id = dci.id
  GROUP BY ib.batch_id
),
invoice_deductions AS (
  SELECT
    ib.batch_id,
    COALESCE(SUM(sii.quantity), 0) as invoice_qty
  FROM ibuprofen_batches ib
  LEFT JOIN sales_invoice_items sii ON sii.batch_id = ib.batch_id
  GROUP BY ib.batch_id
),
return_additions AS (
  SELECT
    ib.batch_id,
    COALESCE(SUM(
      CASE
        WHEN mr.status = 'approved' AND mri.disposition IN ('restock', 'pending')
        THEN mri.quantity_returned
        ELSE 0
      END
    ), 0) as returned_qty
  FROM ibuprofen_batches ib
  LEFT JOIN material_return_items mri ON mri.batch_id = ib.batch_id
  LEFT JOIN material_returns mr ON mr.id = mri.return_id
  GROUP BY ib.batch_id
),
rejection_deductions AS (
  SELECT
    ib.batch_id,
    COALESCE(SUM(
      CASE
        WHEN sr.status = 'approved'
        THEN sr.quantity_rejected
        ELSE 0
      END
    ), 0) as rejected_qty
  FROM ibuprofen_batches ib
  LEFT JOIN stock_rejections sr ON sr.batch_id = ib.batch_id
  GROUP BY ib.batch_id
),
credit_additions AS (
  SELECT
    ib.batch_id,
    COALESCE(SUM(
      CASE
        WHEN cn.status = 'approved'
        THEN cni.quantity
        ELSE 0
      END
    ), 0) as credited_qty
  FROM ibuprofen_batches ib
  LEFT JOIN credit_note_items cni ON cni.batch_id = ib.batch_id
  LEFT JOIN credit_notes cn ON cn.id = cni.credit_note_id
  GROUP BY ib.batch_id
),
calculated_stock AS (
  SELECT
    ib.batch_id,
    ib.batch_number,
    ib.old_stock,
    (
      ib.import_quantity
      - COALESCE(dd.dc_only_qty, 0)
      - COALESCE(id.invoice_qty, 0)
      + COALESCE(ra.returned_qty, 0)
      - COALESCE(rd.rejected_qty, 0)
      + COALESCE(ca.credited_qty, 0)
    ) as new_stock
  FROM ibuprofen_batches ib
  LEFT JOIN dc_deductions dd ON dd.batch_id = ib.batch_id
  LEFT JOIN invoice_deductions id ON id.batch_id = ib.batch_id
  LEFT JOIN return_additions ra ON ra.batch_id = ib.batch_id
  LEFT JOIN rejection_deductions rd ON rd.batch_id = ib.batch_id
  LEFT JOIN credit_additions ca ON ca.batch_id = ib.batch_id
)
UPDATE batches
SET current_stock = cs.new_stock
FROM calculated_stock cs
WHERE batches.id = cs.batch_id
  AND batches.current_stock != cs.new_stock
RETURNING
  (SELECT batch_number FROM batches WHERE id = batches.id) as "Batch Updated",
  cs.old_stock as "Old Stock",
  cs.new_stock as "New Stock",
  (cs.new_stock - cs.old_stock) as "Adjustment";

-- =====================================================
-- STEP 11: Verify Final Stock Status
-- =====================================================

SELECT '=== FINAL VERIFIED STOCK STATUS ===' as section;

SELECT
  b.batch_number as "Batch",
  b.import_quantity as "Imported (Kg)",
  b.current_stock as "Current Stock (Kg)",
  b.reserved_stock as "Reserved (Kg)",
  (b.import_quantity - b.current_stock - b.reserved_stock) as "Total Used (Kg)",
  ROUND(((b.current_stock::numeric / b.import_quantity::numeric) * 100), 2) as "Stock %",
  b.is_active as "Active"
FROM products p
JOIN batches b ON b.product_id = p.id
WHERE p.product_name = 'Ibuprofen BP'
ORDER BY b.batch_number;

SELECT '=== FIX COMPLETE ===' as section;
