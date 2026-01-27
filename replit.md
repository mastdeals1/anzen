# Pharma Raw Material ERP System

## Overview
A React + TypeScript ERP (Enterprise Resource Planning) application for pharmaceutical raw material trading. Built with Vite and styled with Tailwind CSS.

## Tech Stack
- **Frontend**: React 18 with TypeScript
- **Build Tool**: Vite 5
- **Styling**: Tailwind CSS
- **Backend**: Supabase (database, auth, and edge functions)
- **Icons**: Lucide React
- **PDF Generation**: jsPDF + html2canvas
- **Rich Text Editor**: React Quill
- **Excel Support**: xlsx

## Project Structure
```
src/
├── components/        # UI components organized by feature
│   ├── commandCenter/ # Command center dashboard components
│   ├── crm/          # CRM and customer management
│   ├── finance/      # Financial management components
│   ├── settings/     # Application settings
│   └── tasks/        # Task management
├── contexts/         # React contexts (Auth, Language, Navigation)
├── data/             # Static data files
├── i18n/             # Internationalization/translations
├── lib/              # Library configurations (Supabase client)
├── pages/            # Page components
├── services/         # Business logic services
├── types/            # TypeScript type definitions
└── utils/            # Utility functions
supabase/
├── functions/        # Supabase Edge Functions
└── migrations/       # Database migrations
```

## Running the Application
- Development server runs on port 5000
- Command: `npm run dev`

## Deployment
- Static site deployment using `npm run build`
- Output directory: `dist`

## Environment
- Requires Supabase credentials (SUPABASE_URL, SUPABASE_ANON_KEY)

## Finance Module Logic (Strict Separation)

### Core Rules
1. **Bank-paid expenses** → `finance_expenses` table → Participates in bank reconciliation
2. **Cash-paid expenses** → `petty_cash_transactions` table → Reporting ONLY, NEVER in bank reconciliation
3. **Fund transfers** → Money movement between accounts (not expenses)

### Component Responsibilities
- **ExpenseManager**: Bank expenses only (bank_transfer, check, giro, other payment methods)
- **PettyCashManager**: Cash expenses only (for internal cash transactions)
- **BankReconciliationEnhanced**: Matches bank statements with bank expenses, purchase payments, sales receipts, and fund transfers
- **FundTransferManager**: Handles Bank↔Cash, Cash↔Bank, Bank↔Bank transfers

### Important Design Decisions
- NO bidirectional foreign keys between `petty_cash_transactions` and `finance_expenses`
- Petty cash transactions never appear in bank reconciliation
- ExpenseManager does not offer "cash" as a payment method
- Fund transfers are money movement, not recorded as expenses
