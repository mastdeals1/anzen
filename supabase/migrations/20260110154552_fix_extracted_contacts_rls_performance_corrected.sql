/*
  # Fix extracted_contacts RLS Performance (Corrected)

  ## Changes
  - Optimize RLS policies for `extracted_contacts` table
  - Replace `auth.uid()` with `(select auth.uid())` to prevent re-evaluation per row
  - Use correct column name: `user_id` instead of `created_by`

  ## Performance Impact
  This change prevents the auth.uid() function from being called once per row,
  improving query performance at scale.
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view own extracted contacts" ON extracted_contacts;
DROP POLICY IF EXISTS "Users can insert own extracted contacts" ON extracted_contacts;
DROP POLICY IF EXISTS "Users can delete own extracted contacts" ON extracted_contacts;

-- Recreate with optimized auth.uid() calls
CREATE POLICY "Users can view own extracted contacts"
  ON extracted_contacts FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

CREATE POLICY "Users can insert own extracted contacts"
  ON extracted_contacts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (select auth.uid()));

CREATE POLICY "Users can delete own extracted contacts"
  ON extracted_contacts FOR DELETE
  TO authenticated
  USING (user_id = (select auth.uid()));
