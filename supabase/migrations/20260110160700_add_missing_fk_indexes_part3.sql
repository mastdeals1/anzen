/*
  # Add Missing Foreign Key Indexes - Part 3

  ## Performance Issue
  - Continuing from Part 2
  - Part 3: Tables J-P
*/

-- journal_entries
CREATE INDEX IF NOT EXISTS idx_journal_entries_created_by ON journal_entries(created_by);
CREATE INDEX IF NOT EXISTS idx_journal_entries_period_id ON journal_entries(period_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_posted_by ON journal_entries(posted_by);

-- journal_entry_lines
CREATE INDEX IF NOT EXISTS idx_journal_entry_lines_batch_id ON journal_entry_lines(batch_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_lines_customer_id ON journal_entry_lines(customer_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_lines_supplier_id ON journal_entry_lines(supplier_id);
CREATE INDEX IF NOT EXISTS idx_journal_entry_lines_tax_code_id ON journal_entry_lines(tax_code_id);

-- material_return_items
CREATE INDEX IF NOT EXISTS idx_material_return_items_product_id ON material_return_items(product_id);

-- material_returns
CREATE INDEX IF NOT EXISTS idx_material_returns_approval_workflow_id ON material_returns(approval_workflow_id);
CREATE INDEX IF NOT EXISTS idx_material_returns_approved_by ON material_returns(approved_by);
CREATE INDEX IF NOT EXISTS idx_material_returns_created_by ON material_returns(created_by);
CREATE INDEX IF NOT EXISTS idx_material_returns_customer_id ON material_returns(customer_id);

-- payment_vouchers
CREATE INDEX IF NOT EXISTS idx_payment_vouchers_bank_account_id ON payment_vouchers(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_payment_vouchers_created_by ON payment_vouchers(created_by);
CREATE INDEX IF NOT EXISTS idx_payment_vouchers_journal_entry_id ON payment_vouchers(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_payment_vouchers_pph_code_id ON payment_vouchers(pph_code_id);

-- petty_cash_books
CREATE INDEX IF NOT EXISTS idx_petty_cash_books_account_id ON petty_cash_books(account_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_books_created_by ON petty_cash_books(created_by);
CREATE INDEX IF NOT EXISTS idx_petty_cash_books_custodian_id ON petty_cash_books(custodian_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_books_replenishment_bank_account_id ON petty_cash_books(replenishment_bank_account_id);

-- petty_cash_documents
CREATE INDEX IF NOT EXISTS idx_petty_cash_documents_uploaded_by ON petty_cash_documents(uploaded_by);

-- petty_cash_files
CREATE INDEX IF NOT EXISTS idx_petty_cash_files_petty_cash_voucher_id ON petty_cash_files(petty_cash_voucher_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_files_uploaded_by ON petty_cash_files(uploaded_by);

-- petty_cash_transactions
CREATE INDEX IF NOT EXISTS idx_petty_cash_transactions_created_by ON petty_cash_transactions(created_by);
CREATE INDEX IF NOT EXISTS idx_petty_cash_transactions_delivery_challan_id ON petty_cash_transactions(delivery_challan_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_transactions_import_container_id ON petty_cash_transactions(import_container_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_transactions_paid_by_staff_id ON petty_cash_transactions(paid_by_staff_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_transactions_received_by_staff_id ON petty_cash_transactions(received_by_staff_id);

-- petty_cash_vouchers
CREATE INDEX IF NOT EXISTS idx_petty_cash_vouchers_account_id ON petty_cash_vouchers(account_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_vouchers_approved_by ON petty_cash_vouchers(approved_by);
CREATE INDEX IF NOT EXISTS idx_petty_cash_vouchers_created_by ON petty_cash_vouchers(created_by);
CREATE INDEX IF NOT EXISTS idx_petty_cash_vouchers_journal_entry_id ON petty_cash_vouchers(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_petty_cash_vouchers_tax_code_id ON petty_cash_vouchers(tax_code_id);

-- product_documents
CREATE INDEX IF NOT EXISTS idx_product_documents_uploaded_by ON product_documents(uploaded_by);

-- product_files
CREATE INDEX IF NOT EXISTS idx_product_files_uploaded_by ON product_files(uploaded_by);

-- products
CREATE INDEX IF NOT EXISTS idx_products_created_by ON products(created_by);

-- purchase_invoice_items
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_batch_id ON purchase_invoice_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_product_id ON purchase_invoice_items(product_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_purchase_invoice_id ON purchase_invoice_items(purchase_invoice_id);
CREATE INDEX IF NOT EXISTS idx_purchase_invoice_items_tax_code_id ON purchase_invoice_items(tax_code_id);

-- purchase_invoices
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_created_by ON purchase_invoices(created_by);
CREATE INDEX IF NOT EXISTS idx_purchase_invoices_journal_entry_id ON purchase_invoices(journal_entry_id);

-- purchase_order_items
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_product_id ON purchase_order_items(product_id);

-- purchase_orders
CREATE INDEX IF NOT EXISTS idx_purchase_orders_approved_by ON purchase_orders(approved_by);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_created_by ON purchase_orders(created_by);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id ON purchase_orders(supplier_id);
