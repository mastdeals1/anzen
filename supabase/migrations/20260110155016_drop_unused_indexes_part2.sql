/*
  # Drop Unused Indexes - Part 2

  ## Changes
  - Continue dropping unused indexes
  - Focus on sales, inventory, and stock management indexes
*/

-- Sales Orders
DROP INDEX IF EXISTS idx_sales_orders_archived_at;
DROP INDEX IF EXISTS idx_sales_orders_archived;
DROP INDEX IF EXISTS idx_sales_orders_archived_by;
DROP INDEX IF EXISTS idx_sales_orders_rejected_by;
DROP INDEX IF EXISTS idx_sales_orders_customer_id;
DROP INDEX IF EXISTS idx_sales_orders_created_by;
DROP INDEX IF EXISTS idx_sales_orders_approved_by;
DROP INDEX IF EXISTS idx_sales_invoices_payment_status;
DROP INDEX IF EXISTS idx_sales_invoices_created_by;
DROP INDEX IF EXISTS idx_sales_invoices_journal_entry_id;
DROP INDEX IF EXISTS idx_sales_invoice_items_dc_item;

-- Stock and Inventory
DROP INDEX IF EXISTS idx_batches_reserved_stock;
DROP INDEX IF EXISTS idx_stock_reservations_released;
DROP INDEX IF EXISTS idx_stock_reservations_released_by;
DROP INDEX IF EXISTS idx_stock_reservations_reserved_by;
DROP INDEX IF EXISTS idx_stock_reservations_sales_order_item_id;
DROP INDEX IF EXISTS idx_inventory_transactions_created_by;

-- Products
DROP INDEX IF EXISTS idx_products_duty_percent;
DROP INDEX IF EXISTS idx_products_created_by;

-- Journal Entries
DROP INDEX IF EXISTS idx_jel_customer;
DROP INDEX IF EXISTS idx_jel_supplier;
DROP INDEX IF EXISTS idx_journal_entries_created_by;
DROP INDEX IF EXISTS idx_journal_entries_period_id;
DROP INDEX IF EXISTS idx_journal_entries_posted_by;
DROP INDEX IF EXISTS idx_journal_entry_lines_batch_id;
DROP INDEX IF EXISTS idx_journal_entry_lines_tax_code_id;

-- Petty Cash
DROP INDEX IF EXISTS idx_petty_cash_import_container;
DROP INDEX IF EXISTS idx_petty_cash_delivery_challan;
DROP INDEX IF EXISTS idx_petty_cash_transactions_created_by;
DROP INDEX IF EXISTS idx_petty_cash_transactions_paid_by_staff_id;
DROP INDEX IF EXISTS idx_petty_cash_transactions_received_by_staff_id;
DROP INDEX IF EXISTS idx_petty_cash_fund_transfer;
DROP INDEX IF EXISTS idx_petty_cash_books_bank_account;
DROP INDEX IF EXISTS idx_petty_cash_books_account_id;
DROP INDEX IF EXISTS idx_petty_cash_books_created_by;
DROP INDEX IF EXISTS idx_petty_cash_books_custodian_id;
DROP INDEX IF EXISTS idx_petty_cash_documents_uploaded_by;
DROP INDEX IF EXISTS idx_petty_cash_files_uploaded_by;
DROP INDEX IF EXISTS idx_pcf_voucher;

-- Petty Cash Vouchers
DROP INDEX IF EXISTS idx_petty_cash_vouchers_account_id;
DROP INDEX IF EXISTS idx_petty_cash_vouchers_approved_by;
DROP INDEX IF EXISTS idx_petty_cash_vouchers_created_by;
DROP INDEX IF EXISTS idx_petty_cash_vouchers_journal_entry_id;
DROP INDEX IF EXISTS idx_petty_cash_vouchers_tax_code_id;
DROP INDEX IF EXISTS idx_pcv_date;
