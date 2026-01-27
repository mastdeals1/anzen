/*
  # Add UPDATE Policy for Fund Transfers

  ## Problem
  The fund_transfers table has RLS enabled with SELECT and INSERT policies,
  but no UPDATE policy. This causes updates to silently fail.

  ## Solution
  Add an UPDATE policy that allows authenticated users with admin or accounts role
  to update any fund transfer, or the creator to update their own transfers.
*/

DROP POLICY IF EXISTS "Users can update fund transfers" ON fund_transfers;

CREATE POLICY "Users can update fund transfers" 
  ON fund_transfers 
  FOR UPDATE 
  TO authenticated 
  USING (
    created_by = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  )
  WITH CHECK (
    created_by = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );

DROP POLICY IF EXISTS "Users can delete fund transfers" ON fund_transfers;

CREATE POLICY "Users can delete fund transfers" 
  ON fund_transfers 
  FOR DELETE 
  TO authenticated 
  USING (
    created_by = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = (SELECT auth.uid()) 
      AND role IN ('admin', 'accounts')
    )
  );
