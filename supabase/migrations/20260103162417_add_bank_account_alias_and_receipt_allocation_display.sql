/*
  # Add bank account alias for shorter display names
  
  1. Changes
    - Add `alias` column to bank_accounts for short display names (e.g., "BCA IDR", "BCA USD")
    - This alias will be used throughout the UI instead of full account_name
    
  2. Notes
    - Alias is optional - if empty, falls back to account_name
    - Users can set meaningful short names that are easier to read in tables
*/

ALTER TABLE bank_accounts
ADD COLUMN IF NOT EXISTS alias text;

COMMENT ON COLUMN bank_accounts.alias IS 'Short display name for UI (e.g., "BCA IDR", "Mandiri USD")';
