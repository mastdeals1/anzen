/*
  # Optimize RLS Auth Function Calls for Performance

  This migration optimizes Row Level Security (RLS) policies by replacing direct
  auth.function() calls with (select auth.function()). This prevents the function
  from being re-evaluated for each row, significantly improving query performance
  at scale.

  ## Changes:
  
  1. purchase_orders - purchase_orders_delete policy
  2. import_containers - Admins can update any container policy
  3. product_documents - 3 policies optimized
  4. bank_statement_uploads - 2 policies optimized
  5. bank_statement_lines - 3 policies optimized
  6. bank_match_memory - 1 policy optimized
  7. fund_transfers - 1 policy optimized
  8. petty_cash_documents - 1 policy optimized

  ## Performance Impact:
  - Reduces CPU usage for row-level security checks
  - Improves query performance on large tables
  - Prevents redundant auth function evaluations
*/

-- ============================================================================
-- PURCHASE ORDERS
-- ============================================================================

DROP POLICY IF EXISTS "purchase_orders_delete" ON purchase_orders;

CREATE POLICY "purchase_orders_delete" 
  ON purchase_orders 
  FOR DELETE 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin')
    )
  );

-- ============================================================================
-- IMPORT CONTAINERS
-- ============================================================================

DROP POLICY IF EXISTS "Admins can update any container" ON import_containers;

CREATE POLICY "Admins can update any container" 
  ON import_containers 
  FOR UPDATE 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role = 'admin'
    )
  );

-- ============================================================================
-- PRODUCT DOCUMENTS
-- ============================================================================

DROP POLICY IF EXISTS "Authenticated users can upload product documents" ON product_documents;
DROP POLICY IF EXISTS "Users can update own product documents" ON product_documents;
DROP POLICY IF EXISTS "Users can delete own product documents" ON product_documents;

CREATE POLICY "Authenticated users can upload product documents" 
  ON product_documents 
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    uploaded_by = (SELECT auth.uid())
  );

CREATE POLICY "Users can update own product documents" 
  ON product_documents 
  FOR UPDATE 
  TO authenticated 
  USING (
    uploaded_by = (SELECT auth.uid())
  );

CREATE POLICY "Users can delete own product documents" 
  ON product_documents 
  FOR DELETE 
  TO authenticated 
  USING (
    uploaded_by = (SELECT auth.uid())
  );

-- ============================================================================
-- BANK STATEMENT UPLOADS
-- ============================================================================

DROP POLICY IF EXISTS "Accounts/admin can insert bank statement uploads" ON bank_statement_uploads;
DROP POLICY IF EXISTS "Accounts/admin can update bank statement uploads" ON bank_statement_uploads;

CREATE POLICY "Accounts/admin can insert bank statement uploads" 
  ON bank_statement_uploads 
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );

CREATE POLICY "Accounts/admin can update bank statement uploads" 
  ON bank_statement_uploads 
  FOR UPDATE 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );

-- ============================================================================
-- BANK STATEMENT LINES
-- ============================================================================

DROP POLICY IF EXISTS "Accounts/admin can insert bank statement lines" ON bank_statement_lines;
DROP POLICY IF EXISTS "Accounts/admin can delete bank statement lines" ON bank_statement_lines;
DROP POLICY IF EXISTS "bank_statement_lines_delete" ON bank_statement_lines;

CREATE POLICY "Accounts/admin can insert bank statement lines" 
  ON bank_statement_lines 
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );

CREATE POLICY "bank_statement_lines_delete" 
  ON bank_statement_lines 
  FOR DELETE 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );

-- ============================================================================
-- BANK MATCH MEMORY
-- ============================================================================

DROP POLICY IF EXISTS "Accounts/admin can manage match memory" ON bank_match_memory;

CREATE POLICY "Accounts/admin can manage match memory" 
  ON bank_match_memory 
  FOR ALL 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );

-- ============================================================================
-- FUND TRANSFERS
-- ============================================================================

DROP POLICY IF EXISTS "Users can create fund transfers" ON fund_transfers;

CREATE POLICY "Users can create fund transfers" 
  ON fund_transfers 
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    created_by = (SELECT auth.uid())
  );

-- ============================================================================
-- PETTY CASH DOCUMENTS
-- ============================================================================

DROP POLICY IF EXISTS "Users can upload petty cash documents" ON petty_cash_documents;

CREATE POLICY "Users can upload petty cash documents" 
  ON petty_cash_documents 
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    uploaded_by = (SELECT auth.uid())
  );