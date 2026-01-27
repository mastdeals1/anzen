# Complete Accounting System Logic - Pharmaceutical Trading ERP

## Overview
This system implements **Double-Entry Bookkeeping** - the foundation of all professional accounting systems like Tally, QuickBooks, SAP, etc.

---

## Core Accounting Principles

### 1. Double-Entry Bookkeeping
**Every transaction has TWO sides:**
- **DEBIT (Dr)** - Left side
- **CREDIT (Cr)** - Right side
- **Rule:** Total Debits = Total Credits (ALWAYS BALANCED)

### 2. Account Types and Normal Balances

| Account Type | Normal Balance | Increases By | Decreases By |
|-------------|----------------|--------------|--------------|
| **ASSETS** | Debit | Debit | Credit |
| **LIABILITIES** | Credit | Credit | Debit |
| **EQUITY** | Credit | Credit | Debit |
| **REVENUE** | Credit | Credit | Debit |
| **EXPENSES** | Debit | Debit | Credit |

---

## Petty Cash Accounting Flow

### What is Petty Cash?
**Petty Cash = Cash in Hand** (Physical cash kept for small daily expenses)

### Complete Flow:

#### Step 1: Withdraw Cash from Bank to Petty Cash
**Transaction:** PCW2601-0001 - Withdraw Rp 500,000 from Bank

**Journal Entry JE202601-0001:**
```
Dr  Petty Cash (1102)         Rp 500,000  [Asset increases]
    Cr  Bank Accounts (1110)              Rp 500,000  [Asset decreases]
```

**Meaning:**
- Cash leaves bank account (credit = decrease in bank asset)
- Cash enters petty cash (debit = increase in cash asset)
- Total Assets unchanged (just moved from one form to another)

#### Step 2: Make Expense Payment from Petty Cash
**Example:** Buy office supplies Rp 50,000 cash

**Journal Entry:**
```
Dr  Office Supplies Expense (6400)  Rp 50,000  [Expense recorded]
    Cr  Petty Cash (1102)                      Rp 50,000  [Cash out]
```

**Meaning:**
- Expense recognized (debit = increase expense)
- Petty cash reduced (credit = decrease asset)
- This reduces profit and cash

---

## Database Structure

### 1. Chart of Accounts (chart_of_accounts)
Master list of all accounts used in the business

**Key Fields:**
- `code` - Account number (e.g., 1102)
- `name` - Account name (e.g., "Petty Cash")
- `account_type` - asset, liability, equity, revenue, expense
- `normal_balance` - debit or credit

### 2. Journal Entries (journal_entries)
Header for each accounting transaction

**Key Fields:**
- `entry_number` - Unique number (JE202601-0001)
- `entry_date` - Transaction date
- `source_module` - Where it came from (petty_cash, sales_invoice, etc.)
- `total_debit` - Sum of all debit lines (MUST equal total_credit)
- `total_credit` - Sum of all credit lines
- `is_posted` - Whether entry is final

### 3. Journal Entry Lines (journal_entry_lines)
The actual debit/credit entries

**Key Fields:**
- `journal_entry_id` - Links to header
- `line_number` - Order (1, 2, 3...)
- `account_id` - Which account
- `debit` - Debit amount (0 if credit side)
- `credit` - Credit amount (0 if debit side)
- `description` - Line description

### 4. Petty Cash Transactions (petty_cash_transactions)
Records petty cash movements

**Transaction Types:**
- `withdraw` - Get cash from bank
- `expense` - Pay expense from cash

---

## Critical Triggers & Automation

### 1. Auto-Calculate Journal Entry Totals
**Trigger:** `recalculate_journal_entry_totals()`

**When:** After INSERT/UPDATE/DELETE on journal_entry_lines

**What it does:**
```sql
1. Sum all debit amounts from lines
2. Sum all credit amounts from lines
3. Update journal_entries.total_debit
4. Update journal_entries.total_credit
```

**Why Critical:** Without this, reports show Rp 0 for all transactions!

### 2. Auto-Post Petty Cash to Journal
**Trigger:** `post_petty_cash_to_journal()`

**When:** After INSERT on petty_cash_transactions

**What it does:**
- Creates journal entry automatically
- For WITHDRAW: Dr Petty Cash / Cr Bank
- For EXPENSE: Dr Expense Account / Cr Petty Cash

### 3. Auto-Match Bank Statements
**Trigger:** `auto_match_bank_statement_line()`

**When:** After INSERT/UPDATE on bank_statement_lines

**What it does:**
- Matches bank withdrawals to petty cash transactions
- Matches bank debits to expenses
- Matches bank credits to receipts
- Sets reconciliation_status to 'matched'

---

## Integration Points

### Bank Reconciliation
1. Upload bank statement (PDF/Excel)
2. System parses transactions
3. Auto-matches with:
   - Petty cash withdrawals
   - Payment vouchers
   - Receipt vouchers
   - Expenses
4. Shows matched/unmatched status

### Financial Reports
All reports derive from journal_entry_lines:

1. **Trial Balance** - List all accounts with debit/credit balances
2. **Profit & Loss** - Revenue minus Expenses
3. **Balance Sheet** - Assets = Liabilities + Equity
4. **Account Ledger** - All transactions for one account
5. **Cash Flow** - Cash movements

---

## Data Integrity Rules

### 1. Balanced Entries (Enforced by Database)
```sql
CHECK (ABS(total_debit - total_credit) < 0.01)
```
Prevents unbalanced journal entries

### 2. Posted Entries Cannot Change
Once `is_posted = true`, entry is final (would need reversal entry)

### 3. Account Code Uniqueness
Each account has unique code (1102, 1110, etc.)

### 4. Chronological Posting
Entries should be in date order for accuracy

---

## Comparison with Tally

| Feature | Our System | Tally |
|---------|------------|-------|
| **Double Entry** | ✓ Full | ✓ Full |
| **Auto Journal Creation** | ✓ All modules | ✓ All modules |
| **Bank Reconciliation** | ✓ Auto-match | ✓ Manual/Auto |
| **Multi-Currency** | ✓ IDR/USD | ✓ Multi |
| **Inventory Integration** | ✓ Full FIFO | ✓ Multiple methods |
| **Tax Integration** | ✓ PPN/PPh | ✓ India GST |
| **Reports** | ✓ Real-time | ✓ Real-time |
| **Data Integrity** | ✓ Database constraints | ✓ Internal checks |

---

## Advanced Features Beyond Basic Accounting

### 1. Pharmaceutical-Specific
- Batch-wise costing
- Import duty allocation
- Regulatory document tracking
- Expiry date management

### 2. Indonesian Compliance
- PPN (VAT) Input/Output tracking
- PPh withholding tax
- Indonesian account names (Kas Kecil, etc.)
- Rupiah/USD dual currency

### 3. Integration
- Sales orders → Invoices → Journal
- Purchase orders → GRN → Journal
- Delivery challans → Stock → COGS
- Bank statements → Auto-reconciliation

---

## System Health Checks

### 1. Trial Balance Must Balance
```sql
SELECT
  SUM(debit) as total_debits,
  SUM(credit) as total_credits,
  SUM(debit) - SUM(credit) as difference
FROM journal_entry_lines
WHERE journal_entry_id IN (
  SELECT id FROM journal_entries WHERE is_posted = true
);
-- difference MUST be 0.00
```

### 2. All Journal Entries Balanced
```sql
SELECT COUNT(*) as unbalanced_entries
FROM journal_entries
WHERE ABS(total_debit - total_credit) >= 0.01;
-- MUST be 0
```

### 3. Inventory Valuation = Book Value
```sql
-- Stock value should match inventory account balance
```

---

## Best Practices

### 1. For Users
- Enter transactions daily
- Reconcile bank weekly
- Review reports monthly
- Backup database regularly

### 2. For Developers
- NEVER delete posted entries (use reversals)
- ALWAYS use triggers for journal creation
- ALWAYS validate balanced entries
- ALWAYS test with accounting principles

### 3. For Business
- Define clear approval workflows
- Separate duties (enter vs approve)
- Regular audits
- Period-end closing process

---

## Future Enhancements

1. **Budgeting Module** - Compare actuals vs budget
2. **Cost Centers** - Department-wise reporting
3. **Multi-Company** - Consolidation
4. **Audit Trail** - Every change logged
5. **Workflow Automation** - Approval routing
6. **AI Assistance** - Auto-categorize expenses
7. **Mobile App** - On-the-go expense recording

---

## Summary

This is a **COMPLETE DOUBLE-ENTRY ACCOUNTING SYSTEM** that:
- Follows international accounting standards
- Implements proper double-entry bookkeeping
- Has database-level integrity checks
- Auto-posts from all modules to journal
- Provides real-time reports
- Integrates with inventory, sales, purchases
- Complies with Indonesian regulations

**It is MORE POWERFUL than basic Tally** because:
- Industry-specific (pharmaceutical trading)
- Modern web-based interface
- Real-time collaboration
- Integrated CRM and inventory
- Cloud-based with auto-backups
- Customizable for your business needs
