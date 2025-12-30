import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ParsedTransaction {
  date: string;
  description: string;
  branchCode: string;
  debitAmount: number;
  creditAmount: number;
  balance: number | null;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();
    if (userError || !user) {
      throw new Error('Unauthorized');
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const formData = await req.formData();
    const file = formData.get('file') as File;
    const bankAccountId = formData.get('bankAccountId') as string;

    if (!file || !bankAccountId) {
      throw new Error('Missing file or bankAccountId');
    }

    const { data: bankAccount, error: bankError } = await supabase
      .from('bank_accounts')
      .select('currency, account_number, bank_name')
      .eq('id', bankAccountId)
      .single();

    if (bankError || !bankAccount) {
      throw new Error('Bank account not found');
    }

    const arrayBuffer = await file.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);
    
    const text = await extractTextFromPDF(uint8Array);
    console.log('Extracted text length:', text.length);
    console.log('Sample:', text.substring(0, 500));
    
    const parsed = parseBCAStatement(text, bankAccount.currency);
    
    if (!parsed.transactions || parsed.transactions.length === 0) {
      throw new Error('No transactions found in PDF. Please check if this is a valid BCA statement.');
    }

    const fileName = `${bankAccountId}/${Date.now()}_${file.name}`;
    const { error: uploadError } = await supabase.storage
      .from('bank-statements')
      .upload(fileName, file);

    if (uploadError) {
      throw new Error('Failed to upload PDF: ' + uploadError.message);
    }

    const { data: { publicUrl } } = supabase.storage
      .from('bank-statements')
      .getPublicUrl(fileName);

    const { data: upload, error: uploadInsertError } = await supabase
      .from('bank_statement_uploads')
      .insert({
        bank_account_id: bankAccountId,
        statement_period: parsed.period,
        statement_start_date: parsed.startDate,
        statement_end_date: parsed.endDate,
        currency: bankAccount.currency,
        opening_balance: parsed.openingBalance,
        closing_balance: parsed.closingBalance,
        total_credits: parsed.totalCredits,
        total_debits: parsed.totalDebits,
        transaction_count: parsed.transactions.length,
        file_url: publicUrl,
        uploaded_by: user.id,
        status: 'completed',
      })
      .select()
      .single();

    if (uploadInsertError) {
      throw new Error('Failed to create upload record: ' + uploadInsertError.message);
    }

    const lines = parsed.transactions.map((txn) => ({
      upload_id: upload.id,
      bank_account_id: bankAccountId,
      transaction_date: txn.date,
      description: txn.description,
      reference: '',
      branch_code: txn.branchCode,
      debit_amount: txn.debitAmount,
      credit_amount: txn.creditAmount,
      running_balance: txn.balance,
      currency: bankAccount.currency,
      reconciliation_status: 'unmatched',
      created_by: user.id,
    }));

    const { error: linesError } = await supabase
      .from('bank_statement_lines')
      .insert(lines);

    if (linesError) {
      throw new Error('Failed to insert transactions: ' + linesError.message);
    }

    return new Response(
      JSON.stringify({
        success: true,
        uploadId: upload.id,
        transactionCount: parsed.transactions.length,
        period: parsed.period,
        openingBalance: parsed.openingBalance,
        closingBalance: parsed.closingBalance,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error: any) {
    console.error('Error parsing BCA statement:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Failed to parse PDF' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function extractTextFromPDF(pdfData: Uint8Array): Promise<string> {
  const decoder = new TextDecoder('utf-8', { fatal: false });
  const rawText = decoder.decode(pdfData);
  let extractedText = '';

  const textObjectRegex = /BT\s+([\s\S]+?)\s+ET/g;
  for (const match of rawText.matchAll(textObjectRegex)) {
    const content = match[1];
    for (const strMatch of content.matchAll(/[\(\<]([^\)\>]+)[\)\>]/g)) {
      let text = strMatch[1];
      text = text.replace(/\\([\\()rnt])/g, (_, char) => {
        switch (char) {
          case 'n': return ' ';
          case 'r': return '';
          case 't': return ' ';
          case '\\': return '\\';
          case '(': return '(';
          case ')': return ')';
          default: return char;
        }
      });
      extractedText += text + ' ';
    }
  }

  return extractedText;
}

function parseBCAStatement(text: string, currency: string) {
  text = text.replace(/\s+/g, ' ');

  let period = '';
  let openingBalance = 0;
  let closingBalance = 0;

  const periodMatch = text.match(/PERIODE[:\s]+(JANUARI|FEBRUARI|MARET|APRIL|MEI|JUNI|JULI|AGUSTUS|SEPTEMBER|OKTOBER|NOVEMBER|DESEMBER)[\s]+(\d{4})/i);
  if (periodMatch) {
    period = periodMatch[1] + ' ' + periodMatch[2];
  }

  const openingMatch = text.match(/SALDO[\s]+AWAL[:\s]*([\d,\.]+)/i);
  if (openingMatch) {
    openingBalance = parseAmount(openingMatch[1]);
  }

  const closingMatch = text.match(/SALDO[\s]+AKHIR[:\s]*([\d,\.]+)/i);
  if (closingMatch) {
    closingBalance = parseAmount(closingMatch[1]);
  }

  console.log('Period:', period, 'Opening:', openingBalance, 'Closing:', closingBalance);

  let startDate = '';
  let endDate = '';
  let year = new Date().getFullYear().toString();
  let monthNum = '01';
  
  if (period) {
    const parts = period.split(/\s+/);
    const yearPart = parts.find(p => /^\d{4}$/.test(p));
    const monthName = parts.find(p => /^[A-Z]+$/i.test(p));
    
    if (yearPart) year = yearPart;
    
    if (monthName) {
      const monthMap: Record<string, string> = {
        JANUARI: '01', FEBRUARI: '02', MARET: '03', APRIL: '04',
        MEI: '05', JUNI: '06', JULI: '07', AGUSTUS: '08',
        SEPTEMBER: '09', OKTOBER: '10', NOVEMBER: '11', DESEMBER: '12',
      };
      monthNum = monthMap[monthName.toUpperCase()] || '01';
      startDate = `${year}-${monthNum}-01`;
      const lastDay = new Date(parseInt(year), parseInt(monthNum), 0).getDate();
      endDate = `${year}-${monthNum}-${String(lastDay).padStart(2, '0')}`;
    }
  }

  const transactions: ParsedTransaction[] = [];
  
  // Pattern: DD/MM followed by description, amount, maybe DB/CR, maybe balance
  // More flexible - just look for DD/MM anywhere in the text
  const linePattern = /(\d{2})\/(\d{2})[\s]+([^\d]+?)[\s]+(\d{1,3}(?:[,\.]\d{3})*(?:[,\.]\d{2})?)[\s]*(DB|CR)?[\s]*(\d{1,3}(?:[,\.]\d{3})*(?:[,\.]\d{2})?)?/gi;
  
  let match;
  while ((match = linePattern.exec(text)) !== null) {
    const day = match[1];
    const month = match[2];
    let desc = match[3].trim();
    const amountStr = match[4];
    const indicator = match[5];
    const balanceStr = match[6];

    // Validate date
    const dayNum = parseInt(day);
    const monthNumParsed = parseInt(month);
    
    if (dayNum > 31 || monthNumParsed > 12 || dayNum < 1 || monthNumParsed < 1) {
      continue;
    }

    // Skip header lines
    if (desc.match(/TANGGAL|KETERANGAN|MUTASI|SALDO/i)) {
      continue;
    }

    // Clean description
    desc = desc.replace(/[^A-Za-z0-9\s\-\/\.]/g, ' ').trim();
    if (desc.length < 3) {
      desc = 'Transaction';
    }

    const fullDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
    const amount = parseAmount(amountStr);
    const balance = balanceStr ? parseAmount(balanceStr) : null;
    const isDebit = !indicator || indicator.toUpperCase() === 'DB';

    if (amount > 0 && amount < 1000000000000) {
      transactions.push({
        date: fullDate,
        description: desc.substring(0, 500),
        branchCode: '',
        debitAmount: isDebit ? amount : 0,
        creditAmount: isDebit ? 0 : amount,
        balance,
      });
    }
  }

  const totalDebits = transactions.reduce((sum, t) => sum + t.debitAmount, 0);
  const totalCredits = transactions.reduce((sum, t) => sum + t.creditAmount, 0);

  console.log(`Parsed: ${transactions.length} transactions, DR: ${totalDebits.toFixed(2)}, CR: ${totalCredits.toFixed(2)}`);

  return {
    period,
    startDate: startDate || `${year}-01-01`,
    endDate: endDate || `${year}-12-31`,
    openingBalance,
    closingBalance,
    totalDebits,
    totalCredits,
    transactions,
  };
}

function parseAmount(str: string): number {
  let cleaned = str.trim().replace(/[^0-9,\.]/g, '');
  
  const dotCount = (cleaned.match(/\./g) || []).length;
  const commaCount = (cleaned.match(/,/g) || []).length;
  
  if (dotCount > 1) {
    cleaned = cleaned.replace(/\./g, '').replace(',', '.');
  } else if (commaCount > 1) {
    cleaned = cleaned.replace(/,/g, '');
  } else if (dotCount === 1 && commaCount === 1) {
    cleaned = cleaned.replace(/\./g, '').replace(',', '.');
  } else if (commaCount === 1 && dotCount === 0) {
    cleaned = cleaned.replace(',', '.');
  }
  
  return parseFloat(cleaned) || 0;
}
