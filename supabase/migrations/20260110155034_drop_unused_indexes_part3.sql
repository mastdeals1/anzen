/*
  # Drop Unused Indexes - Part 3

  ## Changes
  - Continue dropping unused indexes
  - Focus on bank, fund transfers, and approval indexes
*/

-- Bank Statement and Matching
DROP INDEX IF EXISTS idx_bank_match_memory_pattern;
DROP INDEX IF EXISTS idx_bank_match_memory_category;
DROP INDEX IF EXISTS idx_bank_match_memory_created_by;
DROP INDEX IF EXISTS idx_bank_statement_lines_balance;
DROP INDEX IF EXISTS idx_bank_statement_lines_upload;
DROP INDEX IF EXISTS idx_bank_statement_lines_created_by;
DROP INDEX IF EXISTS idx_bank_statement_lines_matched_entry;
DROP INDEX IF EXISTS idx_bank_statement_uploads_account;
DROP INDEX IF EXISTS idx_bank_statement_uploads_period;
DROP INDEX IF EXISTS idx_bank_statement_uploads_status;
DROP INDEX IF EXISTS idx_bank_statement_uploads_uploaded_by;

-- Fund Transfers
DROP INDEX IF EXISTS idx_fund_transfers_from_statement;
DROP INDEX IF EXISTS idx_fund_transfers_to_statement;
DROP INDEX IF EXISTS idx_fund_transfers_from_bank;
DROP INDEX IF EXISTS idx_fund_transfers_to_bank;
DROP INDEX IF EXISTS idx_fund_transfers_journal;
DROP INDEX IF EXISTS idx_fund_transfers_created_by;
DROP INDEX IF EXISTS idx_fund_transfers_posted_by;
DROP INDEX IF EXISTS idx_fund_transfers_status;

-- Bank Accounts
DROP INDEX IF EXISTS idx_bank_accounts_created_by;
DROP INDEX IF EXISTS idx_bank_accounts_coa_id;

-- Approvals
DROP INDEX IF EXISTS idx_approval_workflows_status;
DROP INDEX IF EXISTS idx_approval_workflows_requested_by;
DROP INDEX IF EXISTS idx_approval_workflows_approved_by;
DROP INDEX IF EXISTS idx_approval_workflows_transaction;
DROP INDEX IF EXISTS idx_approval_thresholds_type;

-- Material Returns and Stock Rejections
DROP INDEX IF EXISTS idx_material_returns_customer;
DROP INDEX IF EXISTS idx_material_returns_approval_workflow_id;
DROP INDEX IF EXISTS idx_material_returns_approved_by;
DROP INDEX IF EXISTS idx_material_returns_created_by;
DROP INDEX IF EXISTS idx_material_return_items_product;
DROP INDEX IF EXISTS idx_stock_rejections_batch;
DROP INDEX IF EXISTS idx_stock_rejections_product;
DROP INDEX IF EXISTS idx_stock_rejections_approval_workflow_id;
DROP INDEX IF EXISTS idx_stock_rejections_approved_by;
DROP INDEX IF EXISTS idx_stock_rejections_created_by;
DROP INDEX IF EXISTS idx_stock_rejections_inspected_by;

-- Credit Notes
DROP INDEX IF EXISTS idx_credit_notes_customer;
DROP INDEX IF EXISTS idx_credit_notes_created_by;
DROP INDEX IF EXISTS idx_credit_notes_approved_by;
DROP INDEX IF EXISTS idx_credit_note_items_product;
