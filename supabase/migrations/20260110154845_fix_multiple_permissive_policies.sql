/*
  # Fix Multiple Permissive Policies

  ## Changes
  - Remove duplicate permissive policies
  - Keep the more descriptive/restrictive policy

  ## Tables Fixed
  - crm_activities
  - import_cost_types
  - petty_cash_documents
*/

-- Fix crm_activities - remove generic policies, keep specific ones
DROP POLICY IF EXISTS crm_activities_delete ON crm_activities;
DROP POLICY IF EXISTS crm_activities_insert ON crm_activities;
DROP POLICY IF EXISTS crm_activities_select ON crm_activities;
DROP POLICY IF EXISTS crm_activities_update ON crm_activities;

-- Fix import_cost_types - remove duplicate
DROP POLICY IF EXISTS import_cost_types_all ON import_cost_types;

-- Fix petty_cash_documents - remove generic policies
DROP POLICY IF EXISTS petty_cash_documents_insert ON petty_cash_documents;
DROP POLICY IF EXISTS petty_cash_documents_select ON petty_cash_documents;
