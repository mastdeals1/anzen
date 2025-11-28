import { useEffect, useState } from 'react';
import { Layout } from '../components/Layout';
import { DataTable } from '../components/DataTable';
import { Modal } from '../components/Modal';
import { useLanguage } from '../contexts/LanguageContext';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { Plus, Edit, Trash2, DollarSign, TrendingUp, TrendingDown, CreditCard, Receipt, Paperclip } from 'lucide-react';
import { BankAccountsManager } from '../components/finance/BankAccountsManager';
import { ReceivablesManager } from '../components/finance/ReceivablesManager';
import { PayablesManager } from '../components/finance/PayablesManager';
import { AgeingReport } from './reports/AgeingReport';
import { FileUpload } from '../components/FileUpload';

interface FinanceExpense {
  id: string;
  expense_category: 'duty' | 'freight' | 'warehouse_rent' | 'utilities' | 'salary' | 'other';
  amount: number;
  expense_date: string;
  description: string | null;
  batch_id: string | null;
  document_urls: string[] | null;
  created_at: string;
  batches?: {
    batch_number: string;
  } | null;
}

interface Batch {
  id: string;
  batch_number: string;
}

type FinanceTab = 'expenses' | 'banks' | 'receivables' | 'payables' | 'ageing';

export function Finance() {
  const { t } = useLanguage();
  const { profile } = useAuth();
  const [activeTab, setActiveTab] = useState<FinanceTab>('expenses');
  const [expenses, setExpenses] = useState<FinanceExpense[]>([]);
  const [batches, setBatches] = useState<Batch[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingExpense, setEditingExpense] = useState<FinanceExpense | null>(null);
  const [filterCategory, setFilterCategory] = useState<string>('all');
  const [dateRange, setDateRange] = useState({
    start: new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0],
  });
  const [formData, setFormData] = useState({
    expense_category: 'other' as FinanceExpense['expense_category'],
    amount: 0,
    expense_date: new Date().toISOString().split('T')[0],
    description: '',
    batch_id: '',
    document_urls: [] as string[],
  });

  useEffect(() => {
    loadExpenses();
    loadBatches();
  }, []);

  const loadExpenses = async () => {
    try {
      const { data, error } = await supabase
        .from('finance_expenses')
        .select('*, batches(batch_number)')
        .order('expense_date', { ascending: false })
        .order('created_at', { ascending: false });

      if (error) throw error;
      setExpenses(data || []);
    } catch (error) {
      console.error('Error loading expenses:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadBatches = async () => {
    try {
      const { data, error } = await supabase
        .from('batches')
        .select('id, batch_number')
        .eq('is_active', true)
        .order('import_date', { ascending: false });

      if (error) throw error;
      setBatches(data || []);
    } catch (error) {
      console.error('Error loading batches:', error);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('Not authenticated');

      if (editingExpense) {
        const { error } = await supabase
          .from('finance_expenses')
          .update({
            ...formData,
            batch_id: formData.batch_id || null,
            description: formData.description || null,
            document_urls: formData.document_urls.length > 0 ? formData.document_urls : null,
          })
          .eq('id', editingExpense.id);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('finance_expenses')
          .insert([{
            ...formData,
            batch_id: formData.batch_id || null,
            description: formData.description || null,
            document_urls: formData.document_urls.length > 0 ? formData.document_urls : null,
            created_by: user.id,
          }]);

        if (error) throw error;
      }

      setModalOpen(false);
      resetForm();
      loadExpenses();
    } catch (error) {
      console.error('Error saving expense:', error);
      alert('Failed to save expense. Please try again.');
    }
  };

  const handleEdit = (expense: FinanceExpense) => {
    setEditingExpense(expense);
    setFormData({
      expense_category: expense.expense_category,
      amount: expense.amount,
      expense_date: expense.expense_date,
      description: expense.description || '',
      batch_id: expense.batch_id || '',
      document_urls: expense.document_urls || [],
    });
    setModalOpen(true);
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this expense?')) return;

    try {
      const { error } = await supabase
        .from('finance_expenses')
        .delete()
        .eq('id', id);

      if (error) throw error;
      loadExpenses();
    } catch (error) {
      console.error('Error deleting expense:', error);
      alert('Failed to delete expense. Please try again.');
    }
  };

  const resetForm = () => {
    setEditingExpense(null);
    setFormData({
      expense_category: 'other',
      amount: 0,
      expense_date: new Date().toISOString().split('T')[0],
      description: '',
      batch_id: '',
      document_urls: [],
    });
  };

  const categoryConfig = {
    duty: { label: 'Duty', color: 'bg-red-100 text-red-800' },
    freight: { label: 'Freight', color: 'bg-blue-100 text-blue-800' },
    warehouse_rent: { label: 'Warehouse Rent', color: 'bg-yellow-100 text-yellow-800' },
    utilities: { label: 'Utilities', color: 'bg-green-100 text-green-800' },
    salary: { label: 'Salary', color: 'bg-purple-100 text-purple-800' },
    other: { label: 'Other', color: 'bg-gray-100 text-gray-800' },
  };

  const filteredExpenses = expenses.filter(expense => {
    const matchesCategory = filterCategory === 'all' || expense.expense_category === filterCategory;
    const expenseDate = new Date(expense.expense_date);
    const matchesDateRange = expenseDate >= new Date(dateRange.start) && expenseDate <= new Date(dateRange.end);
    return matchesCategory && matchesDateRange;
  });

  const stats = {
    totalExpenses: filteredExpenses.reduce((sum, exp) => sum + exp.amount, 0),
    duty: expenses.filter(e => e.expense_category === 'duty').reduce((sum, e) => sum + e.amount, 0),
    freight: expenses.filter(e => e.expense_category === 'freight').reduce((sum, e) => sum + e.amount, 0),
    operations: expenses.filter(e => ['warehouse_rent', 'utilities', 'salary'].includes(e.expense_category))
      .reduce((sum, e) => sum + e.amount, 0),
    other: expenses.filter(e => e.expense_category === 'other').reduce((sum, e) => sum + e.amount, 0),
  };

  const columns = [
    {
      key: 'expense_date',
      label: 'Date',
      render: (exp: FinanceExpense) => new Date(exp.expense_date).toLocaleDateString()
    },
    {
      key: 'expense_category',
      label: 'Category',
      render: (exp: FinanceExpense) => (
        <span className={`inline-block px-2 py-1 rounded-full text-xs font-medium ${categoryConfig[exp.expense_category].color}`}>
          {categoryConfig[exp.expense_category].label}
        </span>
      )
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (exp: FinanceExpense) => (
        <span className="font-semibold text-red-600">
          Rp {exp.amount.toLocaleString('id-ID')}
        </span>
      )
    },
    {
      key: 'batch',
      label: 'Batch',
      render: (exp: FinanceExpense) => exp.batches?.batch_number || 'N/A'
    },
    {
      key: 'description',
      label: 'Description',
      render: (exp: FinanceExpense) => (
        <span className="text-sm text-gray-600">{exp.description || '-'}</span>
      )
    },
  ];

  const canManage = profile?.role === 'admin' || profile?.role === 'accounts';

  const tabs: { id: FinanceTab; label: string; icon: any }[] = [
    { id: 'expenses', label: 'Expenses', icon: Receipt },
    { id: 'banks', label: 'Bank Accounts', icon: CreditCard },
    { id: 'receivables', label: 'Receivables', icon: TrendingUp },
    { id: 'payables', label: 'Payables', icon: TrendingDown },
    { id: 'ageing', label: 'Ageing Report', icon: DollarSign },
  ];

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Finance Management</h1>
            <p className="text-gray-600 mt-1">Comprehensive financial tracking and reporting</p>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow">
          <div className="border-b border-gray-200">
            <nav className="flex space-x-8 px-6" aria-label="Tabs">
              {tabs.map((tab) => {
                const Icon = tab.icon;
                const isActive = activeTab === tab.id;
                return (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={[
                      'flex items-center gap-2 py-4 px-1 border-b-2 font-medium text-sm',
                      isActive
                        ? 'border-blue-500 text-blue-600'
                        : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                    ].join(' ')}
                  >
                    <Icon className="w-5 h-5" />
                    {tab.label}
                  </button>
                );
              })}
            </nav>
          </div>

          <div className="p-6">
            {activeTab === 'expenses' && (
              <div className="space-y-6">
                <div className="flex items-center justify-between">
                  {canManage && (
                    <button
                      onClick={() => {
                        resetForm();
                        setModalOpen(true);
                      }}
                      className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition ml-auto"
                    >
                      <Plus className="w-5 h-5" />
                      Add Expense
                    </button>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
          <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg shadow p-6 text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-blue-100">Total Expenses</p>
                <p className="text-2xl font-bold mt-1">Rp {stats.totalExpenses.toLocaleString('id-ID')}</p>
              </div>
              <DollarSign className="w-8 h-8 text-blue-200" />
            </div>
          </div>

          <div className="bg-red-50 rounded-lg shadow p-6">
            <p className="text-sm text-red-600">Duty</p>
            <p className="text-2xl font-bold text-red-600 mt-1">Rp {stats.duty.toLocaleString('id-ID')}</p>
          </div>

          <div className="bg-blue-50 rounded-lg shadow p-6">
            <p className="text-sm text-blue-600">Freight</p>
            <p className="text-2xl font-bold text-blue-600 mt-1">Rp {stats.freight.toLocaleString('id-ID')}</p>
          </div>

          <div className="bg-yellow-50 rounded-lg shadow p-6">
            <p className="text-sm text-yellow-600">Operations</p>
            <p className="text-2xl font-bold text-yellow-600 mt-1">Rp {stats.operations.toLocaleString('id-ID')}</p>
          </div>

          <div className="bg-gray-50 rounded-lg shadow p-6">
            <p className="text-sm text-gray-600">Other</p>
            <p className="text-2xl font-bold text-gray-600 mt-1">Rp {stats.other.toLocaleString('id-ID')}</p>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-4">
          <div className="flex flex-wrap items-center gap-4">
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700">From:</label>
              <input
                type="date"
                value={dateRange.start}
                onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })}
                className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div className="flex items-center gap-2">
              <label className="text-sm font-medium text-gray-700">To:</label>
              <input
                type="date"
                value={dateRange.end}
                onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })}
                className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div className="flex-1" />
            <div className="flex gap-2">
              <button
                onClick={() => setFilterCategory('all')}
                className={`px-3 py-1.5 rounded-lg text-sm transition ${
                  filterCategory === 'all' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                All
              </button>
              {Object.entries(categoryConfig).map(([key, config]) => (
                <button
                  key={key}
                  onClick={() => setFilterCategory(key)}
                  className={`px-3 py-1.5 rounded-lg text-sm transition ${
                    filterCategory === key ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {config.label}
                </button>
              ))}
            </div>
          </div>
        </div>

        <DataTable
          columns={columns}
          data={filteredExpenses}
          loading={loading}
          actions={canManage ? (expense) => (
            <div className="flex items-center gap-2">
              <button
                onClick={() => handleEdit(expense)}
                className="p-1 text-blue-600 hover:bg-blue-50 rounded"
              >
                <Edit className="w-4 h-4" />
              </button>
              <button
                onClick={() => handleDelete(expense.id)}
                className="p-1 text-red-600 hover:bg-red-50 rounded"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ) : undefined}
        />

        <Modal
          isOpen={modalOpen}
          onClose={() => {
            setModalOpen(false);
            resetForm();
          }}
          title={editingExpense ? 'Edit Expense' : 'Add New Expense'}
        >
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Expense Category *
                </label>
                <select
                  value={formData.expense_category}
                  onChange={(e) => setFormData({ ...formData, expense_category: e.target.value as any })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  required
                >
                  {Object.entries(categoryConfig).map(([key, config]) => (
                    <option key={key} value={key}>{config.label}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Amount (Rp) *
                </label>
                <input
                  type="number"
                  value={formData.amount === 0 ? '' : formData.amount}
                  onChange={(e) => setFormData({ ...formData, amount: e.target.value === '' ? 0 : Number(e.target.value) })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  required
                  min="0"
                  step="0.01"
                  placeholder="0"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Expense Date *
                </label>
                <input
                  type="date"
                  value={formData.expense_date}
                  onChange={(e) => setFormData({ ...formData, expense_date: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Related Batch (Optional)
                </label>
                <select
                  value={formData.batch_id}
                  onChange={(e) => setFormData({ ...formData, batch_id: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">None</option>
                  {batches.map((batch) => (
                    <option key={batch.id} value={batch.id}>
                      {batch.batch_number}
                    </option>
                  ))}
                </select>
              </div>

              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
                  rows={3}
                  placeholder="Additional details about this expense"
                />
              </div>

              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  <Paperclip className="w-4 h-4 inline mr-1" />
                  Attach Documents (Receipts, Photos, etc.)
                </label>
                <FileUpload
                  currentUrls={formData.document_urls}
                  onUploadComplete={(urls) => setFormData({ ...formData, document_urls: urls })}
                  folder="expense-documents"
                />
              </div>
            </div>

            <div className="flex justify-end gap-3 pt-4">
              <button
                type="button"
                onClick={() => {
                  setModalOpen(false);
                  resetForm();
                }}
                className="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition"
              >
                Cancel
              </button>
              <button
                type="submit"
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition"
              >
                {editingExpense ? 'Update Expense' : 'Add Expense'}
              </button>
            </div>
          </form>
        </Modal>
              </div>
            )}

            {activeTab === 'banks' && (
              <BankAccountsManager canManage={canManage} />
            )}

            {activeTab === 'receivables' && (
              <ReceivablesManager canManage={canManage} />
            )}

            {activeTab === 'payables' && (
              <PayablesManager canManage={canManage} />
            )}

            {activeTab === 'ageing' && (
              <AgeingReport />
            )}
          </div>
        </div>
      </div>
    </Layout>
  );
}
