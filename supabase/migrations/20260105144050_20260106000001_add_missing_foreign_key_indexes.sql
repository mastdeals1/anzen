/*
  # Add Missing Foreign Key Indexes for Performance

  This migration adds indexes for all foreign key columns that are missing covering indexes.
  These indexes are critical for query performance, especially for JOIN operations and 
  foreign key constraint checks.

  ## Tables and Indexes Added:
  
  1. bank_match_memory
     - idx_bank_match_memory_created_by (created_by)
  
  2. bank_statement_lines
     - idx_bank_statement_lines_created_by (created_by)
     - idx_bank_statement_lines_matched_by (matched_by)
  
  3. bank_statement_uploads
     - idx_bank_statement_uploads_uploaded_by (uploaded_by)
  
  4. fund_transfers
     - idx_fund_transfers_created_by (created_by)
     - idx_fund_transfers_posted_by (posted_by)
  
  5. import_containers
     - idx_import_containers_created_by (created_by)
     - idx_import_containers_locked_by (locked_by)
  
  6. import_cost_headers
     - idx_import_cost_headers_created_by (created_by)
     - idx_import_cost_headers_posted_by (posted_by)
  
  7. purchase_orders
     - idx_purchase_orders_approved_by (approved_by)
     - idx_purchase_orders_created_by (created_by)

  ## Performance Impact:
  - Dramatically improves JOIN performance
  - Speeds up foreign key constraint validation
  - Reduces query execution time for filtered queries on these columns
*/

-- bank_match_memory indexes
CREATE INDEX IF NOT EXISTS idx_bank_match_memory_created_by 
  ON bank_match_memory(created_by);

-- bank_statement_lines indexes
CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_created_by 
  ON bank_statement_lines(created_by);

CREATE INDEX IF NOT EXISTS idx_bank_statement_lines_matched_by 
  ON bank_statement_lines(matched_by);

-- bank_statement_uploads indexes
CREATE INDEX IF NOT EXISTS idx_bank_statement_uploads_uploaded_by 
  ON bank_statement_uploads(uploaded_by);

-- fund_transfers indexes
CREATE INDEX IF NOT EXISTS idx_fund_transfers_created_by 
  ON fund_transfers(created_by);

CREATE INDEX IF NOT EXISTS idx_fund_transfers_posted_by 
  ON fund_transfers(posted_by);

-- import_containers indexes
CREATE INDEX IF NOT EXISTS idx_import_containers_created_by 
  ON import_containers(created_by);

CREATE INDEX IF NOT EXISTS idx_import_containers_locked_by 
  ON import_containers(locked_by);

-- import_cost_headers indexes
CREATE INDEX IF NOT EXISTS idx_import_cost_headers_created_by 
  ON import_cost_headers(created_by);

CREATE INDEX IF NOT EXISTS idx_import_cost_headers_posted_by 
  ON import_cost_headers(posted_by);

-- purchase_orders indexes
CREATE INDEX IF NOT EXISTS idx_purchase_orders_approved_by 
  ON purchase_orders(approved_by);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_created_by 
  ON purchase_orders(created_by);