/*
  # Drop Unused Indexes - Part 4

  ## Changes
  - Continue dropping unused indexes
  - Focus on CRM, inquiries, tasks, and purchase orders
*/

-- CRM Inquiries
DROP INDEX IF EXISTS idx_crm_inquiries_aceerp_no;
DROP INDEX IF EXISTS idx_crm_inquiries_delivery_date;
DROP INDEX IF EXISTS idx_crm_inquiries_created_by;

-- Inquiry Items
DROP INDEX IF EXISTS idx_inquiry_items_number;
DROP INDEX IF EXISTS idx_inquiry_items_status;
DROP INDEX IF EXISTS idx_inquiry_items_pipeline;
DROP INDEX IF EXISTS idx_inquiry_items_supplier;
DROP INDEX IF EXISTS idx_inquiry_items_aceerp;
DROP INDEX IF EXISTS idx_inquiry_items_delivery_date;

-- CRM Activities and Logs
DROP INDEX IF EXISTS idx_crm_activities_created_by;
DROP INDEX IF EXISTS idx_crm_activity_logs_created_by;
DROP INDEX IF EXISTS idx_crm_automation_rules_created_by;
DROP INDEX IF EXISTS idx_crm_company_domain_mapping_created_by;
DROP INDEX IF EXISTS idx_crm_company_domain_mapping_verified_by;
DROP INDEX IF EXISTS idx_crm_contacts_created_by;

-- CRM Emails
DROP INDEX IF EXISTS idx_crm_email_activities_created_by;
DROP INDEX IF EXISTS idx_crm_email_activities_template_id;
DROP INDEX IF EXISTS idx_crm_email_inbox_assigned_to;
DROP INDEX IF EXISTS idx_crm_email_templates_created_by;
DROP INDEX IF EXISTS idx_crm_emails_sent_by;

-- CRM Inquiry Timeline
DROP INDEX IF EXISTS idx_crm_inquiry_timeline_performed_by;
DROP INDEX IF EXISTS idx_crm_inquiry_timeline_related_action_id;
DROP INDEX IF EXISTS idx_crm_inquiry_timeline_related_activity_id;
DROP INDEX IF EXISTS idx_crm_inquiry_timeline_related_email_id;

-- CRM Leads and Quotations
DROP INDEX IF EXISTS idx_crm_leads_converted_to_customer;
DROP INDEX IF EXISTS idx_crm_leads_created_by;
DROP INDEX IF EXISTS idx_crm_quick_actions_log_performed_by;
DROP INDEX IF EXISTS idx_crm_quick_actions_log_template_used;
DROP INDEX IF EXISTS idx_crm_quotations_created_by;
DROP INDEX IF EXISTS idx_crm_reminders_completed_by;
DROP INDEX IF EXISTS idx_crm_reminders_created_by;

-- Customer Documents
DROP INDEX IF EXISTS idx_customer_documents_uploaded_by;
DROP INDEX IF EXISTS idx_customer_payments_created_by;
DROP INDEX IF EXISTS idx_vendor_payments_created_by;

-- Tasks
DROP INDEX IF EXISTS idx_tasks_status;
DROP INDEX IF EXISTS idx_tasks_priority;
DROP INDEX IF EXISTS idx_tasks_created_by;
DROP INDEX IF EXISTS idx_tasks_assigned_users;
DROP INDEX IF EXISTS idx_tasks_customer;
DROP INDEX IF EXISTS idx_tasks_created_at;
DROP INDEX IF EXISTS idx_tasks_completed_at;
DROP INDEX IF EXISTS idx_tasks_title_search;
DROP INDEX IF EXISTS idx_tasks_description_search;
DROP INDEX IF EXISTS idx_task_comments_task;
DROP INDEX IF EXISTS idx_task_comments_user;
DROP INDEX IF EXISTS idx_task_comments_created;
DROP INDEX IF EXISTS idx_task_comments_parent;
DROP INDEX IF EXISTS idx_task_comments_mentions;
DROP INDEX IF EXISTS idx_task_assignments_task;
DROP INDEX IF EXISTS idx_task_assignments_user;
DROP INDEX IF EXISTS idx_task_assignments_assigned_by;
DROP INDEX IF EXISTS idx_task_status_history_task;
DROP INDEX IF EXISTS idx_task_status_history_changed_at;
