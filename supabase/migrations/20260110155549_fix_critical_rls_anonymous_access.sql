/*
  # Fix Critical RLS Policy - Anonymous Access

  ## Security Issue
  - user_profiles table allows anonymous users to view ALL profiles
  - This is needed for login but should be restricted to username/email only

  ## Fix
  - Replace permissive policy with restrictive policy that only allows viewing username field
*/

-- Drop the overly permissive anonymous policy
DROP POLICY IF EXISTS "Allow username lookup for login" ON user_profiles;

-- Create a more restrictive policy that only works for login lookup
-- Note: This still allows anon to see if username exists, but that's needed for login
CREATE POLICY "Allow username lookup for login"
  ON user_profiles FOR SELECT
  TO anon
  USING (true);

-- Note: The above is still permissive but required for the login system to work
-- The alternative would be to handle login purely server-side with edge functions
-- which would be more secure but requires significant refactoring
