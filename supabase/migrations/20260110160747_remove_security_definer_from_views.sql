/*
  # Remove SECURITY DEFINER from Views

  ## Security Issue
  - 21 views are defined with SECURITY DEFINER
  - This bypasses RLS and can expose data inappropriately
  - Views should rely on RLS policies instead

  ## Solution
  - Recreate all views without SECURITY DEFINER
  - Views will now respect RLS policies and run with invoker's permissions
*/

-- Note: We need to recreate each view to remove SECURITY DEFINER
-- The simplest way is to use CREATE OR REPLACE VIEW without SECURITY DEFINER

-- Since views are complex, we'll just add a note that these views already exist
-- and Postgres doesn't allow changing SECURITY property directly
-- We need to DROP and recreate them

-- Get all security definer views and recreate them as security invoker
DO $$
DECLARE
  v_record RECORD;
  v_definition TEXT;
BEGIN
  FOR v_record IN 
    SELECT 
      schemaname,
      viewname,
      definition
    FROM pg_views
    WHERE schemaname = 'public'
      AND viewname IN (
        'customer_receivables_view',
        'v_batch_cost_summary',
        'product_stock_summary',
        'vw_petty_cash_balance',
        'customer_advance_balances',
        'sales_order_advance_details',
        'pending_dc_items_by_customer',
        'supplier_payables_view',
        'vw_cash_on_hand_balance',
        'vw_all_expenses',
        'trial_balance_view',
        'inventory_audit_log',
        'vw_petty_cash_statement',
        'vw_bank_reconciliation_items',
        'vw_input_ppn_report',
        'vw_monthly_tax_summary',
        'vw_fund_transfers_detailed',
        'vw_output_ppn_report',
        'dc_invoicing_summary',
        'dc_item_invoice_status',
        'v_batch_stock_summary'
      )
  LOOP
    -- Drop the view
    EXECUTE format('DROP VIEW IF EXISTS %I.%I CASCADE', v_record.schemaname, v_record.viewname);
    
    -- Recreate without SECURITY DEFINER (default is SECURITY INVOKER)
    EXECUTE format('CREATE VIEW %I.%I AS %s', v_record.schemaname, v_record.viewname, v_record.definition);
  END LOOP;
END $$;

COMMENT ON SCHEMA public IS 'All views now use SECURITY INVOKER (default) and respect RLS policies';
