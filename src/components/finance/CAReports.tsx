import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Download, FileText, TrendingUp, Package, Building2 } from 'lucide-react';
import * as XLSX from 'xlsx';
import { useAuth } from '../../contexts/AuthContext';
import { useFinance } from '../../contexts/FinanceContext';

type ReportType =
  | 'coa'
  | 'cash_ledger'
  | 'bank_ledger'
  | 'sales_register'
  | 'purchase_register'
  | 'inventory_movement'
  | 'journal_register'
  | 'general_ledger'
  | 'trial_balance'
  | 'fixed_assets';

interface DateRange {
  from: string;
  to: string;
}

export function CAReports() {
  const { profile } = useAuth();
  const { dateRange: contextDateRange } = useFinance();
  const [selectedReport, setSelectedReport] = useState<ReportType>('inventory_movement');
  const [loading, setLoading] = useState(false);
  const [reportData, setReportData] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);

  // Use date range from context (master date picker)
  const dateRange: DateRange = {
    from: contextDateRange.startDate,
    to: contextDateRange.endDate
  };

  const reports = [
    { id: 'coa' as const, name: 'Chart of Accounts', icon: FileText, description: 'Complete COA list' },
    { id: 'cash_ledger' as const, name: 'Cash Ledger', icon: FileText, description: 'Cash on Hand & Petty Cash' },
    { id: 'bank_ledger' as const, name: 'Bank Ledger', icon: Building2, description: 'All bank accounts' },
    { id: 'sales_register' as const, name: 'Sales Register', icon: TrendingUp, description: 'All sales invoices' },
    { id: 'purchase_register' as const, name: 'Purchase Register', icon: FileText, description: 'All purchase invoices' },
    { id: 'inventory_movement' as const, name: 'Inventory Movement', icon: Package, description: 'Stock Opening + In + Out + Closing', highlight: true },
    { id: 'journal_register' as const, name: 'Journal Register', icon: FileText, description: 'All journal entries' },
    { id: 'general_ledger' as const, name: 'General Ledger', icon: FileText, description: 'All account ledgers combined' },
    { id: 'trial_balance' as const, name: 'Trial Balance', icon: FileText, description: 'Debit/Credit summary' },
    { id: 'fixed_assets' as const, name: 'Fixed Asset Register', icon: Building2, description: 'Assets with depreciation' }
  ];

  useEffect(() => {
    if (selectedReport) {
      loadReportData();
    }
  }, [selectedReport, contextDateRange.startDate, contextDateRange.endDate]);

  const loadReportData = async () => {
    setLoading(true);
    setError(null);
    try {
      let data = null;

      switch (selectedReport) {
        case 'coa':
          data = await loadChartOfAccounts();
          break;
        case 'cash_ledger':
          data = await loadCashLedger();
          break;
        case 'bank_ledger':
          data = await loadBankLedger();
          break;
        case 'sales_register':
          data = await loadSalesRegister();
          break;
        case 'purchase_register':
          data = await loadPurchaseRegister();
          break;
        case 'inventory_movement':
          data = await loadInventoryMovement();
          break;
        case 'journal_register':
          data = await loadJournalRegister();
          break;
        case 'general_ledger':
          data = await loadGeneralLedger();
          break;
        case 'trial_balance':
          data = await loadTrialBalance();
          break;
        case 'fixed_assets':
          data = await loadFixedAssets();
          break;
      }

      setReportData(data);
    } catch (error) {
      console.error('Error loading report:', error);
      setError((error as any).message || 'Failed to load report');
    } finally {
      setLoading(false);
    }
  };

  const loadChartOfAccounts = async () => {
    const { data, error } = await supabase
      .from('chart_of_accounts')
      .select('code, name, account_type')
      .order('code');

    if (error) throw error;
    return data || [];
  };

  const loadCashLedger = async () => {
    const { data: cashAccounts } = await supabase
      .from('chart_of_accounts')
      .select('id, code, name')
      .in('code', ['1101', '1102']);

    if (!cashAccounts || cashAccounts.length === 0) return [];

    const accountIds = cashAccounts.map(a => a.id);

    const { data: entries } = await supabase
      .from('journal_entries')
      .select('id, entry_date, entry_number, source_module')
      .gte('entry_date', dateRange.from)
      .lte('entry_date', dateRange.to)
      .order('entry_date', { ascending: true });

    if (!entries || entries.length === 0) return [];

    const entryIds = entries.map(e => e.id);

    const { data: lines, error } = await supabase
      .from('journal_entry_lines')
      .select('journal_entry_id, account_id, debit, credit, description')
      .in('journal_entry_id', entryIds)
      .in('account_id', accountIds);

    if (error) throw error;

    const result = lines?.map(line => {
      const entry = entries.find(e => e.id === line.journal_entry_id);
      const account = cashAccounts.find(a => a.id === line.account_id);
      return {
        date: entry?.entry_date,
        voucher_no: entry?.entry_number,
        account_name: account?.name,
        debit: line.debit,
        credit: line.credit,
        narration: line.description
      };
    }) || [];

    return result;
  };

  const loadBankLedger = async () => {
    const { data: bankAccounts } = await supabase
      .from('chart_of_accounts')
      .select('id, code, name')
      .like('code', '1111%');

    if (!bankAccounts || bankAccounts.length === 0) return [];

    const accountIds = bankAccounts.map(a => a.id);

    const { data: entries } = await supabase
      .from('journal_entries')
      .select('id, entry_date, entry_number, source_module')
      .gte('entry_date', dateRange.from)
      .lte('entry_date', dateRange.to)
      .order('entry_date', { ascending: true });

    if (!entries || entries.length === 0) return [];

    const entryIds = entries.map(e => e.id);

    const { data: lines, error } = await supabase
      .from('journal_entry_lines')
      .select('journal_entry_id, account_id, debit, credit, description')
      .in('journal_entry_id', entryIds)
      .in('account_id', accountIds);

    if (error) throw error;

    const result = lines?.map(line => {
      const entry = entries.find(e => e.id === line.journal_entry_id);
      const account = bankAccounts.find(a => a.id === line.account_id);
      return {
        date: entry?.entry_date,
        voucher_no: entry?.entry_number,
        account_name: account?.name,
        debit: line.debit,
        credit: line.credit,
        narration: line.description
      };
    }) || [];

    return result;
  };

  const loadSalesRegister = async () => {
    const { data, error } = await supabase
      .from('sales_invoices')
      .select(`
        invoice_number,
        invoice_date,
        customer_id,
        subtotal,
        tax_amount,
        total_amount,
        faktur_pajak_number,
        customers(customer_name)
      `)
      .gte('invoice_date', dateRange.from)
      .lte('invoice_date', dateRange.to)
      .order('invoice_date', { ascending: true });

    if (error) throw error;

    return data?.map(inv => ({
      invoice_date: inv.invoice_date,
      invoice_number: inv.invoice_number,
      customer_name: (inv.customers as any)?.customer_name,
      tax_invoice_no: inv.faktur_pajak_number,
      net_amount: inv.subtotal,
      ppn: inv.tax_amount,
      total_amount: inv.total_amount
    })) || [];
  };

  const loadPurchaseRegister = async () => {
    const { data, error } = await supabase
      .from('purchase_orders')
      .select(`
        po_number,
        po_date,
        supplier_id,
        subtotal,
        tax_amount,
        total_amount,
        currency,
        suppliers(supplier_name)
      `)
      .gte('po_date', dateRange.from)
      .lte('po_date', dateRange.to)
      .order('po_date', { ascending: true });

    if (error) throw error;

    return data?.map(po => ({
      po_date: po.po_date,
      po_number: po.po_number,
      supplier_name: (po.suppliers as any)?.supplier_name,
      net_amount: po.subtotal,
      ppn: po.tax_amount,
      total_amount: po.total_amount,
      currency: po.currency
    })) || [];
  };

  const loadInventoryMovement = async () => {
    const { data: openingTxns } = await supabase
      .from('inventory_transactions')
      .select(`
        product_id,
        quantity,
        transaction_type
      `)
      .lt('transaction_date', dateRange.from);

    const { data: periodTxns } = await supabase
      .from('inventory_transactions')
      .select(`
        product_id,
        transaction_date,
        quantity,
        transaction_type,
        reference_type,
        reference_number
      `)
      .gte('transaction_date', dateRange.from)
      .lte('transaction_date', dateRange.to);

    const { data: products } = await supabase
      .from('products')
      .select('id, product_code, product_name, unit');

    if (!products) return [];

    const productMap = new Map();

    products.forEach(prod => {
      productMap.set(prod.id, {
        product_code: prod.product_code,
        product_name: prod.product_name,
        unit: prod.unit || 'PCS',
        opening: 0,
        in_qty: 0,
        out_qty: 0,
        closing: 0
      });
    });

    openingTxns?.forEach((txn: any) => {
      if (productMap.has(txn.product_id)) {
        const prod = productMap.get(txn.product_id);
        if (txn.quantity > 0) {
          prod.opening += parseFloat(txn.quantity);
        } else {
          prod.opening += parseFloat(txn.quantity);
        }
      }
    });

    periodTxns?.forEach((txn: any) => {
      if (productMap.has(txn.product_id)) {
        const prod = productMap.get(txn.product_id);
        if (parseFloat(txn.quantity) > 0) {
          prod.in_qty += parseFloat(txn.quantity);
        } else {
          prod.out_qty += Math.abs(parseFloat(txn.quantity));
        }
      }
    });

    Array.from(productMap.values()).forEach(prod => {
      prod.closing = prod.opening + prod.in_qty - prod.out_qty;
    });

    // Return all products (not filtered) - useful to see full inventory picture
    return Array.from(productMap.values());
  };

  const loadJournalRegister = async () => {
    const { data: entries } = await supabase
      .from('journal_entries')
      .select('id, entry_date, entry_number, source_module, description')
      .gte('entry_date', dateRange.from)
      .lte('entry_date', dateRange.to)
      .order('entry_date', { ascending: true })
      .order('entry_number', { ascending: true });

    if (!entries || entries.length === 0) return [];

    const entryIds = entries.map(e => e.id);

    const { data: lines } = await supabase
      .from('journal_entry_lines')
      .select('journal_entry_id, line_number, account_id, debit, credit, description')
      .in('journal_entry_id', entryIds)
      .order('line_number', { ascending: true });

    const { data: accounts } = await supabase
      .from('chart_of_accounts')
      .select('id, code, name');

    const accountMap = new Map(accounts?.map(a => [a.id, a]) || []);

    const result = lines?.map(line => {
      const entry = entries.find(e => e.id === line.journal_entry_id);
      const account = accountMap.get(line.account_id);
      return {
        entry_date: entry?.entry_date,
        entry_number: entry?.entry_number,
        voucher_type: entry?.source_module,
        account_code: account?.code,
        account_name: account?.name,
        debit: line.debit,
        credit: line.credit,
        narration: line.description || entry?.description
      };
    }) || [];

    return result;
  };

  const loadGeneralLedger = async () => {
    const { data: entries } = await supabase
      .from('journal_entries')
      .select('id, entry_date, entry_number, source_module')
      .gte('entry_date', dateRange.from)
      .lte('entry_date', dateRange.to);

    if (!entries || entries.length === 0) return [];

    const entryIds = entries.map(e => e.id);

    const { data: lines } = await supabase
      .from('journal_entry_lines')
      .select('journal_entry_id, account_id, debit, credit, description')
      .in('journal_entry_id', entryIds);

    const { data: accounts } = await supabase
      .from('chart_of_accounts')
      .select('id, code, name, account_type');

    const accountMap = new Map(accounts?.map(a => [a.id, a]) || []);

    const result = lines?.map(line => {
      const entry = entries.find(e => e.id === line.journal_entry_id);
      const account = accountMap.get(line.account_id);
      return {
        account_code: account?.code,
        account_name: account?.name,
        entry_date: entry?.entry_date,
        voucher_number: entry?.entry_number,
        debit: line.debit,
        credit: line.credit,
        description: line.description
      };
    }) || [];

    return result.sort((a, b) => {
      if (a.account_code !== b.account_code) {
        return (a.account_code || '').localeCompare(b.account_code || '');
      }
      return (a.entry_date || '').localeCompare(b.entry_date || '');
    });
  };

  const loadTrialBalance = async () => {
    const { data: entries } = await supabase
      .from('journal_entries')
      .select('id')
      .gte('entry_date', dateRange.from)
      .lte('entry_date', dateRange.to);

    if (!entries || entries.length === 0) return [];

    const entryIds = entries.map(e => e.id);

    const { data: lines } = await supabase
      .from('journal_entry_lines')
      .select('account_id, debit, credit')
      .in('journal_entry_id', entryIds);

    const { data: accounts } = await supabase
      .from('chart_of_accounts')
      .select('id, code, name, account_type');

    const accountMap = new Map();
    accounts?.forEach(acc => {
      accountMap.set(acc.id, {
        code: acc.code,
        name: acc.name,
        account_type: acc.account_type,
        debit: 0,
        credit: 0
      });
    });

    lines?.forEach((line: any) => {
      if (accountMap.has(line.account_id)) {
        const acc = accountMap.get(line.account_id);
        acc.debit += parseFloat(line.debit || 0);
        acc.credit += parseFloat(line.credit || 0);
      }
    });

    return Array.from(accountMap.values())
      .filter(acc => acc.debit !== 0 || acc.credit !== 0)
      .sort((a, b) => a.code.localeCompare(b.code));
  };

  const loadFixedAssets = async () => {
    const { data, error } = await supabase
      .from('chart_of_accounts')
      .select('code, name')
      .gte('code', '1500')
      .lt('code', '2000')
      .order('code');

    if (error) throw error;
    return data?.map(asset => ({
      asset_code: asset.code,
      asset_name: asset.name,
      acquisition_date: '',
      cost: '',
      accumulated_depreciation: '',
      net_book_value: ''
    })) || [];
  };

  const exportToExcel = () => {
    if (!reportData || reportData.length === 0) {
      alert('No data to export');
      return;
    }

    let worksheetData: any[] = [];
    let filename = '';

    switch (selectedReport) {
      case 'coa':
        worksheetData = reportData.map((row: any) => ({
          'Account Code': row.code,
          'Account Name': row.name,
          'Account Type': row.account_type
        }));
        filename = 'Chart_of_Accounts.xlsx';
        break;

      case 'inventory_movement':
        worksheetData = reportData.map((row: any) => ({
          'Product Code': row.product_code,
          'Product Name': row.product_name,
          'Unit': row.unit,
          'Opening Qty': row.opening,
          'Qty In': row.in_qty,
          'Qty Out': row.out_qty,
          'Closing Qty': row.closing
        }));
        filename = `Inventory_Movement_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'sales_register':
        worksheetData = reportData.map((row: any) => ({
          'Date': row.invoice_date,
          'Invoice No': row.invoice_number,
          'Customer': row.customer_name,
          'Tax Invoice No': row.tax_invoice_no,
          'Net Amount': row.net_amount,
          'PPN': row.ppn,
          'Total': row.total_amount
        }));
        filename = `Sales_Register_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'purchase_register':
        worksheetData = reportData.map((row: any) => ({
          'Date': row.po_date,
          'PO Number': row.po_number,
          'Supplier': row.supplier_name,
          'Net Amount': row.net_amount,
          'PPN': row.ppn,
          'Total': row.total_amount,
          'Currency': row.currency
        }));
        filename = `Purchase_Register_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'journal_register':
        worksheetData = reportData.map((row: any) => ({
          'Date': row.entry_date,
          'Entry No': row.entry_number,
          'Voucher Type': row.voucher_type,
          'Account Code': row.account_code,
          'Account Name': row.account_name,
          'Debit': row.debit,
          'Credit': row.credit,
          'Narration': row.narration
        }));
        filename = `Journal_Register_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'general_ledger':
        worksheetData = reportData.map((row: any) => ({
          'Account Code': row.account_code,
          'Account Name': row.account_name,
          'Date': row.entry_date,
          'Voucher No': row.voucher_number,
          'Debit': row.debit,
          'Credit': row.credit,
          'Description': row.description
        }));
        filename = `General_Ledger_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'trial_balance':
        worksheetData = reportData.map((row: any) => ({
          'Account Code': row.code,
          'Account Name': row.name,
          'Debit': row.debit,
          'Credit': row.credit
        }));
        filename = `Trial_Balance_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'cash_ledger':
        worksheetData = reportData.map((row: any) => ({
          'Date': row.date,
          'Voucher No': row.voucher_no,
          'Account': row.account_name,
          'Debit': row.debit,
          'Credit': row.credit,
          'Narration': row.narration
        }));
        filename = `Cash_Ledger_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'bank_ledger':
        worksheetData = reportData.map((row: any) => ({
          'Date': row.date,
          'Voucher No': row.voucher_no,
          'Bank Account': row.account_name,
          'Debit': row.debit,
          'Credit': row.credit,
          'Narration': row.narration
        }));
        filename = `Bank_Ledger_${dateRange.from}_to_${dateRange.to}.xlsx`;
        break;

      case 'fixed_assets':
        worksheetData = reportData.map((row: any) => ({
          'Asset Code': row.asset_code,
          'Asset Name': row.asset_name,
          'Acquisition Date': row.acquisition_date,
          'Cost': row.cost,
          'Accumulated Depreciation': row.accumulated_depreciation,
          'Net Book Value': row.net_book_value
        }));
        filename = 'Fixed_Asset_Register.xlsx';
        break;
    }

    const worksheet = XLSX.utils.json_to_sheet(worksheetData);
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'Report');
    XLSX.writeFile(workbook, filename);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-slate-900">CA Reports - Tax Consultant Excel Exports</h2>
      </div>

      <div className="grid grid-cols-5 gap-4">
        {reports.map((report) => {
          const Icon = report.icon;
          return (
            <button
              key={report.id}
              onClick={() => setSelectedReport(report.id)}
              className={`p-4 rounded-lg border-2 text-left transition-all ${
                selectedReport === report.id
                  ? 'border-emerald-500 bg-emerald-50'
                  : report.highlight
                  ? 'border-amber-500 bg-amber-50 hover:border-amber-600'
                  : 'border-slate-200 bg-white hover:border-slate-300'
              }`}
            >
              <Icon className={`w-6 h-6 mb-2 ${
                selectedReport === report.id
                  ? 'text-emerald-600'
                  : report.highlight
                  ? 'text-amber-600'
                  : 'text-slate-600'
              }`} />
              <h3 className="font-semibold text-sm text-slate-900">{report.name}</h3>
              <p className="text-xs text-slate-500 mt-1">{report.description}</p>
            </button>
          );
        })}
      </div>

      <div className="bg-white rounded-lg border border-slate-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-slate-900">
            {reports.find(r => r.id === selectedReport)?.name}
          </h3>
          <button
            onClick={exportToExcel}
            disabled={loading || !reportData || reportData.length === 0}
            className="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export to Excel
          </button>
        </div>

        {loading ? (
          <div className="text-center py-12 text-slate-500">Loading report...</div>
        ) : error ? (
          <div className="text-center py-12">
            <div className="text-red-600 font-semibold mb-2">Error Loading Report</div>
            <div className="text-slate-600">{error}</div>
            <button
              onClick={loadReportData}
              className="mt-4 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
            >
              Retry
            </button>
          </div>
        ) : !reportData || reportData.length === 0 ? (
          <div className="text-center py-12 text-slate-500">No data available for selected period</div>
        ) : (
          <div className="overflow-x-auto max-h-[600px] overflow-y-auto">
            <div className="text-sm text-slate-600 mb-2">
              {reportData.length} record(s) found
            </div>
            <table className="min-w-full divide-y divide-slate-200 text-sm">
              <thead className="bg-slate-50 sticky top-0">
                <tr>
                  {selectedReport === 'inventory_movement' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Product Code</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Product Name</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Unit</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Opening</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700 bg-green-50">In</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700 bg-red-50">Out</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700 bg-blue-50">Closing</th>
                    </>
                  )}
                  {selectedReport === 'coa' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Code</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account Name</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Type</th>
                    </>
                  )}
                  {selectedReport === 'sales_register' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Date</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Invoice No</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Customer</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Tax Invoice</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Net</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">PPN</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Total</th>
                    </>
                  )}
                  {selectedReport === 'purchase_register' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Date</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">PO No</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Supplier</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Net</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">PPN</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Total</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Currency</th>
                    </>
                  )}
                  {selectedReport === 'cash_ledger' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Date</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Voucher No</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Debit</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Credit</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Narration</th>
                    </>
                  )}
                  {selectedReport === 'bank_ledger' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Date</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Voucher No</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Bank Account</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Debit</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Credit</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Narration</th>
                    </>
                  )}
                  {selectedReport === 'journal_register' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Date</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Entry No</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Voucher Type</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account Code</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account Name</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Debit</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Credit</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Narration</th>
                    </>
                  )}
                  {selectedReport === 'general_ledger' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account Code</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account Name</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Date</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Voucher No</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Debit</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Credit</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Description</th>
                    </>
                  )}
                  {selectedReport === 'trial_balance' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Code</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Account Name</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Debit</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Credit</th>
                    </>
                  )}
                  {selectedReport === 'fixed_assets' && (
                    <>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Asset Code</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Asset Name</th>
                      <th className="px-4 py-3 text-left font-medium text-slate-700">Acquisition Date</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Cost</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Acc. Depreciation</th>
                      <th className="px-4 py-3 text-right font-medium text-slate-700">Net Book Value</th>
                    </>
                  )}
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-slate-200">
                {selectedReport === 'inventory_movement' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900">{row.product_code}</td>
                    <td className="px-4 py-3 text-slate-900">{row.product_name}</td>
                    <td className="px-4 py-3 text-slate-600">{row.unit}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{row.opening}</td>
                    <td className="px-4 py-3 text-right text-green-600 bg-green-50">{row.in_qty}</td>
                    <td className="px-4 py-3 text-right text-red-600 bg-red-50">{row.out_qty}</td>
                    <td className="px-4 py-3 text-right font-semibold text-blue-600 bg-blue-50">{row.closing}</td>
                  </tr>
                ))}
                {selectedReport === 'coa' && reportData.map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900 font-mono">{row.code}</td>
                    <td className="px-4 py-3 text-slate-900">{row.name}</td>
                    <td className="px-4 py-3 text-slate-600">{row.account_type}</td>
                  </tr>
                ))}
                {selectedReport === 'sales_register' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900">{row.invoice_date}</td>
                    <td className="px-4 py-3 text-slate-900">{row.invoice_number}</td>
                    <td className="px-4 py-3 text-slate-900">{row.customer_name}</td>
                    <td className="px-4 py-3 text-slate-600">{row.tax_invoice_no}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.net_amount || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.ppn || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right font-semibold text-slate-900">{parseFloat(row.total_amount || 0).toFixed(2)}</td>
                  </tr>
                ))}
                {selectedReport === 'purchase_register' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900">{row.po_date}</td>
                    <td className="px-4 py-3 text-slate-900">{row.po_number}</td>
                    <td className="px-4 py-3 text-slate-900">{row.supplier_name}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.net_amount || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.ppn || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right font-semibold text-slate-900">{parseFloat(row.total_amount || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-slate-600">{row.currency}</td>
                  </tr>
                ))}
                {selectedReport === 'cash_ledger' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900">{row.date}</td>
                    <td className="px-4 py-3 text-slate-900">{row.voucher_no}</td>
                    <td className="px-4 py-3 text-slate-900">{row.account_name}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.debit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.credit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-slate-600">{row.narration}</td>
                  </tr>
                ))}
                {selectedReport === 'bank_ledger' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900">{row.date}</td>
                    <td className="px-4 py-3 text-slate-900">{row.voucher_no}</td>
                    <td className="px-4 py-3 text-slate-900">{row.account_name}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.debit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.credit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-slate-600">{row.narration}</td>
                  </tr>
                ))}
                {selectedReport === 'journal_register' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900">{row.entry_date}</td>
                    <td className="px-4 py-3 text-slate-900">{row.entry_number}</td>
                    <td className="px-4 py-3 text-slate-600">{row.voucher_type}</td>
                    <td className="px-4 py-3 text-slate-900 font-mono">{row.account_code}</td>
                    <td className="px-4 py-3 text-slate-900">{row.account_name}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.debit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.credit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-slate-600">{row.narration}</td>
                  </tr>
                ))}
                {selectedReport === 'general_ledger' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900 font-mono">{row.account_code}</td>
                    <td className="px-4 py-3 text-slate-900">{row.account_name}</td>
                    <td className="px-4 py-3 text-slate-900">{row.entry_date}</td>
                    <td className="px-4 py-3 text-slate-900">{row.voucher_number}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.debit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.credit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-slate-600">{row.description}</td>
                  </tr>
                ))}
                {selectedReport === 'trial_balance' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900 font-mono">{row.code}</td>
                    <td className="px-4 py-3 text-slate-900">{row.name}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.debit || 0).toFixed(2)}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{parseFloat(row.credit || 0).toFixed(2)}</td>
                  </tr>
                ))}
                {selectedReport === 'fixed_assets' && reportData.slice(0, 100).map((row: any, idx: number) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="px-4 py-3 text-slate-900 font-mono">{row.asset_code}</td>
                    <td className="px-4 py-3 text-slate-900">{row.asset_name}</td>
                    <td className="px-4 py-3 text-slate-900">{row.acquisition_date}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{row.cost}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{row.accumulated_depreciation}</td>
                    <td className="px-4 py-3 text-right text-slate-900">{row.net_book_value}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {reportData.length > 100 && (
              <div className="text-center py-4 text-slate-500 text-sm">
                Showing first 100 records. Export to Excel to see all {reportData.length} records.
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
