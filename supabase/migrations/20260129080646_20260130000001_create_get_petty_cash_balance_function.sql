/*
  # Create Petty Cash Balance Function
  
  1. New Function
    - `get_petty_cash_balance()` - Calculates current petty cash balance
  
  2. Logic
    - Sum all withdrawals (cash in from bank)
    - Subtract all expenses (cash out)
    - Returns current balance
  
  3. Security
    - SECURITY DEFINER to allow access
    - Returns numeric value
*/

-- Create function to get petty cash balance
CREATE OR REPLACE FUNCTION public.get_petty_cash_balance()
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  total_withdrawals numeric := 0;
  total_expenses numeric := 0;
  current_balance numeric := 0;
BEGIN
  -- Sum all withdrawals (cash coming in from bank)
  SELECT COALESCE(SUM(amount), 0)
  INTO total_withdrawals
  FROM petty_cash_transactions
  WHERE transaction_type = 'withdraw';

  -- Sum all expenses (cash going out)
  SELECT COALESCE(SUM(amount), 0)
  INTO total_expenses
  FROM petty_cash_transactions
  WHERE transaction_type = 'expense';

  -- Calculate balance
  current_balance := total_withdrawals - total_expenses;

  RETURN current_balance;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_petty_cash_balance() TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.get_petty_cash_balance() IS 'Calculates current petty cash balance by summing withdrawals and subtracting expenses';
