/*
  # Add Missing Foreign Key Indexes - Part 2

  ## Performance Issue
  - Continuing from Part 1
  - Part 2: Tables D-I
*/

-- delivery_challans
CREATE INDEX IF NOT EXISTS idx_delivery_challans_approved_by ON delivery_challans(approved_by);
CREATE INDEX IF NOT EXISTS idx_delivery_challans_created_by ON delivery_challans(created_by);
CREATE INDEX IF NOT EXISTS idx_delivery_challans_rejected_by ON delivery_challans(rejected_by);
CREATE INDEX IF NOT EXISTS idx_delivery_challans_sales_order_id ON delivery_challans(sales_order_id);

-- finance_expenses
CREATE INDEX IF NOT EXISTS idx_finance_expenses_created_by ON finance_expenses(created_by);
CREATE INDEX IF NOT EXISTS idx_finance_expenses_delivery_challan_id ON finance_expenses(delivery_challan_id);

-- fund_transfers
CREATE INDEX IF NOT EXISTS idx_fund_transfers_created_by ON fund_transfers(created_by);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_from_bank_account_id ON fund_transfers(from_bank_account_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_from_bank_statement_line_id ON fund_transfers(from_bank_statement_line_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_journal_entry_id ON fund_transfers(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_posted_by ON fund_transfers(posted_by);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_to_bank_account_id ON fund_transfers(to_bank_account_id);
CREATE INDEX IF NOT EXISTS idx_fund_transfers_to_bank_statement_line_id ON fund_transfers(to_bank_statement_line_id);

-- gmail_processed_messages
CREATE INDEX IF NOT EXISTS idx_gmail_processed_messages_user_id ON gmail_processed_messages(user_id);

-- import_containers
CREATE INDEX IF NOT EXISTS idx_import_containers_created_by ON import_containers(created_by);
CREATE INDEX IF NOT EXISTS idx_import_containers_locked_by ON import_containers(locked_by);
CREATE INDEX IF NOT EXISTS idx_import_containers_supplier_id ON import_containers(supplier_id);

-- import_cost_headers
CREATE INDEX IF NOT EXISTS idx_import_cost_headers_created_by ON import_cost_headers(created_by);
CREATE INDEX IF NOT EXISTS idx_import_cost_headers_journal_entry_id ON import_cost_headers(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_import_cost_headers_posted_by ON import_cost_headers(posted_by);
CREATE INDEX IF NOT EXISTS idx_import_cost_headers_supplier_id ON import_cost_headers(supplier_id);

-- import_cost_items
CREATE INDEX IF NOT EXISTS idx_import_cost_items_batch_id ON import_cost_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_import_cost_items_product_id ON import_cost_items(product_id);

-- import_cost_types
CREATE INDEX IF NOT EXISTS idx_import_cost_types_account_id ON import_cost_types(account_id);

-- import_requirements
CREATE INDEX IF NOT EXISTS idx_import_requirements_customer_id ON import_requirements(customer_id);

-- inventory_transactions
CREATE INDEX IF NOT EXISTS idx_inventory_transactions_created_by ON inventory_transactions(created_by);

-- invoice_payment_allocations
CREATE INDEX IF NOT EXISTS idx_invoice_payment_allocations_created_by ON invoice_payment_allocations(created_by);
