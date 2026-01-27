/*
  # Fix Multiple Permissive Policies

  This migration consolidates multiple permissive policies into single policies
  to improve security clarity and query performance. Multiple permissive policies
  for the same action are ORed together, which can lead to confusion and
  potential security issues.

  ## Tables Fixed:
  
  1. approval_thresholds - Consolidated SELECT policies
  2. bank_match_memory - Consolidated SELECT policies
  3. bank_statement_lines - Consolidated DELETE policies
  4. crm_activities - Consolidated SELECT policies
  5. import_containers - Consolidated UPDATE policies
  6. import_cost_types - Consolidated SELECT policies
  7. import_requirements - Consolidated SELECT policies
  8. petty_cash_documents - Consolidated INSERT and SELECT policies

  ## Security Impact:
  - Clearer security model
  - Improved policy evaluation performance
  - Reduced confusion about access control
*/

-- ============================================================================
-- APPROVAL THRESHOLDS
-- ============================================================================

DROP POLICY IF EXISTS "Admins can manage approval thresholds" ON approval_thresholds;
DROP POLICY IF EXISTS "Users can view approval thresholds" ON approval_thresholds;

CREATE POLICY "approval_thresholds_select" 
  ON approval_thresholds 
  FOR SELECT 
  TO authenticated 
  USING (true);

-- ============================================================================
-- BANK MATCH MEMORY
-- ============================================================================

DROP POLICY IF EXISTS "Users can view match memory" ON bank_match_memory;

-- Keep the admin policy as is (already exists from earlier migration)

-- ============================================================================
-- BANK STATEMENT LINES  
-- ============================================================================

-- Only one delete policy needed (kept from earlier migration)
DROP POLICY IF EXISTS "Accounts/admin can delete bank statement lines" ON bank_statement_lines;

-- ============================================================================
-- CRM ACTIVITIES
-- ============================================================================

DROP POLICY IF EXISTS "Admin and sales can view activities" ON crm_activities;
DROP POLICY IF EXISTS "Users can view appointments they're involved in" ON crm_activities;

CREATE POLICY "crm_activities_select" 
  ON crm_activities 
  FOR SELECT 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'sales')
    )
    OR 
    participants @> ARRAY[(SELECT auth.uid())]
  );

-- ============================================================================
-- IMPORT CONTAINERS
-- ============================================================================

DROP POLICY IF EXISTS "Users can update draft containers" ON import_containers;

-- Keep admin policy (already optimized from earlier migration)

-- ============================================================================
-- IMPORT COST TYPES
-- ============================================================================

DROP POLICY IF EXISTS "import_cost_types_select" ON import_cost_types;
DROP POLICY IF EXISTS "import_cost_types_write" ON import_cost_types;

CREATE POLICY "import_cost_types_select" 
  ON import_cost_types 
  FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "import_cost_types_all" 
  ON import_cost_types 
  FOR ALL 
  TO authenticated 
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'procurement')
    )
  );

-- ============================================================================
-- IMPORT REQUIREMENTS
-- ============================================================================

DROP POLICY IF EXISTS "Authenticated users can view import requirements" ON import_requirements;

-- Keep admin manage policy

-- ============================================================================
-- PETTY CASH DOCUMENTS
-- ============================================================================

DROP POLICY IF EXISTS "Admin and accounts can insert petty cash documents" ON petty_cash_documents;
DROP POLICY IF EXISTS "Users can view all petty cash documents" ON petty_cash_documents;
DROP POLICY IF EXISTS "Users can view petty cash documents" ON petty_cash_documents;

CREATE POLICY "petty_cash_documents_insert" 
  ON petty_cash_documents 
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    uploaded_by = (SELECT auth.uid())
  );

CREATE POLICY "petty_cash_documents_select" 
  ON petty_cash_documents 
  FOR SELECT 
  TO authenticated 
  USING (true);