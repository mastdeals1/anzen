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
        .from('expenses')
        .select(`
          id,
          expense_date,
          description,
          amount,
          currency,
          category,
          vendor_name,
          status
        `)
        .order('expense_date', { ascending: false })
        .limit(100);

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

  const handlePDFUpload = async (file: File) => {
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('bankAccountId', selectedBank);

      const { data: { session } } = await supabase.auth.getSession();
      if (!session) throw new Error('Not authenticated');

      console.log('Uploading PDF to:', `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/parse-bca-statement`);
      console.log('File size:', file.size, 'bytes');
      console.log('File type:', file.type);

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

      console.log('Response status:', response.status);
      console.log('Response headers:', response.headers);

      let result;
      try {
        result = await response.json();
        console.log('Response body:', result);
      } catch (jsonError) {
        console.error('Failed to parse response as JSON:', jsonError);
        const text = await response.text();
        console.error('Response text:', text);
        throw new Error('Server returned invalid response');
      }

      if (!response.ok) {
        throw new Error(result.error || 'Failed to parse PDF');
      }

      alert(`✅ Successfully imported ${result.transactionCount} transactions from ${result.period}`);
      await autoMatchTransactions();
      loadStatementLines();
    } catch (error: any) {
      console.error('PDF upload error:', error);
      console.error('Error stack:', error.stack);
      alert(`❌ Failed to parse PDF: ${error.message}\n\nCheck browser console for details.`);
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

          const lines = parseStatementData(jsonData);

          if (lines.length === 0) {
            alert('No valid transactions found in the file.');
            return;
          }

          // Create upload record first
          const { data: uploadRecord, error: uploadError } = await supabase
            .from('bank_statement_uploads')
            .insert({
              bank_account_id: selectedBank,
              statement_period: `${new Date().toLocaleString('default', { month: 'long' })} ${new Date().getFullYear()}`,
              statement_start_date: dateRange.start,
              statement_end_date: dateRange.end,
              currency: selectedAccount?.currency || 'IDR',
              opening_balance: 0,
              closing_balance: lines[lines.length - 1]?.balance || 0,
              total_debits: lines.reduce((sum, l) => sum + l.debit, 0),
              total_credits: lines.reduce((sum, l) => sum + l.credit, 0),
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

  const parseStatementData = (rows: any[][]): StatementLine[] => {
    const lines: StatementLine[] = [];
    const headerRow = rows[0] || [];

    let dateCol = -1, descCol = -1, refCol = -1, debitCol = -1, creditCol = -1, balanceCol = -1;

    headerRow.forEach((cell: any, idx: number) => {
      const cellStr = String(cell || '').toLowerCase();
      if (cellStr.includes('date') || cellStr.includes('tanggal')) dateCol = idx;
      if (cellStr.includes('description') || cellStr.includes('keterangan') || cellStr.includes('uraian')) descCol = idx;
      if (cellStr.includes('ref') || cellStr.includes('no.')) refCol = idx;
      if (cellStr.includes('debit') || cellStr.includes('keluar')) debitCol = idx;
      if (cellStr.includes('credit') || cellStr.includes('kredit') || cellStr.includes('masuk')) creditCol = idx;
      if (cellStr.includes('balance') || cellStr.includes('saldo')) balanceCol = idx;
    });

    if (dateCol === -1) dateCol = 0;
    if (descCol === -1) descCol = 1;
    if (debitCol === -1) debitCol = 2;
    if (creditCol === -1) creditCol = 3;
    if (balanceCol === -1) balanceCol = 4;

    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];
      if (!row || row.length === 0) continue;

      const dateVal = row[dateCol];
      let parsedDate = '';

      if (typeof dateVal === 'number') {
        const excelDate = new Date((dateVal - 25569) * 86400 * 1000);
        parsedDate = excelDate.toISOString().split('T')[0];
      } else if (dateVal) {
        const dateStr = String(dateVal);
        const parts = dateStr.split(/[\/\-\.]/);
        if (parts.length === 3) {
          if (parts[0].length === 4) {
            parsedDate = `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`;
          } else {
            parsedDate = `${parts[2]}-${parts[1].padStart(2, '0')}-${parts[0].padStart(2, '0')}`;
          }
        }
      }

      if (!parsedDate) continue;

      const parseAmount = (val: any): number => {
        if (!val) return 0;
        const str = String(val).replace(/[^\d.-]/g, '');
        return parseFloat(str) || 0;
      };

      lines.push({
        id: `temp-${i}`,
        date: parsedDate,
        description: String(row[descCol] || ''),
        reference: refCol >= 0 ? String(row[refCol] || '') : '',
        debit: parseAmount(row[debitCol]),
        credit: parseAmount(row[creditCol]),
        balance: parseAmount(row[balanceCol]),
        currency: selectedAccount?.currency || 'IDR',
        status: 'unmatched',
      });
    }

    return lines;
  };

  const autoMatchTransactions = async () => {
    try {
      // Basic matching logic - can be enhanced
      const { data: expenses } = await supabase
        .from('finance_expenses')
        .select('id, expense_date, amount, description')
        .gte('expense_date', dateRange.start)
        .lte('expense_date', dateRange.end);

      // Match with expenses
      // This is a simplified version - full implementation would check more criteria
    } catch (err) {
      console.error('Error auto-matching:', err);
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
              onClick={() => { autoMatchTransactions(); loadStatementLines(); }}
              className="flex items-center gap-1 px-3 py-1.5 text-sm bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200"
              title="Auto-match transactions"
            >
              <RefreshCw className="w-4 h-4" />
              Auto-Match
            </button>
            {canManage && (
              <>
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
                        disabled={expenses.filter(exp => exp.currency === recordingLine.currency).length === 0}
                      >
                        <option value="">
                          {expenses.filter(exp => exp.currency === recordingLine.currency).length === 0
                            ? `No expenses found in ${recordingLine.currency}`
                            : 'Choose an expense...'}
                        </option>
                        {expenses.filter(exp => exp.currency === recordingLine.currency).map(expense => (
                          <option key={expense.id} value={expense.id}>
                            {new Date(expense.expense_date).toLocaleDateString('id-ID')} - {expense.vendor_name || expense.description} - {getCurrencySymbol(expense.currency)} {expense.amount.toLocaleString('id-ID')} {expense.status ? `[${expense.status}]` : ''}
                          </option>
                        ))}
                      </select>
                      <p className="text-xs text-gray-500 mt-1">
                        {expenses.filter(exp => exp.currency === recordingLine.currency).length > 0 ? (
                          <>Showing {expenses.filter(exp => exp.currency === recordingLine.currency).length} expenses in {recordingLine.currency}</>
                        ) : (
                          <>No expenses found in {recordingLine.currency}. Total expenses loaded: {expenses.length} (other currencies)</>
                        )}
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
    </div>
  );
}
