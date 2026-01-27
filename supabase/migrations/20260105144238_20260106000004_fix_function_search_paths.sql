/*
  # Fix Function Search Paths for Security

  This migration fixes functions that have role mutable search_path.
  Functions without an explicit search_path can be vulnerable to search_path attacks
  where malicious users could create schemas to intercept function calls.

  ## Functions Fixed:
  
  1. prevent_empty_delivery_challans
  2. verify_dc_has_items_before_approval
  3. generate_bank_transaction_hash
  4. auto_generate_transaction_hash
  5. prevent_linked_dc_deletion
  6. trg_update_po_timestamp
  7. auto_match_all_bank_transactions
  8. safe_delete_bank_statement_lines
  9. preview_bank_statement_delete
  10. learn_from_match
  11. auto_match_with_memory

  ## Security Impact:
  - Prevents search_path attacks
  - Ensures functions always reference the correct schema
  - Improves function security and reliability
*/

-- Set search_path for all affected functions with correct signatures
ALTER FUNCTION prevent_empty_delivery_challans() 
  SET search_path = public, pg_temp;

ALTER FUNCTION verify_dc_has_items_before_approval() 
  SET search_path = public, pg_temp;

ALTER FUNCTION generate_bank_transaction_hash(UUID, DATE, NUMERIC, NUMERIC, TEXT) 
  SET search_path = public, pg_temp;

ALTER FUNCTION auto_generate_transaction_hash() 
  SET search_path = public, pg_temp;

ALTER FUNCTION prevent_linked_dc_deletion() 
  SET search_path = public, pg_temp;

ALTER FUNCTION trg_update_po_timestamp() 
  SET search_path = public, pg_temp;

ALTER FUNCTION auto_match_all_bank_transactions() 
  SET search_path = public, pg_temp;

ALTER FUNCTION safe_delete_bank_statement_lines(UUID, DATE, DATE) 
  SET search_path = public, pg_temp;

ALTER FUNCTION preview_bank_statement_delete(UUID, DATE, DATE) 
  SET search_path = public, pg_temp;

ALTER FUNCTION learn_from_match(TEXT, TEXT) 
  SET search_path = public, pg_temp;

ALTER FUNCTION auto_match_with_memory() 
  SET search_path = public, pg_temp;