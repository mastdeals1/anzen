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
    console.log('[DEBUG] Extracted text length:', text.length);
    console.log('[DEBUG] First 1000 chars:', text.substring(0, 1000));
    console.log('[DEBUG] Contains SALDO:', text.includes('SALDO'));
    console.log('[DEBUG] Contains date pattern:', /\d{2}\/\d{2}/.test(text));
    console.log('[DEBUG] Sample dates found:', text.match(/\d{2}\/\d{2}/g)?.slice(0, 5));
    
    const parsed = parseBCAStatement(text, bankAccount.currency);
    console.log('[DEBUG] Parsed result:', JSON.stringify({
      period: parsed.period,
      transactionCount: parsed.transactions.length,
      firstTransaction: parsed.transactions[0],
      lastTransaction: parsed.transactions[parsed.transactions.length - 1]
    }, null, 2));
    
    if (!parsed.transactions || parsed.transactions.length === 0) {
      // Save debug info
      const debugFile = `debug/${Date.now()}_extract.txt`;
      await supabase.storage.from('bank-statements').upload(debugFile, text);
      
      throw new Error(`No transactions parsed. Text length: ${text.length}. Debug file saved. Please contact support.`);
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
    console.error('[ERROR] Parse error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Failed to parse PDF' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function extractTextFromPDF(pdfData: Uint8Array): Promise<string> {
  const decoder = new TextDecoder('utf-8', { fatal: false });
  const rawText = decoder.decode(pdfData);
  const parts: string[] = [];

  // Method 1: Extract from BT...ET blocks
  const textObjectRegex = /BT\s+([\s\S]+?)\s+ET/g;
  for (const match of rawText.matchAll(textObjectRegex)) {
    const content = match[1];
    for (const strMatch of content.matchAll(/[\(\<]([^\)\>]+)[\)\>]/g)) {
      let text = strMatch[1];
      text = text.replace(/\\([\\()rnt])/g, (_, char) => {
        if (char === 'n') return ' ';
        if (char === 'r') return '';
        if (char === 't') return ' ';
        if (char === '\\') return '\\';
        if (char === '(') return '(';
        if (char === ')') return ')';
        return char;
      });
      parts.push(text);
    }
  }

  return parts.join(' ');
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
  
  // Split into potential transaction chunks
  const chunks = text.split(/(?=\d{2}\/\d{2}\s)/);
  console.log(`[DEBUG] Found ${chunks.length} chunks`);
  
  for (const chunk of chunks) {
    const dateMatch = chunk.match(/^(\d{2})\/(\d{2})/);
    if (!dateMatch) continue;
    
    const day = dateMatch[1];
    const month = dateMatch[2];
    const dayNum = parseInt(day);
    const monthNumParsed = parseInt(month);
    
    if (dayNum > 31 || monthNumParsed > 12 || dayNum < 1 || monthNumParsed < 1) continue;
    
    // Skip headers
    if (chunk.match(/TANGGAL|KETERANGAN|MUTASI|SALDO AWAL/i)) continue;
    
    // Try to find amounts - look for patterns like: 1.234.567,89 or 1234567.89
    const amountMatches = chunk.match(/([\d,\.]+(?:,\d{2})?)/g);
    if (!amountMatches || amountMatches.length === 0) continue;
    
    // Filter out the date itself
    const amounts = amountMatches
      .filter(a => !/^\d{2}$/.test(a))
      .map(a => parseAmount(a))
      .filter(a => a >= 1 && a < 100000000000);
    
    if (amounts.length === 0) continue;
    
    // Extract description (everything between date and first amount)
    let description = chunk.substring(5).trim();
    for (const amountStr of amountMatches) {
      const idx = description.indexOf(amountStr);
      if (idx > 0) {
        description = description.substring(0, idx).trim();
        break;
      }
    }
    
    description = description.replace(/[^A-Za-z0-9\s\-\/\.]/g, ' ').trim();
    if (description.length < 3) description = 'Transaction';
    
    // Check for CR indicator
    const isCredit = chunk.includes(' CR ');
    const amount = amounts[0];
    const balance = amounts.length > 1 ? amounts[amounts.length - 1] : null;
    
    const fullDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
    
    transactions.push({
      date: fullDate,
      description: description.substring(0, 500),
      branchCode: '',
      debitAmount: isCredit ? 0 : amount,
      creditAmount: isCredit ? amount : 0,
      balance,
    });
  }

  const totalDebits = transactions.reduce((sum, t) => sum + t.debitAmount, 0);
  const totalCredits = transactions.reduce((sum, t) => sum + t.creditAmount, 0);

  console.log(`[RESULT] ${transactions.length} transactions, DR: ${totalDebits}, CR: ${totalCredits}`);

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
  if (!str) return 0;
  
  let cleaned = str.trim().replace(/[^0-9,\.]/g, '');
  
  const dotCount = (cleaned.match(/\./g) || []).length;
  const commaCount = (cleaned.match(/,/g) || []).length;
  
  // Indonesian: 1.234.567,89 (dots = thousands, comma = decimal)
  // US: 1,234,567.89 (commas = thousands, dot = decimal)
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
