/*
  # Add Missing Foreign Key Indexes - Part 4

  ## Performance Issue
  - Continuing from Part 3
  - Part 4: Tables R-V (Final)
*/

-- receipt_vouchers
CREATE INDEX IF NOT EXISTS idx_receipt_vouchers_created_by ON receipt_vouchers(created_by);
CREATE INDEX IF NOT EXISTS idx_receipt_vouchers_journal_entry_id ON receipt_vouchers(journal_entry_id);

-- sales_invoices
CREATE INDEX IF NOT EXISTS idx_sales_invoices_created_by ON sales_invoices(created_by);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_customer_id ON sales_invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_journal_entry_id ON sales_invoices(journal_entry_id);

-- sales_orders
CREATE INDEX IF NOT EXISTS idx_sales_orders_approved_by ON sales_orders(approved_by);
CREATE INDEX IF NOT EXISTS idx_sales_orders_archived_by ON sales_orders(archived_by);
CREATE INDEX IF NOT EXISTS idx_sales_orders_created_by ON sales_orders(created_by);
CREATE INDEX IF NOT EXISTS idx_sales_orders_customer_id ON sales_orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_orders_rejected_by ON sales_orders(rejected_by);

-- stock_rejections
CREATE INDEX IF NOT EXISTS idx_stock_rejections_approval_workflow_id ON stock_rejections(approval_workflow_id);
CREATE INDEX IF NOT EXISTS idx_stock_rejections_approved_by ON stock_rejections(approved_by);
CREATE INDEX IF NOT EXISTS idx_stock_rejections_batch_id ON stock_rejections(batch_id);
CREATE INDEX IF NOT EXISTS idx_stock_rejections_created_by ON stock_rejections(created_by);
CREATE INDEX IF NOT EXISTS idx_stock_rejections_inspected_by ON stock_rejections(inspected_by);
CREATE INDEX IF NOT EXISTS idx_stock_rejections_product_id ON stock_rejections(product_id);

-- stock_reservations
CREATE INDEX IF NOT EXISTS idx_stock_reservations_released_by ON stock_reservations(released_by);
CREATE INDEX IF NOT EXISTS idx_stock_reservations_reserved_by ON stock_reservations(reserved_by);
CREATE INDEX IF NOT EXISTS idx_stock_reservations_sales_order_item_id ON stock_reservations(sales_order_item_id);

-- suppliers
CREATE INDEX IF NOT EXISTS idx_suppliers_created_by ON suppliers(created_by);

-- task_assignments
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by ON task_assignments(assigned_by);
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_user_id ON task_assignments(assigned_user_id);

-- task_comments
CREATE INDEX IF NOT EXISTS idx_task_comments_parent_comment_id ON task_comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_task_comments_task_id ON task_comments(task_id);
CREATE INDEX IF NOT EXISTS idx_task_comments_user_id ON task_comments(user_id);

-- task_status_history
CREATE INDEX IF NOT EXISTS idx_task_status_history_changed_by ON task_status_history(changed_by);
CREATE INDEX IF NOT EXISTS idx_task_status_history_task_id ON task_status_history(task_id);

-- tasks
CREATE INDEX IF NOT EXISTS idx_tasks_completed_by ON tasks(completed_by);
CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON tasks(created_by);
CREATE INDEX IF NOT EXISTS idx_tasks_customer_id ON tasks(customer_id);
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_by ON tasks(deleted_by);

-- tax_codes
CREATE INDEX IF NOT EXISTS idx_tax_codes_collection_account_id ON tax_codes(collection_account_id);
CREATE INDEX IF NOT EXISTS idx_tax_codes_payment_account_id ON tax_codes(payment_account_id);

-- vendor_bills
CREATE INDEX IF NOT EXISTS idx_vendor_bills_created_by ON vendor_bills(created_by);

-- vendor_payments
CREATE INDEX IF NOT EXISTS idx_vendor_payments_bank_account_id ON vendor_payments(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_bill_id ON vendor_payments(bill_id);
CREATE INDEX IF NOT EXISTS idx_vendor_payments_created_by ON vendor_payments(created_by);

-- voucher_allocations
CREATE INDEX IF NOT EXISTS idx_voucher_allocations_payment_voucher_id ON voucher_allocations(payment_voucher_id);
CREATE INDEX IF NOT EXISTS idx_voucher_allocations_purchase_invoice_id ON voucher_allocations(purchase_invoice_id);
CREATE INDEX IF NOT EXISTS idx_voucher_allocations_sales_order_id ON voucher_allocations(sales_order_id);

-- Add comment about completion
COMMENT ON INDEX idx_voucher_allocations_sales_order_id IS 'Part 4 of 4: All 186 missing foreign key indexes have been added for optimal query performance';
