/*
  # Remove Duplicate Indexes

  ## Changes
  - Drop duplicate indexes on `fund_transfers` table
  - Keep the more descriptive index names

  ## Indexes Removed
  - idx_fund_transfers_from_bank_stmt (duplicate of idx_fund_transfers_from_statement)
  - idx_fund_transfers_to_bank_stmt (duplicate of idx_fund_transfers_to_statement)
*/

-- Drop duplicate indexes
DROP INDEX IF EXISTS idx_fund_transfers_from_bank_stmt;
DROP INDEX IF EXISTS idx_fund_transfers_to_bank_stmt;
