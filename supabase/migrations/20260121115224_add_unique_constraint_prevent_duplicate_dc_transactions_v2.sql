/*
  # Prevent Duplicate DC Transactions - Final
  
  Add unique constraints to prevent duplicate transactions from DC edits.
  This ensures each DC item creates exactly ONE transaction.
*/

-- Add unique index for DC delivery transactions
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_dc_delivery_transaction
ON inventory_transactions (batch_id, reference_id, transaction_type)
WHERE reference_type = 'delivery_challan' 
  AND transaction_type = 'delivery_challan';

-- Add unique index for DC reservation transactions  
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_dc_reservation_transaction
ON inventory_transactions (batch_id, reference_id, transaction_type)
WHERE reference_type = 'delivery_challan_item' 
  AND transaction_type = 'delivery_challan_reserved';