/*
  # Add current_stock column to products table with trigger
  
  1. Issue
    - Dashboard query failing because current_stock column doesn't exist
    
  2. Solution
    - Add current_stock as regular column
    - Create trigger to update it when batches change
*/

-- Add current_stock column
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS current_stock DECIMAL(18,2) DEFAULT 0;

-- Function to recalculate product current_stock
CREATE OR REPLACE FUNCTION update_product_current_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product_id uuid;
  v_total_stock numeric;
BEGIN
  -- Determine which product to update
  IF TG_OP = 'DELETE' THEN
    v_product_id := OLD.product_id;
  ELSE
    v_product_id := NEW.product_id;
  END IF;

  -- Calculate total stock for this product
  SELECT COALESCE(SUM(current_stock), 0)
  INTO v_total_stock
  FROM batches
  WHERE product_id = v_product_id
    AND is_active = true;

  -- Update product current_stock
  UPDATE products
  SET current_stock = v_total_stock
  WHERE id = v_product_id;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

-- Create trigger on batches table
DROP TRIGGER IF EXISTS trigger_update_product_stock ON batches;
CREATE TRIGGER trigger_update_product_stock
  AFTER INSERT OR UPDATE OF current_stock, is_active OR DELETE ON batches
  FOR EACH ROW
  EXECUTE FUNCTION update_product_current_stock();

-- Initial population of current_stock for all products
UPDATE products p
SET current_stock = (
  SELECT COALESCE(SUM(b.current_stock), 0)
  FROM batches b
  WHERE b.product_id = p.id
    AND b.is_active = true
);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_products_current_stock ON products(current_stock) WHERE is_active = true;

COMMENT ON COLUMN products.current_stock IS 'Total of all active batch stocks for this product. Auto-updated by trigger.';
