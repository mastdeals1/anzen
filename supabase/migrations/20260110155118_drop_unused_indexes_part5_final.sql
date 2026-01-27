/*
  # Drop Unused Indexes - Part 5 (Final)

  ## Changes
  - Drop remaining unused indexes
  - Focus on purchase orders, suppliers, imports, and accounting
*/

-- User Profiles and Gmail
DROP INDEX IF EXISTS idx_user_profiles_username;
DROP INDEX IF EXISTS idx_gmail_processed_user;

-- Voucher Allocations
DROP INDEX IF EXISTS idx_va_payment;
DROP INDEX IF EXISTS idx_va_purchase;
DROP INDEX IF EXISTS idx_va_sales_order;

-- Chart of Accounts
DROP INDEX IF EXISTS idx_coa_type;
DROP INDEX IF EXISTS idx_coa_parent;

-- Suppliers
DROP INDEX IF EXISTS idx_suppliers_name;
DROP INDEX IF EXISTS idx_suppliers_npwp;
DROP INDEX IF EXISTS idx_suppliers_created_by;

-- Accounting Periods
DROP INDEX IF EXISTS idx_accounting_periods_closed_by;

-- Bank Reconciliation
DROP INDEX IF EXISTS idx_bank_reconciliation_items_journal_entry_id;
DROP INDEX IF EXISTS idx_bank_reconciliation_items_reconciliation_id;
DROP INDEX IF EXISTS idx_bank_reconciliations_bank_account_id;
DROP INDEX IF EXISTS idx_bank_reconciliations_created_by;
DROP INDEX IF EXISTS idx_bank_reconciliations_reconciled_by;

-- Batches
DROP INDEX IF EXISTS idx_batch_documents_uploaded_by;
DROP INDEX IF EXISTS idx_batches_created_by;
DROP INDEX IF EXISTS idx_batches_purchase_invoice_id;
DROP INDEX IF EXISTS idx_batches_supplier_id;

-- Tax Codes
DROP INDEX IF EXISTS idx_tax_codes_collection_account_id;
DROP INDEX IF EXISTS idx_tax_codes_payment_account_id;

-- Purchase Orders
DROP INDEX IF EXISTS idx_po_number;
DROP INDEX IF EXISTS idx_po_supplier;
DROP INDEX IF EXISTS idx_po_date;
DROP INDEX IF EXISTS idx_po_status;
DROP INDEX IF EXISTS idx_purchase_orders_approved_by;
DROP INDEX IF EXISTS idx_purchase_orders_created_by;
DROP INDEX IF EXISTS idx_poi_product;
DROP INDEX IF EXISTS idx_poi_coa_code;

-- Purchase Invoices
DROP INDEX IF EXISTS idx_pi_supplier;
DROP INDEX IF EXISTS idx_pi_status;
DROP INDEX IF EXISTS idx_purchase_invoice_items_product_id;
DROP INDEX IF EXISTS idx_purchase_invoice_items_tax_code_id;
DROP INDEX IF EXISTS idx_purchase_invoices_created_by;
DROP INDEX IF EXISTS idx_purchase_invoices_journal_entry_id;
DROP INDEX IF EXISTS idx_pii_invoice;
DROP INDEX IF EXISTS idx_pii_batch;

-- Payment and Receipt Vouchers
DROP INDEX IF EXISTS idx_payment_vouchers_bank_account_id;
DROP INDEX IF EXISTS idx_payment_vouchers_created_by;
DROP INDEX IF EXISTS idx_payment_vouchers_journal_entry_id;
DROP INDEX IF EXISTS idx_payment_vouchers_pph_code_id;
DROP INDEX IF EXISTS idx_receipt_vouchers_created_by;
DROP INDEX IF EXISTS idx_receipt_vouchers_journal_entry_id;
DROP INDEX IF EXISTS idx_invoice_payment_allocations_created_by;

-- Vendor Bills
DROP INDEX IF EXISTS idx_vendor_bills_created_by;

-- Import Containers and Costs
DROP INDEX IF EXISTS idx_import_containers_created_by;
DROP INDEX IF EXISTS idx_import_containers_locked_by;
DROP INDEX IF EXISTS idx_import_containers_supplier;
DROP INDEX IF EXISTS idx_import_cost_headers_created_by;
DROP INDEX IF EXISTS idx_import_cost_headers_posted_by;
DROP INDEX IF EXISTS idx_import_cost_headers_journal_entry;
DROP INDEX IF EXISTS idx_import_cost_types_account;
DROP INDEX IF EXISTS idx_ict_code;
DROP INDEX IF EXISTS idx_ich_number;
DROP INDEX IF EXISTS idx_ich_date;
DROP INDEX IF EXISTS idx_ich_supplier;
DROP INDEX IF EXISTS idx_ich_status;
DROP INDEX IF EXISTS idx_ici_header;
DROP INDEX IF EXISTS idx_ici_batch;
DROP INDEX IF EXISTS idx_ici_product;
DROP INDEX IF EXISTS idx_ici_grn;

-- Extracted Contacts
DROP INDEX IF EXISTS idx_extracted_contacts_email_ids;
DROP INDEX IF EXISTS idx_extracted_contacts_created_at;
