/*
  # Fix Missing RLS Policies for CRM Activities

  1. Problem
    - crm_activities table only has SELECT policy
    - Missing INSERT, UPDATE, DELETE policies
    - This causes 409 Conflict errors when trying to create appointments

  2. Solution
    - Add INSERT policy for authenticated users
    - Add UPDATE policy for activity creators or participants
    - Add DELETE policy for admins

  3. Security
    - Authenticated users can insert activities
    - Only creators or participants can update activities
    - Only admins can delete activities
*/

-- Add INSERT policy for crm_activities
CREATE POLICY "crm_activities_insert"
  ON crm_activities
  FOR INSERT
  TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid())
  );

-- Add UPDATE policy for crm_activities
CREATE POLICY "crm_activities_update"
  ON crm_activities
  FOR UPDATE
  TO authenticated
  USING (
    created_by = (SELECT auth.uid())
    OR
    participants @> ARRAY[(SELECT auth.uid())]
  )
  WITH CHECK (
    created_by = (SELECT auth.uid())
    OR
    participants @> ARRAY[(SELECT auth.uid())]
  );

-- Add DELETE policy for crm_activities
CREATE POLICY "crm_activities_delete"
  ON crm_activities
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE id = (SELECT auth.uid())
      AND role = 'admin'
    )
  );
