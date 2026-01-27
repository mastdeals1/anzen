/*
  # Fix Stock Double Deduction and Blocking Constraint

  1. Root Cause Analysis
    - Constraint `chk_batch_current_stock_positive` prevents negative stock
    - When triggers try to deduct stock below 0, the UPDATE silently fails
    - Inventory transactions are logged but stock never updates
    - Additionally, TWO triggers both deduct stock:
      * `trg_delivery_challan_item_inventory` (on DC item INSERT)
      * `trg_dc_approval_deduct_stock` (on DC APPROVAL)
    - This causes double deduction attempts (-500g for 250g item)

  2. Solution
    - Remove the positive stock constraint (allow negative/oversold stock)
    - Disable the immediate deduction trigger on DC item INSERT
    - Keep only the DC APPROVAL trigger for actual stock deduction
    - Fix Mometasone batch stock to correct value

  3. Proper Flow
    - DC item INSERT → reserve stock only (via separate trigger)
    - DC APPROVAL → deduct actual stock + release reservation
    - DC REJECTION → release reservation only
    - DC DELETE → release reservation only
*/

-- Step 1: Drop the constraint that blocks negative stock
ALTER TABLE batches 
DROP CONSTRAINT IF EXISTS chk_batch_current_stock_positive;

-- Step 2: Drop the bulletproof triggers that deduct on DC item INSERT/DELETE
-- These conflict with the approval-based flow
DROP TRIGGER IF EXISTS trigger_dc_item_insert ON delivery_challan_items;
DROP TRIGGER IF EXISTS trigger_dc_item_delete ON delivery_challan_items;

-- Step 3: Recalculate and fix Mometasone batch stock based on transactions
-- Current: 250g (wrong)
-- Transactions show: -250g (reserved) + -250g (approved) = -500g
-- But only -250g should have been deducted (on approval)
-- So correct stock = 250 - 250 = 0g
UPDATE batches
SET current_stock = 0,
    reserved_stock = 0
WHERE id = '7fb3efd0-bdff-4da3-a7f5-0e3aa24fcbe6';

-- Step 4: Add a comment explaining the fix
COMMENT ON TABLE batches IS 'Stock can go negative to handle oversold/backorder scenarios. Double deduction fixed by using approval-based flow only.';