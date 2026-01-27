/*
  # Fix Bank Statement Lines Update Policy
  
  1. Problem
    - Duplicate UPDATE policies exist
    - One restrictive (admin/accounts only) blocking auto-match
    - One permissive (all authenticated)
    
  2. Solution
    - Drop both duplicate policies
    - Create single policy allowing all authenticated users to update
    - Needed for auto-match functionality
    
  3. Security
    - Still restricted to authenticated users only
    - Auto-match needs ability to update matched_expense_id, reconciliation_status, notes
*/

-- Drop duplicate policies
DROP POLICY IF EXISTS "bank_statement_lines_update" ON bank_statement_lines;
DROP POLICY IF EXISTS "Accounts/admin can update bank statement lines" ON bank_statement_lines;

-- Create single, clear policy for updates
CREATE POLICY "Authenticated users can update bank statement lines"
  ON bank_statement_lines FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
