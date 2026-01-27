/*
  # Drop Unused Indexes - Part 1

  ## Changes
  - Drop unused indexes that waste storage and slow down writes
  - Keep indexes that are likely to be used for common queries

  ## Performance Impact
  - Reduces storage usage
  - Improves INSERT/UPDATE/DELETE performance
  - Removes maintenance overhead
*/

-- Audit and User Tracking Indexes (low usage expected)
DROP INDEX IF EXISTS idx_audit_logs_user_id;
DROP INDEX IF EXISTS idx_tasks_completed_by;
DROP INDEX IF EXISTS idx_tasks_deleted_by;
DROP INDEX IF EXISTS idx_task_status_history_changed_by;

-- Duplicate or Redundant Foreign Key Indexes
DROP INDEX IF EXISTS idx_crm_activities_customer_id;
DROP INDEX IF EXISTS idx_crm_emails_customer_id;
DROP INDEX IF EXISTS idx_crm_emails_lead_id;
DROP INDEX IF EXISTS idx_crm_inquiries_assigned_to;
DROP INDEX IF EXISTS idx_crm_leads_assigned_to;
DROP INDEX IF EXISTS idx_crm_quotations_customer_id;
DROP INDEX IF EXISTS idx_crm_reminders_assigned_to;
DROP INDEX IF EXISTS idx_customer_documents_customer_id;
DROP INDEX IF EXISTS idx_customer_payments_customer_id;
DROP INDEX IF EXISTS idx_sales_invoices_customer_id;

-- Payment and Bill Indexes
DROP INDEX IF EXISTS idx_vendor_payments_bill_id;
DROP INDEX IF EXISTS idx_customer_payments_bank_account_id;
DROP INDEX IF EXISTS idx_vendor_payments_bank_account_id;

-- Import Requirements
DROP INDEX IF EXISTS idx_import_requirements_priority;
DROP INDEX IF EXISTS idx_import_requirements_customer_id;

-- Delivery Challans
DROP INDEX IF EXISTS idx_delivery_challans_approval_status;
DROP INDEX IF EXISTS idx_delivery_challans_approved_by;
DROP INDEX IF EXISTS idx_delivery_challans_rejected_by;
DROP INDEX IF EXISTS idx_delivery_challans_sales_order;
DROP INDEX IF EXISTS idx_delivery_challans_created_by;

-- Activities and Follow-ups
DROP INDEX IF EXISTS idx_crm_activities_follow_up;
DROP INDEX IF EXISTS idx_crm_activities_participants;

-- Document Tracking
DROP INDEX IF EXISTS idx_product_documents_type;
DROP INDEX IF EXISTS idx_product_files_uploaded_by;
DROP INDEX IF EXISTS idx_product_documents_uploaded_by;

-- Finance and Expenses
DROP INDEX IF EXISTS idx_finance_expenses_voucher_number;
DROP INDEX IF EXISTS idx_finance_expenses_challan;
DROP INDEX IF EXISTS idx_finance_expenses_dc;
DROP INDEX IF EXISTS idx_finance_expenses_created_by;

-- Customer and Company
DROP INDEX IF EXISTS idx_customers_company_name;
DROP INDEX IF EXISTS idx_customers_created_by;
