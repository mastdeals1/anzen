import { useEffect, useState, useCallback } from 'react';
import { supabase } from '../../lib/supabase';
import { Plus, Wallet, ArrowDownCircle, ArrowUpCircle, RefreshCw, Upload, X, FileText, Image, Eye, Edit2, Trash2, ExternalLink, Download, Clipboard, DollarSign, Package, Truck, Building2 } from 'lucide-react';
import { Modal } from '../Modal';
import { useFinance } from '../../contexts/FinanceContext';

interface PettyCashDocument {
  id: string;
  file_type: string;
  file_name: string;
  file_url: string;
  file_size: number | null;
  uploaded_at?: string;
  created_at?: string;
}

interface PettyCashTransaction {
  id: string;
  transaction_number: string;
  transaction_date: string;
  transaction_type: 'withdraw' | 'expense';
  amount: number;
  description: string;
  expense_category: string | null;
  bank_account_id: string | null;
  paid_to: string | null;
  paid_by_staff_id: string | null;
  paid_by_staff_name: string | null;
  source: string | null;
  received_by_staff_id: string | null;
  received_by_staff_name: string | null;
  import_container_id: string | null;
  delivery_challan_id: string | null;
  voucher_number: string | null;
  bank_accounts?: { account_name: string; bank_name: string; alias: string | null; currency: string } | null;
  import_containers?: { container_ref: string } | null;
  delivery_challans?: { challan_number: string } | null;
  created_at: string;
  petty_cash_documents?: PettyCashDocument[];
}

interface ImportContainer {
  id: string;
  container_ref: string;
}

interface DeliveryChallan {
  id: string;
  challan_number: string;
  challan_date: string;
  customers?: {
    company_name: string;
  } | null;
}

interface BankAccount {
  id: string;
  bank_name: string;
  account_number: string;
  alias: string | null;
  currency: string;
}

interface PettyCashManagerProps {
  canManage: boolean;
  onNavigateToFundTransfer?: () => void;
}

const expenseCategories = [
  {
    value: 'duty_customs',
    label: 'Duty & Customs (BM)',
    type: 'import',
    icon: Building2,
    description: 'Import duties and customs charges - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'ppn_import',
    label: 'PPN Import',
    type: 'operations',
    icon: DollarSign,
    description: 'Import VAT - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Operations'
  },
  {
    value: 'pph_import',
    label: 'PPh Import',
    type: 'import',
    icon: Building2,
    description: 'Import withholding tax - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'freight_import',
    label: 'Freight (Import)',
    type: 'import',
    icon: Package,
    description: 'International freight charges - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'clearing_forwarding',
    label: 'Clearing & Forwarding',
    type: 'import',
    icon: Building2,
    description: 'Customs clearance - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'port_charges',
    label: 'Port Charges',
    type: 'import',
    icon: Building2,
    description: 'Port handling charges - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'container_handling',
    label: 'Container Handling',
    type: 'import',
    icon: Package,
    description: 'Container unloading - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'transport_import',
    label: 'Transportation (Import)',
    type: 'import',
    icon: Truck,
    description: 'Port to godown transport - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'loading_import',
    label: 'Loading / Unloading (Import)',
    type: 'import',
    icon: Truck,
    description: 'Import container loading/unloading - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'bpom_ski_fees',
    label: 'BPOM / SKI Fees',
    type: 'import',
    icon: FileText,
    description: 'BPOM/SKI regulatory fees - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'other_import',
    label: 'Other (Import)',
    type: 'import',
    icon: DollarSign,
    description: 'Other import-related expenses - CAPITALIZED to inventory',
    requiresContainer: true,
    group: 'Import Costs'
  },
  {
    value: 'delivery_sales',
    label: 'Delivery / Dispatch (Sales)',
    type: 'sales',
    icon: Truck,
    description: 'Customer delivery - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Sales & Distribution'
  },
  {
    value: 'loading_sales',
    label: 'Loading / Unloading (Sales)',
    type: 'sales',
    icon: Truck,
    description: 'Sales loading charges - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Sales & Distribution'
  },
  {
    value: 'other_sales',
    label: 'Other (Sales)',
    type: 'sales',
    icon: DollarSign,
    description: 'Other sales-related expenses - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Sales & Distribution'
  },
  {
    value: 'salary',
    label: 'Salary',
    type: 'staff',
    icon: DollarSign,
    description: 'Staff salaries - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Staff Costs'
  },
  {
    value: 'staff_overtime',
    label: 'Staff Overtime',
    type: 'staff',
    icon: DollarSign,
    description: 'Overtime payments - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Staff Costs'
  },
  {
    value: 'staff_welfare',
    label: 'Staff Welfare / Allowances',
    type: 'staff',
    icon: DollarSign,
    description: 'Driver food, snacks, overtime meals, welfare - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Staff Costs'
  },
  {
    value: 'travel_conveyance',
    label: 'Travel & Conveyance',
    type: 'staff',
    icon: Truck,
    description: 'Local travel, taxi, fuel reimbursements, tolls - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Staff Costs'
  },
  {
    value: 'warehouse_rent',
    label: 'Warehouse Rent',
    type: 'operations',
    icon: Building2,
    description: 'Rent expense - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Operations'
  },
  {
    value: 'utilities',
    label: 'Utilities',
    type: 'operations',
    icon: Building2,
    description: 'Electricity, water, etc - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Operations'
  },
  {
    value: 'bank_charges',
    label: 'Bank Charges',
    type: 'operations',
    icon: DollarSign,
    description: 'Bank fees, charges, and transaction costs - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Operations'
  },
  {
    value: 'office_admin',
    label: 'Office & Admin',
    type: 'admin',
    icon: Building2,
    description: 'General admin expenses - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Administrative'
  },
  {
    value: 'office_shifting_renovation',
    label: 'Office Shifting & Renovation',
    type: 'admin',
    icon: Building2,
    description: 'Office shifting, partition work, electrical, cabling, interior renovation - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Administrative'
  },
  {
    value: 'fixed_assets',
    label: 'Fixed Assets / Equipment',
    type: 'assets',
    icon: Package,
    description: 'Purchase of fixed assets - CAPITALIZED (see Asset Guide)',
    requiresContainer: false,
    group: 'Assets'
  },
  {
    value: 'other',
    label: 'Other',
    type: 'admin',
    icon: DollarSign,
    description: 'Miscellaneous expenses - EXPENSED to P&L',
    requiresContainer: false,
    group: 'Administrative'
  },
];

export function PettyCashManager({ canManage, onNavigateToFundTransfer }: PettyCashManagerProps) {
  const [transactions, setTransactions] = useState<PettyCashTransaction[]>([]);
  const [containers, setContainers] = useState<ImportContainer[]>([]);
  const [challans, setChallans] = useState<DeliveryChallan[]>([]);
  const [bankAccounts, setBankAccounts] = useState<BankAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [viewModalOpen, setViewModalOpen] = useState(false);
  const [viewingTransaction, setViewingTransaction] = useState<PettyCashTransaction | null>(null);
  const [editingTransaction, setEditingTransaction] = useState<PettyCashTransaction | null>(null);
  const [cashBalance, setCashBalance] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const [uploadingFiles, setUploadingFiles] = useState<File[]>([]);
  const [sortConfig, setSortConfig] = useState<{ key: string; direction: 'asc' | 'desc' } | null>(null);
  const [showPasteHint, setShowPasteHint] = useState(false);
  const [filterType, setFilterType] = useState<'all' | 'import' | 'sales' | 'staff' | 'operations' | 'admin' | 'assets'>('all');
  const [categoryFilter, setCategoryFilter] = useState<string>('all');

  const { dateRange } = useFinance();
  const startDate = dateRange.startDate;
  const endDate = dateRange.endDate;

  const [formData, setFormData] = useState({
    transaction_type: 'expense' as 'withdraw' | 'expense',
    transaction_date: new Date().toISOString().split('T')[0],
    amount: 0,
    description: '',
    expense_category: '',
    bank_account_id: '',
    paid_to: '',
    paid_by_staff_name: '',
    paid_by: 'cash' as 'cash' | 'bank',
    source: '',
    received_by_staff_name: '',
    import_container_id: '',
    delivery_challan_id: '',
  });

  const loadData = useCallback(async () => {
    try {
      const [txRes, balanceRes, containersRes, challansRes, bankRes] = await Promise.all([
        supabase
          .from('petty_cash_transactions')
          .select(`
            *,
            bank_accounts:bank_account_id (
              account_name,
              bank_name,
              alias,
              currency
            ),
            import_containers:import_container_id (
              container_ref
            ),
            delivery_challans:delivery_challan_id (
              challan_number
            ),
            petty_cash_documents (*)
          `)
          .gte('transaction_date', startDate)
          .lte('transaction_date', endDate)
          .order('transaction_date', { ascending: false })
          .order('transaction_number', { ascending: false }),

        supabase.rpc('get_petty_cash_balance'),

        supabase
          .from('import_containers')
          .select('id, container_ref')
          .order('container_ref', { ascending: false }),

        supabase
          .from('delivery_challans')
          .select(`
            id,
            challan_number,
            challan_date,
            customers:customer_id (
              company_name
            )
          `)
          .order('challan_date', { ascending: false }),

        supabase
          .from('bank_accounts')
          .select('*')
          .order('bank_name', { ascending: true })
      ]);

      if (txRes.error) throw txRes.error;
      if (balanceRes.error) throw balanceRes.error;

      setTransactions(txRes.data || []);
      setCashBalance(balanceRes.data || 0);
      setContainers(containersRes.data || []);
      setChallans(challansRes.data || []);
      setBankAccounts(bankRes.data || []);
    } catch (error: any) {
      console.error('Error loading petty cash data:', error);
      alert('Failed to load petty cash data: ' + error.message);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [startDate, endDate]);

  useEffect(() => {
    loadData();

    const subscription = supabase
      .channel('petty-cash-changes')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'petty_cash_transactions' },
        () => {
          loadData();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [loadData]);

  const handleRefresh = () => {
    setRefreshing(true);
    loadData();
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;

    setUploadingFiles(files);
  };

  const handlePaste = async (e: React.ClipboardEvent) => {
    const items = Array.from(e.clipboardData.items);
    const imageItems = items.filter(item => item.type.startsWith('image/'));

    if (imageItems.length > 0) {
      e.preventDefault();
      const files = await Promise.all(
        imageItems.map(item => {
          const blob = item.getAsFile();
          if (blob) {
            return new File([blob], `pasted-image-${Date.now()}.png`, { type: blob.type });
          }
          return null;
        })
      );

      const validFiles = files.filter((f): f is File => f !== null);
      if (validFiles.length > 0) {
        setUploadingFiles(prev => [...prev, ...validFiles]);
      }
    }
  };

  const removeUploadingFile = (index: number) => {
    setUploadingFiles(prev => prev.filter((_, i) => i !== index));
  };

  const openAddModal = () => {
    setEditingTransaction(null);
    setFormData({
      transaction_type: 'expense',
      transaction_date: new Date().toISOString().split('T')[0],
      amount: 0,
      description: '',
      expense_category: '',
      bank_account_id: '',
      paid_to: '',
      paid_by_staff_name: '',
      paid_by: 'cash',
      source: '',
      received_by_staff_name: '',
      import_container_id: '',
      delivery_challan_id: '',
    });
    setUploadingFiles([]);
    setModalOpen(true);
  };

  const openEditModal = (transaction: PettyCashTransaction) => {
    setEditingTransaction(transaction);
    setFormData({
      transaction_type: transaction.transaction_type,
      transaction_date: transaction.transaction_date,
      amount: transaction.amount,
      description: transaction.description,
      expense_category: transaction.expense_category || '',
      bank_account_id: transaction.bank_account_id || '',
      paid_to: transaction.paid_to || '',
      paid_by_staff_name: transaction.paid_by_staff_name || '',
      paid_by: 'cash',
      source: transaction.source || '',
      received_by_staff_name: transaction.received_by_staff_name || '',
      import_container_id: transaction.import_container_id || '',
      delivery_challan_id: transaction.delivery_challan_id || '',
    });
    setUploadingFiles([]);
    setModalOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (formData.transaction_type === 'expense' && !formData.expense_category) {
      alert('Please select an expense category');
      return;
    }

    const selectedCategory = expenseCategories.find(c => c.value === formData.expense_category);
    if (selectedCategory?.requiresContainer && !formData.import_container_id) {
      alert(`${selectedCategory.label} requires linking to an import container`);
      return;
    }

    try {
      const payload = {
        transaction_type: formData.transaction_type,
        transaction_date: formData.transaction_date,
        amount: formData.amount,
        description: formData.description,
        expense_category: formData.transaction_type === 'expense' ? formData.expense_category : null,
        bank_account_id: formData.transaction_type === 'withdraw' ? formData.bank_account_id : null,
        paid_to: formData.transaction_type === 'expense' ? formData.paid_to : null,
        paid_by_staff_name: formData.transaction_type === 'expense' ? formData.paid_by_staff_name : null,
        source: formData.transaction_type === 'withdraw' ? formData.source : null,
        received_by_staff_name: formData.transaction_type === 'withdraw' ? formData.received_by_staff_name : null,
        import_container_id: formData.import_container_id || null,
        delivery_challan_id: formData.delivery_challan_id || null,
      };

      let transactionId: string;

      if (editingTransaction) {
        const { error } = await supabase
          .from('petty_cash_transactions')
          .update(payload)
          .eq('id', editingTransaction.id);

        if (error) throw error;
        transactionId = editingTransaction.id;
      } else {
        const { data, error } = await supabase
          .from('petty_cash_transactions')
          .insert([payload])
          .select('id')
          .single();

        if (error) throw error;
        if (!data) throw new Error('Failed to create transaction');
        transactionId = data.id;
      }

      // Upload documents if any
      if (uploadingFiles.length > 0) {
        const uploadPromises = uploadingFiles.map(async (file) => {
          const fileExt = file.name.split('.').pop();
          const fileName = `${transactionId}_${Date.now()}.${fileExt}`;
          const filePath = `${fileName}`;

          const { error: uploadError } = await supabase.storage
            .from('petty-cash-receipts')
            .upload(filePath, file);

          if (uploadError) throw uploadError;

          const { data: { publicUrl } } = supabase.storage
            .from('petty-cash-receipts')
            .getPublicUrl(filePath);

          // Save document record
          const { error: docError } = await supabase
            .from('petty_cash_documents')
            .insert([{
              petty_cash_transaction_id: transactionId,
              file_type: file.type,
              file_name: file.name,
              file_url: publicUrl,
              file_size: file.size,
            }]);

          if (docError) throw docError;
        });

        await Promise.all(uploadPromises);
      }

      alert(editingTransaction ? 'Petty cash transaction updated successfully!' : 'Petty cash transaction added successfully!');
      setModalOpen(false);
      loadData();
    } catch (error: any) {
      console.error('Error saving petty cash transaction:', error);
      alert('Failed to save transaction: ' + error.message);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this transaction?')) return;

    try {
      const { error } = await supabase
        .from('petty_cash_transactions')
        .delete()
        .eq('id', id);

      if (error) throw error;
      alert('Transaction deleted successfully!');
      loadData();
    } catch (error: any) {
      console.error('Error deleting transaction:', error);
      alert('Failed to delete transaction: ' + error.message);
    }
  };

  const viewTransaction = (transaction: PettyCashTransaction) => {
    setViewingTransaction(transaction);
    setViewModalOpen(true);
  };

  const handleSort = (key: string) => {
    let direction: 'asc' | 'desc' = 'asc';
    if (sortConfig && sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const sortedTransactions = [...transactions].sort((a, b) => {
    if (!sortConfig) return 0;

    const aValue = a[sortConfig.key as keyof PettyCashTransaction];
    const bValue = b[sortConfig.key as keyof PettyCashTransaction];

    if (aValue === null || aValue === undefined) return 1;
    if (bValue === null || bValue === undefined) return -1;

    if (aValue < bValue) return sortConfig.direction === 'asc' ? -1 : 1;
    if (aValue > bValue) return sortConfig.direction === 'asc' ? 1 : -1;
    return 0;
  });

  const filteredTransactions = sortedTransactions.filter(tx => {
    if (filterType !== 'all' && tx.transaction_type === 'expense') {
      const category = expenseCategories.find(c => c.value === tx.expense_category);
      if (!category || category.type !== filterType) return false;
    }

    if (categoryFilter !== 'all' && tx.expense_category !== categoryFilter) {
      return false;
    }

    return true;
  });

  const getCategoryInfo = (value: string) => {
    return expenseCategories.find(c => c.value === value);
  };

  const selectedCategory = getCategoryInfo(formData.expense_category);

  if (loading) {
    return <div className="flex items-center justify-center h-64">Loading petty cash data...</div>;
  }

  const totalExpense = filteredTransactions
    .filter(t => t.transaction_type === 'expense')
    .reduce((sum, t) => sum + Number(t.amount), 0);

  const totalWithdraw = filteredTransactions
    .filter(t => t.transaction_type === 'withdraw')
    .reduce((sum, t) => sum + Number(t.amount), 0);

  const groupedCategories = expenseCategories.reduce((acc, cat) => {
    if (!acc[cat.group]) {
      acc[cat.group] = [];
    }
    acc[cat.group].push(cat);
    return acc;
  }, {} as Record<string, typeof expenseCategories>);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-gray-900">Petty Cash Management</h2>
          <p className="text-sm text-gray-600 mt-1">Track cash withdrawals and expenses with full categorization</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="p-2 text-gray-600 hover:text-gray-900 disabled:opacity-50"
            title="Refresh"
          >
            <RefreshCw className={`h-5 w-5 ${refreshing ? 'animate-spin' : ''}`} />
          </button>
          {canManage && (
            <button
              onClick={openAddModal}
              className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              <Plus className="h-5 w-5" />
              Add Transaction
            </button>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-green-600 font-medium">Current Cash Balance</p>
              <p className="text-2xl font-bold text-green-900 mt-1">
                Rp {cashBalance.toLocaleString()}
              </p>
            </div>
            <Wallet className="h-10 w-10 text-green-600" />
          </div>
        </div>

        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-blue-600 font-medium">Total Withdrawals (Period)</p>
              <p className="text-2xl font-bold text-blue-900 mt-1">
                Rp {totalWithdraw.toLocaleString()}
              </p>
            </div>
            <ArrowDownCircle className="h-10 w-10 text-blue-600" />
          </div>
        </div>

        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-red-600 font-medium">Total Expenses (Period)</p>
              <p className="text-2xl font-bold text-red-900 mt-1">
                Rp {totalExpense.toLocaleString()}
              </p>
            </div>
            <ArrowUpCircle className="h-10 w-10 text-red-600" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow p-4">
        <div className="flex items-center gap-4 mb-4 flex-wrap">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Filter by Type</label>
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value as any)}
              className="px-3 py-2 border border-gray-300 rounded-lg"
            >
              <option value="all">All Types</option>
              <option value="import">Import Costs</option>
              <option value="sales">Sales & Distribution</option>
              <option value="staff">Staff Costs</option>
              <option value="operations">Operations</option>
              <option value="admin">Administrative</option>
              <option value="assets">Assets</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Filter by Category</label>
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-lg"
            >
              <option value="all">All Categories</option>
              {expenseCategories.map(cat => (
                <option key={cat.value} value={cat.value}>{cat.label}</option>
              ))}
            </select>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th onClick={() => handleSort('transaction_date')} className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                  Date {sortConfig?.key === 'transaction_date' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                </th>
                <th onClick={() => handleSort('transaction_number')} className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                  Number {sortConfig?.key === 'transaction_number' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Description</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Linked To</th>
                <th onClick={() => handleSort('amount')} className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100">
                  Amount {sortConfig?.key === 'amount' && (sortConfig.direction === 'asc' ? '↑' : '↓')}
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredTransactions.map((tx) => {
                const categoryInfo = tx.expense_category ? getCategoryInfo(tx.expense_category) : null;
                const Icon = categoryInfo?.icon;

                return (
                  <tr key={tx.id} className="hover:bg-gray-50">
                    <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                      {new Date(tx.transaction_date).toLocaleDateString()}
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-medium text-blue-600">{tx.transaction_number}</span>
                        {tx.voucher_number && (
                          <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">
                            {tx.voucher_number}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${
                        tx.transaction_type === 'withdraw'
                          ? 'bg-blue-100 text-blue-800'
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {tx.transaction_type === 'withdraw' ? (
                          <>
                            <ArrowDownCircle className="h-3 w-3" />
                            Withdrawal
                          </>
                        ) : (
                          <>
                            <ArrowUpCircle className="h-3 w-3" />
                            Expense
                          </>
                        )}
                      </span>
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap">
                      {categoryInfo && (
                        <div className="flex items-center gap-2">
                          {Icon && <Icon className="h-4 w-4 text-gray-500" />}
                          <span className="text-sm text-gray-900">{categoryInfo.label}</span>
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600">
                      <div className="max-w-xs truncate">
                        {tx.description}
                        {tx.paid_to && <div className="text-xs text-gray-500">To: {tx.paid_to}</div>}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm">
                      <div className="space-y-1">
                        {tx.import_containers && (
                          <div className="flex items-center gap-1 text-purple-600">
                            <Package className="h-3 w-3" />
                            <span className="text-xs">{tx.import_containers.container_ref}</span>
                          </div>
                        )}
                        {tx.delivery_challans && (
                          <div className="flex items-center gap-1 text-green-600">
                            <Truck className="h-3 w-3" />
                            <span className="text-xs">{tx.delivery_challans.challan_number}</span>
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-right">
                      <span className={`text-sm font-medium ${
                        tx.transaction_type === 'withdraw' ? 'text-blue-600' : 'text-red-600'
                      }`}>
                        Rp {Number(tx.amount).toLocaleString()}
                      </span>
                    </td>
                    <td className="px-4 py-3 whitespace-nowrap text-right text-sm">
                      <div className="flex items-center justify-end gap-2">
                        <button
                          onClick={() => viewTransaction(tx)}
                          className="text-blue-600 hover:text-blue-900"
                          title="View Details"
                        >
                          <Eye className="h-4 w-4" />
                        </button>
                        {canManage && (
                          <>
                            <button
                              onClick={() => openEditModal(tx)}
                              className="text-yellow-600 hover:text-yellow-900"
                              title="Edit"
                            >
                              <Edit2 className="h-4 w-4" />
                            </button>
                            <button
                              onClick={() => handleDelete(tx.id)}
                              className="text-red-600 hover:text-red-900"
                              title="Delete"
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {filteredTransactions.length === 0 && (
          <div className="text-center py-12 text-gray-500">
            No transactions found for the selected period and filters
          </div>
        )}
      </div>

      <Modal isOpen={modalOpen} onClose={() => setModalOpen(false)} title={editingTransaction ? 'Edit Transaction' : 'Add Petty Cash Transaction'}>
        <form onSubmit={handleSubmit} className="space-y-4" onPaste={handlePaste}>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Transaction Type</label>
            <select
              value={formData.transaction_type}
              onChange={(e) => setFormData({ ...formData, transaction_type: e.target.value as 'withdraw' | 'expense' })}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              required
            >
              <option value="expense">Expense (Cash Out)</option>
              <option value="withdraw">Withdraw from Bank</option>
            </select>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Date</label>
              <input
                type="date"
                value={formData.transaction_date}
                onChange={(e) => setFormData({ ...formData, transaction_date: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Amount (Rp)</label>
              <input
                type="number"
                value={formData.amount || ''}
                onChange={(e) => setFormData({ ...formData, amount: parseFloat(e.target.value) || 0 })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                required
                min="0"
                step="0.01"
              />
            </div>
          </div>

          {formData.transaction_type === 'expense' && (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Expense Category <span className="text-red-500">*</span>
                </label>
                <div className="space-y-2 max-h-96 overflow-y-auto border border-gray-200 rounded-lg p-3">
                  {Object.entries(groupedCategories).map(([group, categories]) => (
                    <div key={group} className="space-y-1">
                      <div className="text-xs font-semibold text-gray-500 uppercase tracking-wider px-2 py-1 bg-gray-50">
                        {group}
                      </div>
                      {categories.map((cat) => {
                        const Icon = cat.icon;
                        return (
                          <label
                            key={cat.value}
                            className={`flex items-start gap-3 p-3 rounded-lg cursor-pointer transition-colors ${
                              formData.expense_category === cat.value
                                ? 'bg-blue-50 border-2 border-blue-500'
                                : 'hover:bg-gray-50 border-2 border-transparent'
                            }`}
                          >
                            <input
                              type="radio"
                              name="expense_category"
                              value={cat.value}
                              checked={formData.expense_category === cat.value}
                              onChange={(e) => setFormData({ ...formData, expense_category: e.target.value })}
                              className="mt-1"
                            />
                            <Icon className="h-5 w-5 text-gray-400 flex-shrink-0 mt-0.5" />
                            <div className="flex-1">
                              <div className="font-medium text-gray-900">{cat.label}</div>
                              <div className="text-xs text-gray-600 mt-0.5">{cat.description}</div>
                              {cat.requiresContainer && (
                                <div className="text-xs text-orange-600 mt-1 font-medium">⚠️ Requires Container Link</div>
                              )}
                            </div>
                          </label>
                        );
                      })}
                    </div>
                  ))}
                </div>
              </div>

              {selectedCategory?.requiresContainer && (
                <div className="bg-orange-50 border border-orange-200 rounded-lg p-3">
                  <div className="flex items-start gap-2">
                    <Package className="h-5 w-5 text-orange-600 flex-shrink-0 mt-0.5" />
                    <div>
                      <div className="text-sm font-medium text-orange-900">Import Container Required</div>
                      <div className="text-xs text-orange-700 mt-1">
                        This expense category requires linking to an import container for proper cost allocation
                      </div>
                    </div>
                  </div>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Link to Container {selectedCategory?.requiresContainer && <span className="text-red-500">*</span>}
                  </label>
                  <select
                    value={formData.import_container_id}
                    onChange={(e) => setFormData({ ...formData, import_container_id: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    required={selectedCategory?.requiresContainer}
                  >
                    <option value="">None</option>
                    {containers.map((c) => (
                      <option key={c.id} value={c.id}>{c.container_ref}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Link to Delivery Challan (Sales)</label>
                  <select
                    value={formData.delivery_challan_id}
                    onChange={(e) => setFormData({ ...formData, delivery_challan_id: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  >
                    <option value="">None</option>
                    {challans.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.challan_number} - {c.customers?.company_name} ({new Date(c.challan_date).toLocaleDateString()})
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Paid To</label>
                  <input
                    type="text"
                    value={formData.paid_to}
                    onChange={(e) => setFormData({ ...formData, paid_to: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    placeholder="Vendor/Supplier name"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Paid By (Staff)</label>
                  <input
                    type="text"
                    value={formData.paid_by_staff_name}
                    onChange={(e) => setFormData({ ...formData, paid_by_staff_name: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    placeholder="Staff member name"
                  />
                </div>
              </div>
            </>
          )}

          {formData.transaction_type === 'withdraw' && (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Bank Account</label>
                <select
                  value={formData.bank_account_id}
                  onChange={(e) => setFormData({ ...formData, bank_account_id: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                >
                  <option value="">Select bank account</option>
                  {bankAccounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.alias || acc.bank_name} - {acc.account_number} ({acc.currency})
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Source/Reference</label>
                  <input
                    type="text"
                    value={formData.source}
                    onChange={(e) => setFormData({ ...formData, source: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    placeholder="Check number, transfer ref"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Received By</label>
                  <input
                    type="text"
                    value={formData.received_by_staff_name}
                    onChange={(e) => setFormData({ ...formData, received_by_staff_name: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    placeholder="Staff member name"
                  />
                </div>
              </div>
            </>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              rows={3}
              required
              placeholder="Enter transaction details"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Upload Documents/Receipts
            </label>
            <div className="border-2 border-dashed border-gray-300 rounded-lg p-4 text-center hover:border-blue-500 transition-colors">
              <input
                type="file"
                onChange={handleFileUpload}
                accept="image/*,.pdf"
                multiple
                className="hidden"
                id="file-upload"
              />
              <label htmlFor="file-upload" className="cursor-pointer">
                <Upload className="h-8 w-8 text-gray-400 mx-auto mb-2" />
                <p className="text-sm text-gray-600">Click to upload or drag and drop</p>
                <p className="text-xs text-gray-500 mt-1">Images or PDF files</p>
              </label>
              {!showPasteHint && uploadingFiles.length === 0 && (
                <button
                  type="button"
                  onClick={() => setShowPasteHint(true)}
                  className="text-xs text-blue-600 hover:text-blue-700 mt-2"
                >
                  💡 You can also paste images here
                </button>
              )}
            </div>

            {uploadingFiles.length > 0 && (
              <div className="mt-3 space-y-2">
                <p className="text-sm font-medium text-gray-700">{uploadingFiles.length} file(s) ready:</p>
                <div className="space-y-1">
                  {uploadingFiles.map((file, idx) => (
                    <div key={idx} className="flex items-center justify-between bg-gray-50 px-3 py-2 rounded">
                      <div className="flex items-center gap-2">
                        {file.type.startsWith('image/') ? (
                          <Image className="h-4 w-4 text-blue-600" />
                        ) : (
                          <FileText className="h-4 w-4 text-red-600" />
                        )}
                        <span className="text-sm text-gray-700">{file.name}</span>
                        <span className="text-xs text-gray-500">({(file.size / 1024).toFixed(1)} KB)</span>
                      </div>
                      <button
                        type="button"
                        onClick={() => removeUploadingFile(idx)}
                        className="text-red-600 hover:text-red-800"
                      >
                        <X className="h-4 w-4" />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div className="flex justify-end gap-3 pt-4">
            <button
              type="button"
              onClick={() => setModalOpen(false)}
              className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              {editingTransaction ? 'Update' : 'Save'} Transaction
            </button>
          </div>
        </form>
      </Modal>

      <Modal isOpen={viewModalOpen} onClose={() => setViewModalOpen(false)} title="Transaction Details">
        {viewingTransaction && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-500">Transaction Number</label>
                <p className="text-gray-900 font-medium">{viewingTransaction.transaction_number}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-500">Date</label>
                <p className="text-gray-900">{new Date(viewingTransaction.transaction_date).toLocaleDateString()}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-sm font-medium text-gray-500">Type</label>
                <p className="text-gray-900 capitalize">{viewingTransaction.transaction_type}</p>
              </div>
              <div>
                <label className="text-sm font-medium text-gray-500">Amount</label>
                <p className="text-gray-900 font-bold">Rp {Number(viewingTransaction.amount).toLocaleString()}</p>
              </div>
            </div>

            {viewingTransaction.expense_category && (
              <div>
                <label className="text-sm font-medium text-gray-500">Category</label>
                <p className="text-gray-900">{getCategoryInfo(viewingTransaction.expense_category)?.label}</p>
              </div>
            )}

            {viewingTransaction.import_containers && (
              <div>
                <label className="text-sm font-medium text-gray-500">Linked Container</label>
                <p className="text-gray-900">{viewingTransaction.import_containers.container_ref}</p>
              </div>
            )}

            {viewingTransaction.delivery_challans && (
              <div>
                <label className="text-sm font-medium text-gray-500">Linked Delivery Challan</label>
                <p className="text-gray-900">{viewingTransaction.delivery_challans.challan_number}</p>
              </div>
            )}

            <div>
              <label className="text-sm font-medium text-gray-500">Description</label>
              <p className="text-gray-900">{viewingTransaction.description}</p>
            </div>

            {viewingTransaction.paid_to && (
              <div>
                <label className="text-sm font-medium text-gray-500">Paid To</label>
                <p className="text-gray-900">{viewingTransaction.paid_to}</p>
              </div>
            )}

            {viewingTransaction.petty_cash_documents && viewingTransaction.petty_cash_documents.length > 0 && (
              <div>
                <label className="text-sm font-medium text-gray-500 mb-2 block">Attached Documents</label>
                <div className="space-y-2">
                  {viewingTransaction.petty_cash_documents.map((doc) => (
                    <div key={doc.id} className="flex items-center justify-between bg-gray-50 px-3 py-2 rounded">
                      <div className="flex items-center gap-2">
                        {doc.file_type.startsWith('image/') ? (
                          <Image className="h-4 w-4 text-blue-600" />
                        ) : (
                          <FileText className="h-4 w-4 text-red-600" />
                        )}
                        <span className="text-sm text-gray-700">{doc.file_name}</span>
                      </div>
                      <a
                        href={doc.file_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-600 hover:text-blue-800"
                      >
                        <ExternalLink className="h-4 w-4" />
                      </a>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </Modal>

      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex items-start gap-3">
          <FileText className="h-5 w-5 text-blue-600 flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <h4 className="text-sm font-semibold text-blue-900 mb-2">Recording Fixed Assets</h4>
            <div className="text-sm text-blue-800 space-y-2">
              <p><strong>For Equipment/Asset Purchases:</strong></p>
              <ol className="list-decimal list-inside space-y-1 ml-2">
                <li>Use category "Fixed Assets / Equipment"</li>
                <li>Record the purchase here with full details</li>
                <li>This creates a debit to "Fixed Assets" account</li>
                <li>Assets are CAPITALIZED (not expensed immediately)</li>
                <li>Later: Finance team will set up depreciation schedule</li>
              </ol>
              <p className="text-xs mt-2 bg-blue-100 p-2 rounded">
                💡 Examples: Computers, machinery, furniture, vehicles, AC units, shelving
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
