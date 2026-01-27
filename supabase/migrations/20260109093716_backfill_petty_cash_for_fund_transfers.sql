/*
  # Backfill Missing Petty Cash Transactions for Fund Transfers

  ## Problem
  Fund transfers to petty_cash should create a corresponding petty_cash_transaction,
  but some existing transfers are missing their petty cash entries.

  ## Solution
  1. Find all fund_transfers with to_account_type = 'petty_cash' that don't have a corresponding
     petty_cash_transaction (by fund_transfer_id)
  2. Create the missing petty_cash_transactions
*/

DO $$
DECLARE
  v_transfer RECORD;
  v_tx_number TEXT;
  v_count INT;
  v_source_name TEXT;
BEGIN
  FOR v_transfer IN
    SELECT 
      ft.id,
      ft.transfer_number,
      ft.transfer_date,
      ft.to_amount,
      ft.description,
      ft.from_bank_account_id,
      ft.from_account_type,
      ft.created_by,
      ba.bank_name,
      ba.alias
    FROM fund_transfers ft
    LEFT JOIN bank_accounts ba ON ft.from_bank_account_id = ba.id
    WHERE ft.to_account_type = 'petty_cash'
      AND ft.status = 'posted'
      AND NOT EXISTS (
        SELECT 1 FROM petty_cash_transactions pct
        WHERE pct.fund_transfer_id = ft.id
      )
  LOOP
    -- Generate transaction number
    SELECT COUNT(*) INTO v_count
    FROM petty_cash_transactions
    WHERE transaction_number LIKE 'PCW' || TO_CHAR(v_transfer.transfer_date, 'YYMM') || '%';
    
    v_tx_number := 'PCW' || TO_CHAR(v_transfer.transfer_date, 'YYMM') || '-' || LPAD((v_count + 1)::TEXT, 4, '0');
    
    -- Get source account name
    IF v_transfer.from_account_type = 'bank' AND v_transfer.from_bank_account_id IS NOT NULL THEN
      v_source_name := COALESCE(v_transfer.alias, v_transfer.bank_name, 'Bank');
    ELSE
      v_source_name := 'Bank';
    END IF;
    
    -- Create the petty cash transaction
    INSERT INTO petty_cash_transactions (
      transaction_number,
      transaction_date,
      transaction_type,
      amount,
      description,
      bank_account_id,
      source,
      fund_transfer_id,
      created_by
    ) VALUES (
      v_tx_number,
      v_transfer.transfer_date,
      'withdraw',
      v_transfer.to_amount,
      COALESCE(v_transfer.description, 'Fund transfer from ' || v_source_name),
      v_transfer.from_bank_account_id,
      'Fund Transfer ' || v_transfer.transfer_number,
      v_transfer.id,
      v_transfer.created_by
    );
    
    RAISE NOTICE 'Created petty cash transaction % for fund transfer %', v_tx_number, v_transfer.transfer_number;
  END LOOP;
END $$;
