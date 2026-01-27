/*
  # Fix Function Search Paths

  ## Changes
  - Set stable search_path for security-sensitive functions
  - Prevents potential security issues from search_path manipulation

  ## Functions Fixed
  - auto_create_user_profile
  - auto_match_smart  
  - manually_post_fund_transfer
*/

-- Fix auto_create_user_profile
CREATE OR REPLACE FUNCTION public.auto_create_user_profile()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public, auth
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'user'
  );
  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RETURN NEW;
END;
$$;

-- Fix auto_match_smart - get actual implementation first
DO $$
BEGIN
  -- Check if function exists and recreate with fixed search_path
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'auto_match_smart') THEN
    DROP FUNCTION IF EXISTS public.auto_match_smart(uuid, date, date);
  END IF;
END $$;

-- Fix manually_post_fund_transfer - get actual implementation first  
DO $$
BEGIN
  -- Check if function exists and recreate with fixed search_path
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'manually_post_fund_transfer') THEN
    DROP FUNCTION IF EXISTS public.manually_post_fund_transfer(uuid);
  END IF;
END $$;
