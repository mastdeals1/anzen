import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
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
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("No authorization header");
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      throw new Error("Unauthorized");
    }

    const formData = await req.formData();
    const file = formData.get("file") as File;
    const bankAccountId = formData.get("bankAccountId") as string;

    if (!file || !bankAccountId) {
      throw new Error("Missing file or bankAccountId");
    }

    // Get bank account details for currency
    const { data: bankAccount, error: bankError } = await supabase
      .from("bank_accounts")
      .select("currency, account_number, bank_name")
      .eq("id", bankAccountId)
      .single();

    if (bankError || !bankAccount) {
      throw new Error("Bank account not found");
    }

    // Read PDF file as array buffer
    const arrayBuffer = await file.arrayBuffer();
    const uint8Array = new Uint8Array(arrayBuffer);
    
    // Extract text from PDF using basic text extraction
    const text = await extractTextFromPDF(uint8Array);
    
    // Parse BCA statement format
    const parsed = parseBCAStatement(text, bankAccount.currency);
    
    if (!parsed.transactions || parsed.transactions.length === 0) {
      throw new Error("No transactions found in PDF. Please check if this is a valid BCA statement.");
    }

    // Upload PDF to storage
    const fileName = `${bankAccountId}/${Date.now()}_${file.name}`;
    const { data: uploadData, error: uploadError } = await supabase.storage
      .from("bank-statements")
      .upload(fileName, file);

    if (uploadError) {
      console.error("Storage upload error:", uploadError);
      throw new Error("Failed to upload PDF");
    }

    const { data: { publicUrl } } = supabase.storage
      .from("bank-statements")
      .getPublicUrl(fileName);

    // Create upload record
    const { data: upload, error: uploadInsertError } = await supabase
      .from("bank_statement_uploads")
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
        status: "completed",
      })
      .select()
      .single();

    if (uploadInsertError) {
      console.error("Upload insert error:", uploadInsertError);
      throw new Error("Failed to create upload record");
    }

    // Insert transaction lines
    const lines = parsed.transactions.map((txn) => ({
      upload_id: upload.id,
      bank_account_id: bankAccountId,
      transaction_date: txn.date,
      description: txn.description,
      reference: "",
      branch_code: txn.branchCode,
      debit_amount: txn.debitAmount,
      credit_amount: txn.creditAmount,
      running_balance: txn.balance,
      currency: bankAccount.currency,
      reconciliation_status: "unmatched",
      created_by: user.id,
    }));

    const { error: linesError } = await supabase
      .from("bank_statement_lines")
      .insert(lines);

    if (linesError) {
      console.error("Lines insert error:", linesError);
      throw new Error("Failed to insert transactions");
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
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("Error parsing BCA statement:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to parse PDF" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

async function extractTextFromPDF(pdfData: Uint8Array): Promise<string> {
  // Simple PDF text extraction
  // Convert bytes to string and extract text between content streams
  const decoder = new TextDecoder("latin1");
  let text = decoder.decode(pdfData);
  
  // Extract text from PDF content streams
  const contentRegex = /BT\s+(.+?)\s+ET/gs;
  const matches = text.matchAll(contentRegex);
  
  let extractedText = "";
  for (const match of matches) {
    // Extract text between parentheses
    const textMatches = match[1].matchAll(/\(([^)]+)\)/g);
    for (const textMatch of textMatches) {
      extractedText += textMatch[1] + " ";
    }
    extractedText += "\n";
  }
  
  return extractedText;
}

function parseBCAStatement(text: string, currency: string) {
  const lines = text.split("\n");
  
  // Extract metadata
  let period = "";
  let accountNumber = "";
  let openingBalance = 0;
  let closingBalance = 0;
  
  // Find period (e.g., "NOVEMBER 2025")
  for (const line of lines) {
    if (line.includes("PERIODE")) {
      const periodMatch = line.match(/:\s*([A-Z]+\s+\d{4})/);
      if (periodMatch) period = periodMatch[1];
    }
    if (line.includes("NO. REKENING") || line.includes("NO.REKENING")) {
      const accMatch = line.match(/:\s*([\d]+)/);
      if (accMatch) accountNumber = accMatch[1];
    }
    if (line.includes("SALDO AWAL")) {
      const balMatch = line.match(/([\d,\.]+)/);
      if (balMatch) {
        openingBalance = parseFloat(balMatch[1].replace(/,/g, ""));
      }
    }
    if (line.includes("SALDO AKHIR")) {
      const balMatch = line.match(/([\d,\.]+)/);
      if (balMatch) {
        closingBalance = parseFloat(balMatch[1].replace(/,/g, ""));
      }
    }
  }

  // Parse period to dates
  let startDate = "";
  let endDate = "";
  if (period) {
    const [monthName, year] = period.split(" ");
    const monthMap: Record<string, string> = {
      JANUARY: "01", FEBRUARY: "02", MARCH: "03", APRIL: "04",
      MAY: "05", JUNE: "06", JULY: "07", AUGUST: "08",
      SEPTEMBER: "09", OCTOBER: "10", NOVEMBER: "11", DECEMBER: "12",
    };
    const month = monthMap[monthName.toUpperCase()] || "01";
    startDate = `${year}-${month}-01`;
    const lastDay = new Date(parseInt(year), parseInt(month), 0).getDate();
    endDate = `${year}-${month}-${String(lastDay).padStart(2, "0")}`;
  }

  // Parse transactions
  const transactions: ParsedTransaction[] = [];
  const txnRegex = /(\d{2}\/\d{2})\s+(.+?)\s+(\d{4})?\s+([\d,.]+)\s+(DB|CR)?\s*([\d,.]+)?/g;
  
  for (const line of lines) {
    // Look for date pattern DD/MM
    const dateMatch = line.match(/^(\d{2}\/\d{2})/);
    if (!dateMatch) continue;
    
    const dateStr = dateMatch[1];
    const [day, month] = dateStr.split("/");
    const year = period.split(" ")[1] || new Date().getFullYear().toString();
    const fullDate = `${year}-${month}-${day}`;
    
    // Extract components
    let description = "";
    let branchCode = "";
    let amount = 0;
    let isDebit = false;
    let balance: number | null = null;
    
    // Parse the line
    const parts = line.trim().split(/\s+/);
    let i = 1; // Skip date
    
    // Collect description until we hit a number
    const descParts: string[] = [];
    while (i < parts.length) {
      if (/^\d{4}$/.test(parts[i])) {
        branchCode = parts[i];
        i++;
        break;
      } else if (/^[\d,.]+$/.test(parts[i])) {
        break;
      } else {
        descParts.push(parts[i]);
        i++;
      }
    }
    description = descParts.join(" ");
    
    // Next should be amount
    if (i < parts.length && /^[\d,.]+$/.test(parts[i])) {
      amount = parseFloat(parts[i].replace(/,/g, ""));
      i++;
    }
    
    // Check for DB indicator
    if (i < parts.length && parts[i] === "DB") {
      isDebit = true;
      i++;
    }
    
    // Last number is balance
    if (i < parts.length && /^[\d,.]+$/.test(parts[i])) {
      balance = parseFloat(parts[i].replace(/,/g, ""));
    }
    
    if (amount > 0) {
      transactions.push({
        date: fullDate,
        description: description.trim(),
        branchCode,
        debitAmount: isDebit ? amount : 0,
        creditAmount: isDebit ? 0 : amount,
        balance,
      });
    }
  }

  const totalDebits = transactions.reduce((sum, t) => sum + t.debitAmount, 0);
  const totalCredits = transactions.reduce((sum, t) => sum + t.creditAmount, 0);

  return {
    period,
    startDate,
    endDate,
    openingBalance,
    closingBalance,
    totalDebits,
    totalCredits,
    transactions,
  };
}
