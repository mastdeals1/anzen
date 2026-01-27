/*
  # Drop Duplicate Indexes for Performance

  This migration removes duplicate indexes that are indexing the same columns.
  Duplicate indexes waste storage space and slow down write operations (INSERT, UPDATE, DELETE)
  without providing any performance benefit.

  ## Duplicate Index Pairs Removed:
  
  For each pair, we keep the more descriptive name (with _id suffix) and drop the shorter version.

  1. bank_reconciliation_items - 2 duplicates
  2. bank_reconciliations - 1 duplicate  
  3. batches - 2 duplicates
  4. journal_entries - 2 duplicates
  5. journal_entry_lines - 2 duplicates
  6. material_returns - 1 duplicate
  7. payment_vouchers - 3 duplicates
  8. petty_cash_books - 2 duplicates
  9. petty_cash_documents - 1 duplicate
  10. petty_cash_transactions - 3 duplicates
  11. petty_cash_vouchers - 3 duplicates
  12. purchase_invoice_items - 2 duplicates
  13. purchase_invoices - 1 duplicate
  14. receipt_vouchers - 2 duplicates
  15. sales_invoices - 1 duplicate
  16. stock_rejections - 1 duplicate
  17. tax_codes - 2 duplicates

  ## Performance Impact:
  - Reduces storage usage
  - Improves write operation performance
  - Simplifies index maintenance
*/

-- bank_reconciliation_items
DROP INDEX IF EXISTS idx_bank_reconciliation_items_journal_entry;
DROP INDEX IF EXISTS idx_bank_reconciliation_items_reconciliation;

-- bank_reconciliations  
DROP INDEX IF EXISTS idx_bank_reconciliations_bank_account;

-- batches
DROP INDEX IF EXISTS idx_batches_purchase_invoice;
DROP INDEX IF EXISTS idx_batches_supplier;

-- journal_entries
DROP INDEX IF EXISTS idx_journal_entries_period;
DROP INDEX IF EXISTS idx_journal_entries_reversed_by;

-- journal_entry_lines
DROP INDEX IF EXISTS idx_journal_entry_lines_batch;
DROP INDEX IF EXISTS idx_journal_entry_lines_tax_code;

-- material_returns
DROP INDEX IF EXISTS idx_material_returns_approval_workflow;

-- payment_vouchers
DROP INDEX IF EXISTS idx_payment_vouchers_bank_account;
DROP INDEX IF EXISTS idx_payment_vouchers_journal_entry;
DROP INDEX IF EXISTS idx_payment_vouchers_pph_code;

-- petty_cash_books
DROP INDEX IF EXISTS idx_petty_cash_books_account;
DROP INDEX IF EXISTS idx_petty_cash_books_custodian;

-- petty_cash_documents
DROP INDEX IF EXISTS idx_petty_cash_documents_transaction;

-- petty_cash_transactions
DROP INDEX IF EXISTS idx_petty_cash_transactions_bank_account;
DROP INDEX IF EXISTS idx_petty_cash_transactions_paid_by;
DROP INDEX IF EXISTS idx_petty_cash_transactions_received_by;

-- petty_cash_vouchers
DROP INDEX IF EXISTS idx_petty_cash_vouchers_account;
DROP INDEX IF EXISTS idx_petty_cash_vouchers_journal_entry;
DROP INDEX IF EXISTS idx_petty_cash_vouchers_tax_code;

-- purchase_invoice_items
DROP INDEX IF EXISTS idx_purchase_invoice_items_product;
DROP INDEX IF EXISTS idx_purchase_invoice_items_tax_code;

-- purchase_invoices
DROP INDEX IF EXISTS idx_purchase_invoices_journal_entry;

-- receipt_vouchers
DROP INDEX IF EXISTS idx_receipt_vouchers_bank_account;
DROP INDEX IF EXISTS idx_receipt_vouchers_journal_entry;

-- sales_invoices
DROP INDEX IF EXISTS idx_sales_invoices_journal_entry;

-- stock_rejections
DROP INDEX IF EXISTS idx_stock_rejections_approval_workflow;

-- tax_codes
DROP INDEX IF EXISTS idx_tax_codes_collection_account;
DROP INDEX IF EXISTS idx_tax_codes_payment_account;