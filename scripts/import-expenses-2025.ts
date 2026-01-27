import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

// Get directory name in ES module
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env file
const envPath = path.join(__dirname, '../.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars: { [key: string]: string } = {};

envContent.split('\n').forEach(line => {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const [key, ...valueParts] = trimmed.split('=');
    if (key && valueParts.length > 0) {
      envVars[key.trim()] = valueParts.join('=').trim();
    }
  }
});

const supabaseUrl = envVars['VITE_SUPABASE_URL'];
const supabaseServiceKey = envVars['SUPABASE_SERVICE_ROLE_KEY'];

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('Missing Supabase credentials in .env file');
  console.error('Make sure VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set');
  process.exit(1);
}

// Use service role key to bypass RLS
const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

interface ExpenseRow {
  date: string;
  subject: string;
  amount: number;
}

// Parse CSV
function parseCSV(content: string): ExpenseRow[] {
  const lines = content.split('\n').slice(1); // Skip header
  const expenses: ExpenseRow[] = [];

  for (const line of lines) {
    if (!line.trim()) continue;

    const parts = line.split(';');
    if (parts.length < 3) continue;

    const dateStr = parts[0].trim();
    const subject = parts[1].trim();
    const amountStr = parts[2].trim().replace(/,/g, '').replace(/\s/g, '');

    if (!dateStr || !subject || !amountStr) continue;

    const amount = parseFloat(amountStr);
    if (isNaN(amount)) continue;

    expenses.push({ date: dateStr, subject, amount });
  }

  return expenses;
}

// Categorize expense based on subject
function categorizeExpense(subject: string): {
  category: string;
  type: string;
  paymentMethod: string;
} {
  const subjectLower = subject.toLowerCase();

  // Determine category
  let category = 'other';
  let type = 'general';

  if (subjectLower.includes('salary')) {
    category = 'staff_salaries';
    type = 'staff';
  } else if (subjectLower.includes('internet') || subjectLower.includes('telfon') ||
             subjectLower.includes('telephone') || subjectLower.includes('electricty') ||
             subjectLower.includes('electricity') || subjectLower.includes('water') ||
             subjectLower.includes('security')) {
    category = 'utilities';
    type = 'operations';
  } else if (subjectLower.includes('rent')) {
    category = 'office_admin';
    type = 'admin';
  } else if (subjectLower.includes('grab') || subjectLower.includes('transport') ||
             subjectLower.includes('driver') || subjectLower.includes('trip') ||
             subjectLower.includes('expenses trip')) {
    category = 'travel_conveyance';
    type = 'operations';
  } else if (subjectLower.includes('tax consultant')) {
    category = 'office_admin';
    type = 'admin';
  } else if (subjectLower.includes('courier')) {
    category = 'other';
    type = 'operations';
  } else if (subjectLower.includes('cdob') || subjectLower.includes('inspection')) {
    category = 'other';
    type = 'operations';
  }

  // Determine payment method
  // (B) = Bank Transfer
  // � or cash symbol = Cash
  const hasB = subject.includes('(B)');
  const hasCash = subject.includes('�') || subject.includes('(T)');

  const paymentMethod = hasB ? 'bank_transfer' : (hasCash ? 'cash' : 'bank_transfer');

  return { category, type, paymentMethod };
}

// Parse date like "01-Aug" to full date in 2025
function parseDate(dateStr: string): string {
  const monthMap: { [key: string]: string } = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
    'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
    'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12'
  };

  const parts = dateStr.split('-');
  if (parts.length !== 2) return new Date().toISOString().split('T')[0];

  const day = parts[0].padStart(2, '0');
  const monthAbbr = parts[1].toLowerCase();
  const month = monthMap[monthAbbr] || '01';

  return `2025-${month}-${day}`;
}

// Get or create default bank account
async function getDefaultBankAccount(): Promise<string | null> {
  const { data, error } = await supabase
    .from('bank_accounts')
    .select('id')
    .eq('currency', 'IDR')
    .limit(1)
    .single();

  if (error || !data) {
    console.log('No default bank account found, will use null');
    return null;
  }

  return data.id;
}

// Main import function
async function importExpenses() {
  console.log('Starting expense import for 2025...\n');

  // Read CSV file
  const csvPath = path.join(__dirname, '../src/data/exptiljun.csv');
  const csvContent = fs.readFileSync(csvPath, 'utf-8');

  // Parse expenses
  const expenses = parseCSV(csvContent);
  console.log(`Parsed ${expenses.length} expenses from CSV\n`);

  // Get default bank account
  const defaultBankAccountId = await getDefaultBankAccount();

  let successCount = 0;
  let errorCount = 0;

  for (const expense of expenses) {
    const { category, type, paymentMethod } = categorizeExpense(expense.subject);
    const expenseDate = parseDate(expense.date);

    const expenseData = {
      expense_date: expenseDate,
      amount: expense.amount,
      expense_category: category,
      expense_type: type,
      description: expense.subject,
      payment_method: paymentMethod,
      bank_account_id: paymentMethod === 'bank_transfer' ? defaultBankAccountId : null,
    };

    console.log(`Importing: ${expense.date} - ${expense.subject} - Rp ${expense.amount.toLocaleString()}`);
    console.log(`  Category: ${category}, Type: ${type}, Method: ${paymentMethod}`);

    const { error } = await supabase
      .from('finance_expenses')
      .insert(expenseData);

    if (error) {
      console.error(`  ❌ Error: ${error.message}\n`);
      errorCount++;
    } else {
      console.log(`  ✅ Imported successfully\n`);
      successCount++;
    }
  }

  console.log('\n=== Import Summary ===');
  console.log(`Total expenses: ${expenses.length}`);
  console.log(`Successfully imported: ${successCount}`);
  console.log(`Failed: ${errorCount}`);
}

// Run the import
importExpenses().catch(console.error);
