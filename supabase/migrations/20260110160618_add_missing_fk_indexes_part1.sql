/*
  # Add Missing Foreign Key Indexes - Part 1

  ## Performance Issue
  - 186 foreign keys without covering indexes
  - This causes full table scans on JOINs and cascade operations
  - Significantly impacts query performance

  ## Solution
  - Add indexes for all unindexed foreign keys
  - Part 1: Tables A-C
*/

-- accounting_periods
CREATE INDEX IF NOT EXISTS idx_accounting_periods_closed_by ON accounting_periods(closed_by);

-- approval_workflows
CREATE INDEX IF NOT EXISTS idx_approval_workflows_approved_by ON approval_workflows(approved_by);
CREATE INDEX IF NOT EXISTS idx_approval_workflows_requested_by ON approval_workflows(requested_by);

-- audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);

-- bank_accounts
CREATE INDEX IF NOT EXISTS idx_bank_accounts_coa_id ON bank_accounts(coa_id);
CREATE INDEX IF NOT EXISTS idx_bank_accounts_created_by ON bank_accounts(created_by);

-- bank_match_memory
CREATE INDEX IF NOT EXISTS idx_bank_match_memory_created_by ON bank_match_memory(created_by);

-- bank_reconciliation_items
CREATE INDEX IF NOT EXISTS idx_bank_reconciliation_items_journal_entry_id ON bank_reconciliation_items(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_bank_reconciliation_items_reconciliation_id ON bank_reconciliation_items(reconciliation_id);

-- bank_reconciliations
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_bank_account_id ON bank_reconciliations(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_created_by ON bank_reconciliations(created_by);
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_reconciled_by ON bank_reconciliations(reconciled_by);

-- bank_statement_lines
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_created_by ON bank_statement_lines(created_by);
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_matched_entry_id ON bank_statement_lines(matched_entry_id);
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_upload_id ON bank_statement_lines(upload_id);

-- bank_statement_uploads
CREATE INDEX IF NOT EXISTS idx_bank_statement_uploads_bank_account_id ON bank_statement_uploads(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_bank_statement_uploads_uploaded_by ON bank_statement_uploads(uploaded_by);

-- batch_documents
CREATE INDEX IF NOT EXISTS idx_batch_documents_uploaded_by ON batch_documents(uploaded_by);

-- batches
CREATE INDEX IF NOT EXISTS idx_batches_created_by ON batches(created_by);
CREATE INDEX IF NOT EXISTS idx_batches_purchase_invoice_id ON batches(purchase_invoice_id);
CREATE INDEX IF NOT EXISTS idx_batches_supplier_id ON batches(supplier_id);

-- chart_of_accounts
CREATE INDEX IF NOT EXISTS idx_chart_of_accounts_parent_id ON chart_of_accounts(parent_id);

-- credit_note_items
CREATE INDEX IF NOT EXISTS idx_credit_note_items_product_id ON credit_note_items(product_id);

-- credit_notes
CREATE INDEX IF NOT EXISTS idx_credit_notes_approved_by ON credit_notes(approved_by);
CREATE INDEX IF NOT EXISTS idx_credit_notes_created_by ON credit_notes(created_by);
CREATE INDEX IF NOT EXISTS idx_credit_notes_customer_id ON credit_notes(customer_id);

-- crm_activities
CREATE INDEX IF NOT EXISTS idx_crm_activities_created_by ON crm_activities(created_by);
CREATE INDEX IF NOT EXISTS idx_crm_activities_customer_id ON crm_activities(customer_id);

-- crm_activity_logs
CREATE INDEX IF NOT EXISTS idx_crm_activity_logs_created_by ON crm_activity_logs(created_by);

-- crm_automation_rules
CREATE INDEX IF NOT EXISTS idx_crm_automation_rules_created_by ON crm_automation_rules(created_by);

-- crm_company_domain_mapping
CREATE INDEX IF NOT EXISTS idx_crm_company_domain_mapping_created_by ON crm_company_domain_mapping(created_by);
CREATE INDEX IF NOT EXISTS idx_crm_company_domain_mapping_verified_by ON crm_company_domain_mapping(verified_by);

-- crm_contacts
CREATE INDEX IF NOT EXISTS idx_crm_contacts_created_by ON crm_contacts(created_by);

-- crm_email_activities
CREATE INDEX IF NOT EXISTS idx_crm_email_activities_created_by ON crm_email_activities(created_by);
CREATE INDEX IF NOT EXISTS idx_crm_email_activities_template_id ON crm_email_activities(template_id);

-- crm_email_inbox
CREATE INDEX IF NOT EXISTS idx_crm_email_inbox_assigned_to ON crm_email_inbox(assigned_to);

-- crm_email_templates
CREATE INDEX IF NOT EXISTS idx_crm_email_templates_created_by ON crm_email_templates(created_by);

-- crm_emails
CREATE INDEX IF NOT EXISTS idx_crm_emails_customer_id ON crm_emails(customer_id);
CREATE INDEX IF NOT EXISTS idx_crm_emails_lead_id ON crm_emails(lead_id);
CREATE INDEX IF NOT EXISTS idx_crm_emails_sent_by ON crm_emails(sent_by);

-- crm_inquiries
CREATE INDEX IF NOT EXISTS idx_crm_inquiries_assigned_to ON crm_inquiries(assigned_to);
CREATE INDEX IF NOT EXISTS idx_crm_inquiries_created_by ON crm_inquiries(created_by);

-- crm_inquiry_timeline
CREATE INDEX IF NOT EXISTS idx_crm_inquiry_timeline_performed_by ON crm_inquiry_timeline(performed_by);
CREATE INDEX IF NOT EXISTS idx_crm_inquiry_timeline_related_action_id ON crm_inquiry_timeline(related_action_id);
CREATE INDEX IF NOT EXISTS idx_crm_inquiry_timeline_related_activity_id ON crm_inquiry_timeline(related_activity_id);
CREATE INDEX IF NOT EXISTS idx_crm_inquiry_timeline_related_email_id ON crm_inquiry_timeline(related_email_id);

-- crm_leads
CREATE INDEX IF NOT EXISTS idx_crm_leads_assigned_to ON crm_leads(assigned_to);
CREATE INDEX IF NOT EXISTS idx_crm_leads_converted_to_customer ON crm_leads(converted_to_customer);
CREATE INDEX IF NOT EXISTS idx_crm_leads_created_by ON crm_leads(created_by);

-- crm_quick_actions_log
CREATE INDEX IF NOT EXISTS idx_crm_quick_actions_log_performed_by ON crm_quick_actions_log(performed_by);
CREATE INDEX IF NOT EXISTS idx_crm_quick_actions_log_template_used ON crm_quick_actions_log(template_used);

-- crm_quotations
CREATE INDEX IF NOT EXISTS idx_crm_quotations_created_by ON crm_quotations(created_by);
CREATE INDEX IF NOT EXISTS idx_crm_quotations_customer_id ON crm_quotations(customer_id);

-- crm_reminders
CREATE INDEX IF NOT EXISTS idx_crm_reminders_assigned_to ON crm_reminders(assigned_to);
CREATE INDEX IF NOT EXISTS idx_crm_reminders_completed_by ON crm_reminders(completed_by);
CREATE INDEX IF NOT EXISTS idx_crm_reminders_created_by ON crm_reminders(created_by);

-- customer_documents
CREATE INDEX IF NOT EXISTS idx_customer_documents_customer_id ON customer_documents(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_documents_uploaded_by ON customer_documents(uploaded_by);

-- customer_payments
CREATE INDEX IF NOT EXISTS idx_customer_payments_bank_account_id ON customer_payments(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_customer_payments_created_by ON customer_payments(created_by);
CREATE INDEX IF NOT EXISTS idx_customer_payments_customer_id ON customer_payments(customer_id);

-- customers
CREATE INDEX IF NOT EXISTS idx_customers_created_by ON customers(created_by);
