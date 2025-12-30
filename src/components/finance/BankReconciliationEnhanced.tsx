import { useEffect, useState, useRef } from 'react';
import { supabase } from '../../lib/supabase';
import { Upload, RefreshCw, CheckCircle2, AlertCircle, XCircle, Plus, Calendar, Landmark, FileText, DollarSign } from 'lucide-react';
import * as XLSX from 'xlsx';
import { Modal } from '../Modal';

interface BankAccount {
  id: string;
  account_name: string;
  bank_name: string;
  account_number: string;
  currency: string;
}

interface StatementLine {
  id: string;
  date: string;
  description: string;
  reference: string;
  debit: number;
  credit: number;
  balance: number;
  currency: string;
  status: 'matched' | 'suggested' | 'unmatched' | 'recorded';
  matchedEntry?: string;
}

interface BankReconciliationEnhancedProps {
  canManage: boolean;
}

export function BankReconciliationEnhanced({ canManage }: BankReconciliationEnhancedProps) {
  const [bankAccounts, setBankAccounts] = useState<BankAccount[]>([]);
  const [selectedBank, setSelectedBank] = useState<string>('');
  const [selectedAccount, setSelectedAccount] = useState<BankAccount | null>(null);
  const [statementLines, setStatementLines] = useState<StatementLine[]>([]);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [activeFilter, setActiveFilter] = useState<'all' | 'matched' | 'suggested' | 'unmatched'>('all');
  const [dateRange, setDateRange] = useState({
    start: new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0],
  });
  const [recordingLine, setRecordingLine] = useState<StatementLine | null>(null);
  const [recordModal, setRecordModal] = useState(false);
  const [expenses, setExpenses] = useState<any[]>([]);
  const [linkToExpense, setLinkToExpense] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [ocrError, setOcrError] = useState<{message: string; canUseOCR: boolean; suggestions: string[]} | null>(null);
  const [ocrPreview, setOcrPreview] = useState<any | null>(null);
  const [lastUploadedFile, setLastUploadedFile] = useState<File | null>(null);

  const expenseCategories = [
    { value: 'duty_customs', label: 'Duty & Customs (BM)', type: 'import' },
    { value: 'ppn_import', label: 'PPN Import', type: 'import' },
    { value: 'pph_import', label: 'PPh Import', type: 'import' },
    { value: 'freight_import', label: 'Freight (Import)', type: 'import' },
    { value: 'clearing_forwarding', label: 'Clearing & Forwarding', type: 'import' },
    { value: 'port_charges', label: 'Port Charges', type: 'import' },
    { value: 'container_handling', label: 'Container Handling', type: 'import' },
    { value: 'transport_import', label: 'Transport (Import)', type: 'import' },
    { value: 'delivery_sales', label: 'Delivery/Sales', type: 'sales' },
    { value: 'loading_sales', label: 'Loading', type: 'sales' },
    { value: 'warehouse_rent', label: 'Warehouse Rent', type: 'admin' },
    { value: 'utilities', label: 'Utilities', type: 'admin' },
    { value: 'salary', label: 'Salary', type: 'admin' },
    { value: 'office_admin', label: 'Office & Admin', type: 'admin' },
  ];

  useEffect(() => {
    loadBankAccounts();
    loadExpenses();
  }, []);

  useEffect(() => {
    if (selectedBank) {
      const account = bankAccounts.find(b => b.id === selectedBank);
      setSelectedAccount(account || null);
      loadStatementLines();
    }
  }, [selectedBank, dateRange]);

  const loadBankAccounts = async () => {
    try {
      const { data, error } = await supabase
        .from('bank_accounts')
        .select('id, account_name, bank_name, account_number, currency')
        .eq('is_active', true)
        .order('account_name');
      if (error) throw error;
      setBankAccounts(data || []);
      if (data && data.length > 0) {
        setSelectedBank(data[0].id);
      }
    } catch (err) {
      console.error('Error loading bank accounts:', err);
    }
  };

  const loadExpenses = async () => {
    try {
      const { data, error } = await supabase
        .from('finance_expenses')
        .select(`
          id,
          expense_date,
          description,
          amount,
          expense_category,
          voucher_number
        `)
        .order('expense_date', { ascending: false })
        .limit(200);

      if (error) throw error;
      setExpenses(data || []);
    } catch (err) {
      console.error('Error loading expenses:', err);
    }
  };

  const loadStatementLines = async () => {
    if (!selectedBank) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('bank_statement_lines')
        .select('*')
        .eq('bank_account_id', selectedBank)
        .gte('transaction_date', dateRange.start)
        .lte('transaction_date', dateRange.end)
        .order('transaction_date', { ascending: false });

      if (error) throw error;

      const lines: StatementLine[] = (data || []).map(row => ({
        id: row.id,
        date: row.transaction_date,
        description: row.description || '',
        reference: row.reference || '',
        debit: row.debit_amount || 0,
        credit: row.credit_amount || 0,
        balance: row.running_balance || 0,
        currency: row.currency || 'IDR',
        status: row.reconciliation_status || 'unmatched',
        matchedEntry: row.matched_entry_id,
      }));
      setStatementLines(lines);
    } catch (err) {
      console.error('Error loading statement lines:', err);
      setStatementLines([]);
    } finally {
      setLoading(false);
    }
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !selectedBank || !selectedAccount) return;

    setUploading(true);
    try {
      if (file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf')) {
        await handlePDFUpload(file);
      } else {
        await handleExcelUpload(file);
      }
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handlePDFUpload = async (file: File, useOCR = false, previewOnly = false) => {
    try {
      setUploading(true);
      setOcrError(null);

      const formData = new FormData();
      formData.append('file', file);
      formData.append('bankAccountId', selectedBank);
      if (useOCR) {
        formData.append('useOCR', 'true');
      }
      if (previewOnly) {
        formData.append('previewOnly', 'true');
      }

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/parse-bca-statement`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${session.access_token}`,
          },
          body: formData,
        }
      );

      const result = await response.json();

      if (!response.ok) {
        if (result.canUseOCR) {
          setOcrError({
            message: result.error,
            canUseOCR: true,
            suggestions: result.suggestions
          });
          setLastUploadedFile(file);
        } else {
          throw new Error(result.error || 'Failed to parse PDF');
        }
        return;
      }

      if (result.preview) {
        setOcrPreview(result);
        return;
      }

      const ocrUsed = result.usedOCR ? ' (via OCR)' : '';
      alert(`✅ Successfully imported ${result.transactionCount} transactions from ${result.period}${ocrUsed}`);
      setOcrError(null);
      setLastUploadedFile(null);
      await autoMatchTransactions();
      loadStatementLines();
    } catch (error: any) {
      console.error('PDF upload error:', error);
      alert(`❌ Failed to parse PDF: ${error.message}`);
    } finally {
      setUploading(false);
    }
  };

  const handleRunOCR = async () => {
    if (!lastUploadedFile) return;
    setUploading(true);
    setOcrError(null);
    try {
      await handlePDFUpload(lastUploadedFile, true, true);
    } catch (error: any) {
      alert(`❌ OCR failed: ${error.message}`);
      setUploading(false);
    }
  };

  const handleConfirmOCRPreview = async () => {
    if (!lastUploadedFile) return;
    setOcrPreview(null);
    setUploading(true);
    try {
      await handlePDFUpload(lastUploadedFile, true, false);
    } catch (error: any) {
      alert(`❌ Failed to save: ${error.message}`);
    } finally {
      setUploading(false);
    }
  };

  const handleExcelUpload = async (file: File) => {
    try {
      const reader = new FileReader();
      reader.onload = async (event) => {
        try {
          const data = event.target?.result;
          const workbook = XLSX.read(data, { type: 'binary' });
          const sheetName = workbook.SheetNames[0];
          const worksheet = workbook.Sheets[sheetName];
          const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 }) as any[][];

          console.log('📊 Raw Excel data rows:', jsonData.length);
          console.log('📋 First 10 rows:', jsonData.slice(0, 10));

          const { lines, metadata } = parseStatementDataWithMetadata(jsonData);

          console.log('✅ Parsed lines:', lines.length);
          console.log('📈 Metadata:', metadata);
          if (lines.length > 0) {
            console.log('🔍 First 3 transactions:', lines.slice(0, 3));
          }

          if (lines.length === 0) {
            alert('❌ No valid transactions found in the file. Check browser console (F12) for details.');
            return;
          }

          const { data: uploadRecord, error: uploadError } = await supabase
            .from('bank_statement_uploads')
            .insert({
              bank_account_id: selectedBank,
              statement_period: metadata.period || `${new Date().toLocaleString('default', { month: 'long' })} ${new Date().getFullYear()}`,
              statement_start_date: metadata.startDate || dateRange.start,
              statement_end_date: metadata.endDate || dateRange.end,
              currency: selectedAccount?.currency || 'IDR',
              opening_balance: metadata.openingBalance || 0,
              closing_balance: metadata.closingBalance || lines[lines.length - 1]?.balance || 0,
              total_debits: metadata.totalDebits || lines.reduce((sum, l) => sum + l.debit, 0),
              total_credits: metadata.totalCredits || lines.reduce((sum, l) => sum + l.credit, 0),
              transaction_count: lines.length,
              status: 'completed',
            })
            .select()
            .single();

          if (uploadError) throw uploadError;

          const { data: { user } } = await supabase.auth.getUser();

          const insertData = lines.map(line => ({
            upload_id: uploadRecord.id,
            bank_account_id: selectedBank,
            transaction_date: line.date,
            description: line.description,
            reference: line.reference,
            debit_amount: line.debit,
            credit_amount: line.credit,
            running_balance: line.balance,
            currency: selectedAccount?.currency || 'IDR',
            reconciliation_status: 'unmatched',
            created_by: user?.id,
          }));

          const { error } = await supabase
            .from('bank_statement_lines')
            .insert(insertData);

          if (error) throw error;

          await autoMatchTransactions();
          loadStatementLines();
          alert(`✅ Successfully imported ${lines.length} transactions`);
        } catch (err: any) {
          console.error('Error parsing file:', err);
          alert('❌ Failed to parse file: ' + err.message);
        }
      };
      reader.readAsBinaryString(file);
    } catch (error: any) {
      console.error('Excel upload error:', error);
      alert(`❌ Failed to process file: ${error.message}`);
    }
  };

  const parseStatementDataWithMetadata = (rows: any[][]): { lines: StatementLine[]; metadata: any } => {
    const lines: StatementLine[] = [];
    const metadata: any = {
      period: '',
      startDate: '',
      endDate: '',
      openingBalance: 0,
      closingBalance: 0,
      totalDebits: 0,
      totalCredits: 0,
    };

    let year = new Date().getFullYear();
    let month = new Date().getMonth() + 1;

    for (let i = 0; i < Math.min(10, rows.length); i++) {
      const row = rows[i];
      if (!row || row.length === 0) continue;

      const firstCell = String(row[0] || '');
      if (firstCell.includes('Periode')) {
        const periodeMatch = firstCell.match(/(\d{2})\/(\d{2})\/(\d{4})\s*-\s*(\d{2})\/(\d{2})\/(\d{4})/);
        if (periodeMatch) {
          const startDay = parseInt(periodeMatch[1]);
          const startMonth = parseInt(periodeMatch[2]);
          const startYear = parseInt(periodeMatch[3]);
          const endDay = parseInt(periodeMatch[4]);
          const endMonth = parseInt(periodeMatch[5]);
          const endYear = parseInt(periodeMatch[6]);

          year = startYear;
          month = startMonth;

          metadata.startDate = `${startYear}-${String(startMonth).padStart(2, '0')}-${String(startDay).padStart(2, '0')}`;
          metadata.endDate = `${endYear}-${String(endMonth).padStart(2, '0')}-${String(endDay).padStart(2, '0')}`;

          const monthNames = ['', 'JANUARI', 'FEBRUARI', 'MARET', 'APRIL', 'MEI', 'JUNI', 'JULI', 'AGUSTUS', 'SEPTEMBER', 'OKTOBER', 'NOVEMBER', 'DESEMBER'];
          metadata.period = `${monthNames[startMonth]} ${startYear}`;
        }
      }
    }

    let headerRowIdx = -1;
    for (let i = 0; i < Math.min(20, rows.length); i++) {
      const row = rows[i];
      if (!row || row.length === 0) continue;

      const firstCell = String(row[0] || '').toLowerCase();
      if (firstCell.includes('tanggal') && firstCell.includes('transaksi')) {
        headerRowIdx = i;
        break;
      }
    }

    console.log('🔍 Header row index:', headerRowIdx);

    if (headerRowIdx === -1) {
      console.error('❌ Could not find BCA column headers (looking for "Tanggal Transaksi")');
      console.log('📋 Checked rows:', rows.slice(0, 20).map((r, i) => `Row ${i}: ${r[0]}`));
      return { lines, metadata };
    }

    const headerRow = rows[headerRowIdx];
    let dateCol = -1, descCol = -1, branchCol = -1, amountCol = -1, balanceCol = -1;

    headerRow.forEach((cell: any, idx: number) => {
      const cellStr = String(cell || '').toLowerCase();
      if (cellStr.includes('tanggal')) dateCol = idx;
      if (cellStr.includes('keterangan')) descCol = idx;
      if (cellStr.includes('cabang')) branchCol = idx;
      if (cellStr.includes('jumlah')) amountCol = idx;
      if (cellStr.includes('saldo')) balanceCol = idx;
    });

    console.log('📍 Column positions:', { dateCol, descCol, branchCol, amountCol, balanceCol });

    if (dateCol === -1 || descCol === -1 || amountCol === -1) {
      console.error('❌ Missing required columns', { dateCol, descCol, amountCol });
      console.log('📋 Header row:', headerRow);
      return { lines, metadata };
    }

    let processedCount = 0;
    let skippedCount = 0;

    for (let i = headerRowIdx + 1; i < rows.length; i++) {
      const row = rows[i];
      if (!row || row.length === 0) {
        skippedCount++;
        continue;
      }

      const firstCell = String(row[0] || '');

      if (firstCell.includes('Saldo Awal') ||
          firstCell.includes('Mutasi Debet') ||
          firstCell.includes('Mutasi Kredit') ||
          firstCell.includes('Saldo Akhir')) {
        console.log(`⏹️ Stopped at footer row ${i}: ${firstCell}`);
        break;
      }

      const dateVal = row[dateCol];
      if (!dateVal) {
        skippedCount++;
        if (i < headerRowIdx + 5) console.log(`⏭️ Row ${i}: No date value`);
        continue;
      }

      const dateStr = String(dateVal).trim();
      const dateMatch = dateStr.match(/^(\d{1,2})\/(\d{1,2})$/);
      if (!dateMatch) {
        skippedCount++;
        if (i < headerRowIdx + 5) console.log(`⏭️ Row ${i}: Date doesn't match pattern: "${dateStr}"`);
        continue;
      }

      processedCount++;

      const day = parseInt(dateMatch[1]);
      const mon = parseInt(dateMatch[2]);

      if (day < 1 || day > 31 || mon < 1 || mon > 12) continue;

      const parsedDate = `${year}-${String(mon).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

      const amountStr = String(row[amountCol] || '').trim();
      const isCR = amountStr.includes(' CR');
      const isDB = amountStr.includes(' DB');

      const amountCleaned = amountStr.replace(/[^\d,\.]/g, '');
      const amount = parseFloat(amountCleaned.replace(/,/g, '')) || 0;

      let debit = 0, credit = 0;
      if (isCR) {
        credit = amount;
      } else if (isDB) {
        debit = amount;
      } else {
        debit = amount;
      }

      const balanceStr = String(row[balanceCol] || '').trim();
      const balanceCleaned = balanceStr.replace(/[^\d,\.]/g, '');
      const balance = parseFloat(balanceCleaned.replace(/,/g, '')) || 0;

      const description = String(row[descCol] || '').trim();
      const branch = branchCol >= 0 ? String(row[branchCol] || '').trim() : '';

      lines.push({
        id: `temp-${i}`,
        date: parsedDate,
        description: description,
        reference: branch,
        debit: debit,
        credit: credit,
        balance: balance,
        currency: selectedAccount?.currency || 'IDR',
        status: 'unmatched',
      });
    }

    console.log(`✅ Parsing complete: ${lines.length} transactions, ${skippedCount} rows skipped`);

    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      if (!row || row.length === 0) continue;

      const firstCell = String(row[0] || '');

      if (firstCell.includes('Saldo Awal')) {
        const valueCell = String(row[1] || row[0] || '');
        const amountMatch = valueCell.match(/[\d,\.]+/);
        if (amountMatch) {
          metadata.openingBalance = parseFloat(amountMatch[0].replace(/,/g, '')) || 0;
        }
      }

      if (firstCell.includes('Mutasi Debet')) {
        const valueCell = String(row[1] || row[0] || '');
        const amountMatch = valueCell.match(/[\d,\.]+/);
        if (amountMatch) {
          metadata.totalDebits = parseFloat(amountMatch[0].replace(/,/g, '')) || 0;
        }
      }

      if (firstCell.includes('Mutasi Kredit')) {
        const valueCell = String(row[1] || row[0] || '');
        const amountMatch = valueCell.match(/[\d,\.]+/);
        if (amountMatch) {
          metadata.totalCredits = parseFloat(amountMatch[0].replace(/,/g, '')) || 0;
        }
      }

      if (firstCell.includes('Saldo Akhir')) {
        const valueCell = String(row[1] || row[0] || '');
        const amountMatch = valueCell.match(/[\d,\.]+/);
        if (amountMatch) {
          metadata.closingBalance = parseFloat(amountMatch[0].replace(/,/g, '')) || 0;
        }
      }
    }

    return { lines, metadata };
  };

  const autoMatchTransactions = async () => {
    if (!selectedBank) return;

    try {
      // Load unmatched statement lines
      const { data: lines, error: linesError } = await supabase
        .from('bank_statement_lines')
        .select('*')
        .eq('bank_account_id', selectedBank)
        .eq('reconciliation_status', 'unmatched')
        .gte('transaction_date', dateRange.start)
        .lte('transaction_date', dateRange.end);

      if (linesError) throw linesError;
      if (!lines || lines.length === 0) {
        alert('No unmatched transactions to process');
        return;
      }

      // Load expenses
      const { data: expensesList, error: expError } = await supabase
        .from('finance_expenses')
        .select('id, expense_date, amount, description, voucher_number');

      if (expError) throw expError;
      if (!expensesList || expensesList.length === 0) {
        alert('No expenses found to match against');
        return;
      }

      let matchCount = 0;

      for (const line of lines) {
        const amount = line.debit_amount || line.credit_amount || 0;

        // Try to find matching expense
        let matchedExpense = null;

        // 1. Try match by amount (exact match within 0.01)
        matchedExpense = expensesList.find(exp =>
          Math.abs(exp.amount - amount) < 0.01
        );

        // 2. If no match, try by voucher number in description
        if (!matchedExpense && line.description) {
          for (const exp of expensesList) {
            if (exp.voucher_number && line.description.includes(exp.voucher_number)) {
              matchedExpense = exp;
              break;
            }
          }
        }

        if (matchedExpense) {
          // Update the line with matched expense
          await supabase
            .from('bank_statement_lines')
            .update({
              matched_expense_id: matchedExpense.id,
              reconciliation_status: 'suggested',
              notes: `Auto-matched: ${matchedExpense.description}`,
            })
            .eq('id', line.id);

          matchCount++;
        }
      }

      alert(`✅ Auto-match complete!\nMatched ${matchCount} out of ${lines.length} transactions`);
      loadStatementLines();
    } catch (err: any) {
      console.error('Error auto-matching:', err);
      alert('❌ Auto-match failed: ' + err.message);
    }
  };

  const clearAllReconciliationData = async () => {
    if (!selectedBank) return;

    const confirmed = confirm(
      '⚠️ WARNING: This will delete ALL reconciliation data for this bank account.\n\n' +
      'This includes:\n' +
      '- All statement lines\n' +
      '- All matches and links\n' +
      '\nAre you sure you want to proceed?'
    );

    if (!confirmed) return;

    try {
      const { error } = await supabase
        .from('bank_statement_lines')
        .delete()
        .eq('bank_account_id', selectedBank);

      if (error) throw error;

      alert('✅ All reconciliation data cleared successfully');
      loadStatementLines();
    } catch (err: any) {
      console.error('Error clearing data:', err);
      alert('❌ Failed to clear data: ' + err.message);
    }
  };

  const confirmMatch = async (lineId: string) => {
    try {
      await supabase
        .from('bank_statement_lines')
        .update({ reconciliation_status: 'matched' })
        .eq('id', lineId);
      loadStatementLines();
    } catch (err) {
      console.error('Error confirming match:', err);
    }
  };

  const rejectMatch = async (lineId: string) => {
    try {
      await supabase
        .from('bank_statement_lines')
        .update({
          reconciliation_status: 'unmatched',
          matched_entry_id: null
        })
        .eq('id', lineId);
      loadStatementLines();
    } catch (err) {
      console.error('Error rejecting match:', err);
    }
  };

  const openRecordModal = (line: StatementLine) => {
    setRecordingLine(line);
    setRecordModal(true);
  };

  const handleRecordExpense = async (line: StatementLine, category: string, description: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Record as expense
      const { data: expense, error: expenseError } = await supabase
        .from('finance_expenses')
        .insert({
          expense_category: category,
          amount: line.debit,
          expense_date: line.date,
          description: description || line.description,
          created_by: user.id,
        })
        .select()
        .single();

      if (expenseError) throw expenseError;

      // Mark line as recorded
      await supabase
        .from('bank_statement_lines')
        .update({
          reconciliation_status: 'recorded',
          matched_expense_id: expense.id,
          matched_at: new Date().toISOString(),
          matched_by: user.id,
        })
        .eq('id', line.id);

      setRecordModal(false);
      setRecordingLine(null);
      loadStatementLines();
      alert('✅ Expense recorded and linked successfully');
    } catch (error: any) {
      console.error('Error recording expense:', error);
      alert('❌ ' + error.message);
    }
  };

  const handleLinkToExpense = async (line: StatementLine, expenseId: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Link to existing expense
      await supabase
        .from('bank_statement_lines')
        .update({
          reconciliation_status: 'matched',
          matched_expense_id: expenseId,
          matched_at: new Date().toISOString(),
          matched_by: user.id,
        })
        .eq('id', line.id);

      setRecordModal(false);
      setRecordingLine(null);
      setLinkToExpense(false);
      loadStatementLines();
      alert('✅ Linked to expense successfully');
    } catch (error: any) {
      console.error('Error linking to expense:', error);
      alert('❌ ' + error.message);
    }
  };

  const handleRecordReceipt = async (line: StatementLine, type: string, description: string) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      // Record as receipt - simplified
      // Full implementation would create proper receipt voucher

      // Mark line as recorded
      await supabase
        .from('bank_statement_lines')
        .update({
          reconciliation_status: 'recorded',
          notes: `${type}: ${description}`,
          matched_at: new Date().toISOString(),
          matched_by: user.id,
        })
        .eq('id', line.id);

      setRecordModal(false);
      setRecordingLine(null);
      loadStatementLines();
      alert('✅ Receipt recorded successfully');
    } catch (error: any) {
      console.error('Error recording receipt:', error);
      alert('❌ ' + error.message);
    }
  };

  const filteredLines = statementLines.filter(line => {
    if (activeFilter === 'all') return true;
    return line.status === activeFilter;
  });

  const stats = {
    total: statementLines.length,
    matched: statementLines.filter(l => l.status === 'matched' || l.status === 'recorded').length,
    suggested: statementLines.filter(l => l.status === 'suggested').length,
    unmatched: statementLines.filter(l => l.status === 'unmatched').length,
  };

  const getCurrencySymbol = (currency: string) => {
    return currency === 'USD' ? '$' : 'Rp';
  };

  return (
    <div className="space-y-4">
      <div className="bg-white border rounded-lg p-4">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">Bank Reconciliation</h3>
            {selectedAccount && (
              <p className="text-sm text-gray-600 mt-1">
                {selectedAccount.bank_name} - {selectedAccount.account_number}
                <span className="ml-2 px-2 py-0.5 bg-blue-100 text-blue-700 rounded text-xs font-medium">
                  {selectedAccount.currency}
                </span>
              </p>
            )}
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => { autoMatchTransactions(); }}
              disabled={!selectedBank}
              className="flex items-center gap-1 px-3 py-1.5 text-sm bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 disabled:opacity-50"
              title="Auto-match transactions by amount and voucher number"
            >
              <RefreshCw className="w-4 h-4" />
              Auto-Match
            </button>
            {canManage && (
              <>
                <button
                  onClick={clearAllReconciliationData}
                  disabled={!selectedBank}
                  className="flex items-center gap-1 px-3 py-1.5 text-sm bg-red-100 text-red-700 rounded-lg hover:bg-red-200 disabled:opacity-50"
                  title="Clear all reconciliation data for this account"
                >
                  <XCircle className="w-4 h-4" />
                  Clear Data
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".pdf,.xlsx,.xls,.csv"
                  onChange={handleFileUpload}
                  className="hidden"
                />
                <button
                  onClick={() => fileInputRef.current?.click()}
                  disabled={uploading || !selectedBank}
                  className="flex items-center gap-1 px-3 py-1.5 text-sm bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
                  title="Upload BCA statement PDF or Excel/CSV from online banking"
                >
                  <Upload className="w-4 h-4" />
                  {uploading ? 'Uploading...' : 'Upload PDF/Excel'}
                </button>
              </>
            )}
          </div>
        </div>

        <div className="flex items-center gap-4">
          <select
            value={selectedBank}
            onChange={(e) => setSelectedBank(e.target.value)}
            className="px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
          >
            {bankAccounts.map(bank => (
              <option key={bank.id} value={bank.id}>
                {bank.bank_name} - {bank.account_number} ({bank.currency})
              </option>
            ))}
          </select>
          <div className="flex items-center gap-2 text-sm">
            <Calendar className="w-4 h-4 text-gray-400" />
            <input
              type="date"
              value={dateRange.start}
              onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })}
              className="px-2 py-1.5 border rounded"
            />
            <span className="text-gray-400">to</span>
            <input
              type="date"
              value={dateRange.end}
              onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })}
              className="px-2 py-1.5 border rounded"
            />
          </div>
        </div>
      </div>

      <div className="grid grid-cols-4 gap-3">
        <button
          onClick={() => setActiveFilter('all')}
          className={`p-3 rounded-lg text-left transition ${
            activeFilter === 'all' ? 'bg-blue-50 border-2 border-blue-500' : 'bg-white border border-gray-200'
          }`}
        >
          <div className="text-2xl font-bold text-gray-900">{stats.total}</div>
          <div className="text-xs text-gray-500">Total Transactions</div>
        </button>
        <button
          onClick={() => setActiveFilter('matched')}
          className={`p-3 rounded-lg text-left transition ${
            activeFilter === 'matched' ? 'bg-green-50 border-2 border-green-500' : 'bg-white border border-gray-200'
          }`}
        >
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-green-600" />
            <span className="text-2xl font-bold text-green-700">{stats.matched}</span>
          </div>
          <div className="text-xs text-gray-500">Reconciled</div>
        </button>
        <button
          onClick={() => setActiveFilter('suggested')}
          className={`p-3 rounded-lg text-left transition ${
            activeFilter === 'suggested' ? 'bg-yellow-50 border-2 border-yellow-500' : 'bg-white border border-gray-200'
          }`}
        >
          <div className="flex items-center gap-2">
            <AlertCircle className="w-5 h-5 text-yellow-600" />
            <span className="text-2xl font-bold text-yellow-700">{stats.suggested}</span>
          </div>
          <div className="text-xs text-gray-500">Needs Review</div>
        </button>
        <button
          onClick={() => setActiveFilter('unmatched')}
          className={`p-3 rounded-lg text-left transition ${
            activeFilter === 'unmatched' ? 'bg-red-50 border-2 border-red-500' : 'bg-white border border-gray-200'
          }`}
        >
          <div className="flex items-center gap-2">
            <XCircle className="w-5 h-5 text-red-600" />
            <span className="text-2xl font-bold text-red-700">{stats.unmatched}</span>
          </div>
          <div className="text-xs text-gray-500">Unrecorded</div>
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-12 bg-white rounded-lg">
          <RefreshCw className="w-6 h-6 animate-spin text-blue-600" />
        </div>
      ) : filteredLines.length === 0 ? (
        <div className="text-center py-12 bg-white rounded-lg border-2 border-dashed">
          <Landmark className="w-12 h-12 text-gray-300 mx-auto mb-3" />
          <h3 className="text-lg font-medium text-gray-600 mb-1">No Bank Transactions</h3>
          <p className="text-sm text-gray-500 mb-4">
            Upload a BCA PDF statement or Excel/CSV file to start reconciling
          </p>
          {canManage && (
            <button
              onClick={() => fileInputRef.current?.click()}
              className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              <Upload className="w-4 h-4" />
              Upload Statement
            </button>
          )}
        </div>
      ) : (
        <div className="bg-white border rounded-lg overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-3 py-2 text-left font-medium text-gray-600">Date</th>
                <th className="px-3 py-2 text-left font-medium text-gray-600">Description</th>
                <th className="px-3 py-2 text-right font-medium text-gray-600">Debit</th>
                <th className="px-3 py-2 text-right font-medium text-gray-600">Credit</th>
                <th className="px-3 py-2 text-center font-medium text-gray-600">Status</th>
                <th className="px-3 py-2 text-center font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filteredLines.map(line => (
                <tr key={line.id} className="hover:bg-gray-50">
                  <td className="px-3 py-2 text-gray-700 whitespace-nowrap">
                    {new Date(line.date).toLocaleDateString('id-ID')}
                  </td>
                  <td className="px-3 py-2 text-gray-700 max-w-md">
                    <div className="truncate">{line.description}</div>
                    {line.reference && (
                      <div className="text-xs text-gray-500 font-mono">{line.reference}</div>
                    )}
                  </td>
                  <td className="px-3 py-2 text-right text-red-600 font-medium whitespace-nowrap">
                    {line.debit > 0 ? `${getCurrencySymbol(line.currency)} ${line.debit.toLocaleString('id-ID')}` : '-'}
                  </td>
                  <td className="px-3 py-2 text-right text-green-600 font-medium whitespace-nowrap">
                    {line.credit > 0 ? `${getCurrencySymbol(line.currency)} ${line.credit.toLocaleString('id-ID')}` : '-'}
                  </td>
                  <td className="px-3 py-2 text-center">
                    {(line.status === 'matched' || line.status === 'recorded') && (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
                        <CheckCircle2 className="w-3 h-3" /> Recorded
                      </span>
                    )}
                    {line.status === 'suggested' && (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-700">
                        <AlertCircle className="w-3 h-3" /> Review
                      </span>
                    )}
                    {line.status === 'unmatched' && (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                        <XCircle className="w-3 h-3" /> Unrecorded
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-2 text-center">
                    {line.status === 'suggested' && (
                      <div className="flex items-center justify-center gap-1">
                        <button
                          onClick={() => confirmMatch(line.id)}
                          className="p-1 text-green-600 hover:bg-green-50 rounded"
                          title="Confirm Match"
                        >
                          <CheckCircle2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => rejectMatch(line.id)}
                          className="p-1 text-red-600 hover:bg-red-50 rounded"
                          title="Reject Match"
                        >
                          <XCircle className="w-4 h-4" />
                        </button>
                      </div>
                    )}
                    {line.status === 'unmatched' && canManage && (
                      <button
                        onClick={() => openRecordModal(line)}
                        className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-blue-600 text-white rounded hover:bg-blue-700"
                        title="Record transaction"
                      >
                        <Plus className="w-3 h-3" />
                        Record
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Recording Modal */}
      <Modal isOpen={recordModal} onClose={() => { setRecordModal(false); setRecordingLine(null); setLinkToExpense(false); }} title="Record Transaction">
        {recordingLine && (
          <div className="space-y-4">
            <div className="p-3 bg-gray-50 rounded-lg">
              <div className="flex items-center justify-between text-sm">
                <span className="text-gray-600">Date:</span>
                <span className="font-medium">{new Date(recordingLine.date).toLocaleDateString('id-ID')}</span>
              </div>
              <div className="mt-2 text-sm">
                <span className="text-gray-600">Description:</span>
                <p className="font-medium mt-1">{recordingLine.description}</p>
              </div>
              {recordingLine.debit > 0 && (
                <div className="mt-2 flex items-center justify-between">
                  <span className="text-sm text-gray-600">Amount:</span>
                  <span className="text-lg font-bold text-red-600">
                    {getCurrencySymbol(recordingLine.currency)} {recordingLine.debit.toLocaleString('id-ID')}
                  </span>
                </div>
              )}
              {recordingLine.credit > 0 && (
                <div className="mt-2 flex items-center justify-between">
                  <span className="text-sm text-gray-600">Amount:</span>
                  <span className="text-lg font-bold text-green-600">
                    {getCurrencySymbol(recordingLine.currency)} {recordingLine.credit.toLocaleString('id-ID')}
                  </span>
                </div>
              )}
            </div>

            {recordingLine.debit > 0 && (
              <div>
                <div className="flex gap-2 mb-3">
                  <button
                    onClick={() => setLinkToExpense(false)}
                    className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium ${!linkToExpense ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700'}`}
                  >
                    Create New Expense
                  </button>
                  <button
                    onClick={() => setLinkToExpense(true)}
                    className={`flex-1 py-2 px-3 rounded-lg text-sm font-medium ${linkToExpense ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700'}`}
                  >
                    Link to Existing Expense
                  </button>
                </div>

                {!linkToExpense ? (
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      const formData = new FormData(e.currentTarget);
                      const category = formData.get('category') as string;
                      const description = formData.get('description') as string;
                      handleRecordExpense(recordingLine, category, description);
                    }}
                    className="space-y-3"
                  >
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Category *</label>
                      <select
                        name="category"
                        required
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                      >
                        <option value="">Select category...</option>
                        {expenseCategories.map(cat => (
                          <option key={cat.value} value={cat.value}>
                            {cat.label} ({cat.type})
                          </option>
                        ))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                      <input
                        type="text"
                        name="description"
                        defaultValue={recordingLine.description}
                        className="w-full px-3 py-2 border rounded-lg"
                        placeholder="Optional: Override description"
                      />
                    </div>
                    <button
                      type="submit"
                      className="w-full py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                    >
                      Create & Link Expense
                    </button>
                  </form>
                ) : (
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      const formData = new FormData(e.currentTarget);
                      const expenseId = formData.get('expense_id') as string;
                      if (!expenseId) {
                        alert('Please select an expense');
                        return;
                      }
                      handleLinkToExpense(recordingLine, expenseId);
                    }}
                    className="space-y-3"
                  >
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">Select Expense *</label>
                      <select
                        name="expense_id"
                        required
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 text-sm"
                        disabled={expenses.length === 0}
                      >
                        <option value="">
                          {expenses.length === 0 ? 'No expenses found' : 'Choose an expense...'}
                        </option>
                        {expenses.map(expense => (
                          <option key={expense.id} value={expense.id}>
                            {expense.voucher_number ? `[${expense.voucher_number}] ` : ''}
                            {new Date(expense.expense_date).toLocaleDateString('id-ID')} -
                            {expense.description} -
                            Rp {expense.amount.toLocaleString('id-ID')}
                          </option>
                        ))}
                      </select>
                      <p className="text-xs text-gray-500 mt-1">
                        Showing {expenses.length} expenses. Match by voucher number or amount.
                      </p>
                    </div>
                    <button
                      type="submit"
                      className="w-full py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                    >
                      Link to Expense
                    </button>
                  </form>
                )}
              </div>
            )}

            {recordingLine.credit > 0 && (
              <div>
                <h4 className="font-medium mb-2">Record as Receipt</h4>
                <form
                  onSubmit={(e) => {
                    e.preventDefault();
                    const formData = new FormData(e.currentTarget);
                    const type = formData.get('type') as string;
                    const description = formData.get('description') as string;
                    handleRecordReceipt(recordingLine, type, description);
                  }}
                  className="space-y-3"
                >
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Type *</label>
                    <select
                      name="type"
                      required
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="">Select type...</option>
                      <option value="customer_payment">Customer Payment</option>
                      <option value="capital">Capital Injection</option>
                      <option value="other_income">Other Income</option>
                      <option value="loan">Loan/Financing</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
                    <input
                      type="text"
                      name="description"
                      defaultValue={recordingLine.description}
                      className="w-full px-3 py-2 border rounded-lg"
                      placeholder="Optional: Override description"
                    />
                  </div>
                  <button
                    type="submit"
                    className="w-full py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                  >
                    Record Receipt
                  </button>
                </form>
              </div>
            )}
          </div>
        )}
      </Modal>

      {ocrError && (
        <Modal
          isOpen={true}
          onClose={() => {
            setOcrError(null);
            setLastUploadedFile(null);
          }}
          title="PDF Extraction Failed"
        >
          <div className="space-y-4">
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
              <p className="text-yellow-800 text-sm font-medium mb-2">{ocrError.message}</p>
              <div className="space-y-2">
                <p className="text-sm text-yellow-700 font-medium">Recommended options:</p>
                <ul className="list-disc list-inside space-y-1 text-sm text-yellow-700">
                  {ocrError.suggestions.map((suggestion, idx) => (
                    <li key={idx}>{suggestion}</li>
                  ))}
                </ul>
              </div>
            </div>

            {ocrError.canUseOCR && (
              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <p className="text-blue-800 text-sm font-medium mb-2">Advanced Option: OCR Processing</p>
                <p className="text-blue-700 text-xs mb-3">
                  Optical Character Recognition (OCR) can extract text from image-based or encrypted PDFs.
                  This process takes 30-60 seconds and requires Google Vision API configuration.
                  You'll be able to preview the results before saving.
                </p>
                <div className="flex gap-2">
                  <button
                    onClick={handleRunOCR}
                    disabled={uploading}
                    className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 text-sm font-medium"
                  >
                    {uploading ? 'Processing with OCR...' : 'Run OCR Anyway'}
                  </button>
                  <button
                    onClick={() => {
                      setOcrError(null);
                      setLastUploadedFile(null);
                    }}
                    className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 text-sm font-medium"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        </Modal>
      )}

      {ocrPreview && (
        <Modal
          isOpen={true}
          onClose={() => setOcrPreview(null)}
          title="OCR Preview - Confirm Before Saving"
        >
          <div className="space-y-4">
            <div className="bg-green-50 border border-green-200 rounded-lg p-4">
              <p className="text-green-800 text-sm font-medium mb-2">
                ✅ OCR extracted {ocrPreview.transactionCount} transactions
              </p>
              <div className="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <span className="text-gray-600">Period:</span>
                  <span className="ml-2 font-medium text-gray-900">{ocrPreview.period}</span>
                </div>
                <div>
                  <span className="text-gray-600">Opening Balance:</span>
                  <span className="ml-2 font-medium text-gray-900">
                    {selectedAccount?.currency} {ocrPreview.openingBalance.toLocaleString()}
                  </span>
                </div>
                <div>
                  <span className="text-gray-600">Closing Balance:</span>
                  <span className="ml-2 font-medium text-gray-900">
                    {selectedAccount?.currency} {ocrPreview.closingBalance.toLocaleString()}
                  </span>
                </div>
                <div>
                  <span className="text-gray-600">Transactions:</span>
                  <span className="ml-2 font-medium text-gray-900">{ocrPreview.transactionCount}</span>
                </div>
              </div>
            </div>

            <div>
              <h4 className="text-sm font-medium text-gray-900 mb-2">Sample Transactions (First 10):</h4>
              <div className="border rounded-lg overflow-hidden">
                <table className="w-full text-xs">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-2 py-1 text-left">Date</th>
                      <th className="px-2 py-1 text-left">Description</th>
                      <th className="px-2 py-1 text-right">Amount</th>
                    </tr>
                  </thead>
                  <tbody>
                    {ocrPreview.transactions.map((txn: any, idx: number) => (
                      <tr key={idx} className="border-t">
                        <td className="px-2 py-1">{txn.date}</td>
                        <td className="px-2 py-1 truncate max-w-xs">{txn.description}</td>
                        <td className="px-2 py-1 text-right">
                          {selectedAccount?.currency} {(txn.debitAmount || txn.creditAmount).toLocaleString()}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>

            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
              <p className="text-yellow-800 text-xs">
                ⚠️ Please verify the extracted data looks correct before confirming.
                OCR may have minor errors in dates, amounts, or descriptions.
              </p>
            </div>

            <div className="flex gap-2">
              <button
                onClick={handleConfirmOCRPreview}
                disabled={uploading}
                className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 font-medium"
              >
                {uploading ? 'Saving...' : 'Confirm & Save'}
              </button>
              <button
                onClick={() => setOcrPreview(null)}
                className="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 font-medium"
              >
                Cancel
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
