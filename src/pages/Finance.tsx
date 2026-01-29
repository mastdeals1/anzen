import { useEffect, useState, useMemo } from 'react';
import { Layout } from '../components/Layout';
import { useAuth } from '../contexts/AuthContext';
import { useLanguage } from '../contexts/LanguageContext';
import { FinanceProvider, useFinance } from '../contexts/FinanceContext';
import { Calendar, ChevronDown, ChevronRight, Menu, X } from 'lucide-react';

// Import all finance components
import { PurchaseInvoiceManager } from '../components/finance/PurchaseInvoiceManager';
import { ReceiptVoucherManager } from '../components/finance/ReceiptVoucherManager';
import { PaymentVoucherManager } from '../components/finance/PaymentVoucherManager';
import { ExpenseManager } from '../components/finance/ExpenseManager';
import { PettyCashManager } from '../components/finance/PettyCashManager';
import { FundTransferManager } from '../components/finance/FundTransferManager';
import { JournalEntryViewerEnhanced as JournalEntryViewer } from '../components/finance/JournalEntryViewerEnhanced';
import { AccountLedger } from '../components/finance/AccountLedger';
import PartyLedger from '../components/finance/PartyLedger';
import BankLedger from '../components/finance/BankLedger';
import { FinancialReports } from '../components/finance/FinancialReports';
import { ReceivablesManager } from '../components/finance/ReceivablesManager';
import { PayablesManager } from '../components/finance/PayablesManager';
import OutstandingSummary from '../components/finance/OutstandingSummary';
import { AgeingReport } from './reports/AgeingReport';
import { BankReconciliationEnhanced as BankReconciliation } from '../components/finance/BankReconciliationEnhanced';
import { ChartOfAccountsManager } from '../components/finance/ChartOfAccountsManager';
import { SuppliersManager } from '../components/finance/SuppliersManager';
import { BankAccountsManager } from '../components/finance/BankAccountsManager';
import { TaxReports } from '../components/finance/TaxReports';
import { CAReports } from '../components/finance/CAReports';

type FinanceTab =
  | 'purchase' | 'receipt' | 'payment' | 'journal' | 'contra' | 'expenses' | 'petty_cash'
  | 'ledger' | 'journal_register' | 'bank_ledger' | 'party_ledger' | 'bank_recon'
  | 'trial_balance' | 'pnl' | 'balance_sheet' | 'receivables' | 'payables' | 'ageing' | 'tax' | 'ca_reports'
  | 'coa' | 'customers' | 'suppliers' | 'products' | 'banks';

interface MenuItem {
  id: FinanceTab;
  label: string;
  shortcut?: string;
}

interface MenuGroup {
  label: string;
  items: MenuItem[];
  collapsible?: boolean;
}

const getFinanceMenu = (t: any): MenuGroup[] => [
  {
    label: t.finance.vouchers,
    items: [
      { id: 'purchase', label: t.finance.purchase, shortcut: 'F9' },
      { id: 'receipt', label: t.finance.receipt, shortcut: 'F6' },
      { id: 'payment', label: t.finance.payment, shortcut: 'F5' },
      { id: 'journal', label: t.finance.journal, shortcut: 'F7' },
      { id: 'contra', label: t.finance.contra, shortcut: 'F4' },
      { id: 'expenses', label: t.finance.expenses, shortcut: 'F8' },
      { id: 'petty_cash', label: t.finance.pettyCash },
    ]
  },
  {
    label: t.finance.books,
    items: [
      { id: 'ledger', label: t.finance.ledger, shortcut: 'Ctrl+L' },
      { id: 'journal_register', label: t.finance.journalRegister, shortcut: 'Ctrl+J' },
      { id: 'bank_ledger', label: t.finance.bankLedger },
      { id: 'party_ledger', label: t.finance.partyLedger },
      { id: 'bank_recon', label: t.finance.bankReconciliation },
    ]
  },
  {
    label: t.finance.reports,
    collapsible: true,
    items: [
      { id: 'ca_reports', label: '📊 ' + t.finance.caReports, shortcut: 'Ctrl+R' },
      { id: 'trial_balance', label: t.finance.trialBalance },
      { id: 'pnl', label: t.finance.profitLoss },
      { id: 'balance_sheet', label: t.finance.balanceSheet },
      { id: 'receivables', label: t.finance.receivables },
      { id: 'payables', label: t.finance.payables },
      { id: 'ageing', label: t.finance.ageing },
      { id: 'tax', label: t.finance.taxReports },
    ]
  },
  {
    label: t.finance.masters,
    collapsible: true,
    items: [
      { id: 'coa', label: t.finance.chartOfAccounts },
      { id: 'suppliers', label: t.finance.suppliers },
      { id: 'banks', label: t.finance.banks },
    ]
  }
];

function FinanceContent() {
  const { profile } = useAuth();
  const { t } = useLanguage();
  const { dateRange, setDateRange } = useFinance();
  const [activeTab, setActiveTab] = useState<FinanceTab>('purchase');
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(new Set());
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const canManage = profile?.role === 'admin' || profile?.role === 'accounts';

  const financeMenu = useMemo(() => {
    if (!t || !t.finance) return [];
    return getFinanceMenu(t);
  }, [t]);

  const toggleGroup = (groupLabel: string) => {
    setCollapsedGroups(prev => {
      const newSet = new Set(prev);
      if (newSet.has(groupLabel)) {
        newSet.delete(groupLabel);
      } else {
        newSet.add(groupLabel);
      }
      return newSet;
    });
  };

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (['INPUT', 'TEXTAREA', 'SELECT'].includes((e.target as HTMLElement).tagName)) {
        return;
      }

      if (e.key === 'F2') {
        e.preventDefault();
        const input = document.querySelector('input[type="date"]') as HTMLInputElement;
        if (input) input.focus();
      } else if (e.key === 'F4') {
        e.preventDefault();
        setActiveTab('contra');
      } else if (e.key === 'F5') {
        e.preventDefault();
        setActiveTab('payment');
      } else if (e.key === 'F6') {
        e.preventDefault();
        setActiveTab('receipt');
      } else if (e.key === 'F7') {
        e.preventDefault();
        setActiveTab('journal');
      } else if (e.key === 'F8') {
        e.preventDefault();
        setActiveTab('expenses');
      } else if (e.key === 'F9') {
        e.preventDefault();
        setActiveTab('purchase');
      } else if (e.key === 'F10') {
        e.preventDefault();
        // Navigate to Sales page instead
        window.location.hash = 'sales';
      } else if (e.ctrlKey && e.key === 'l') {
        e.preventDefault();
        setActiveTab('ledger');
      } else if (e.ctrlKey && e.key === 'j') {
        e.preventDefault();
        setActiveTab('journal_register');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const renderContent = () => {
    switch (activeTab) {
      case 'purchase':
        return <PurchaseInvoiceManager canManage={canManage} />;
      case 'receipt':
        return <ReceiptVoucherManager canManage={canManage} />;
      case 'payment':
        return <PaymentVoucherManager canManage={canManage} />;
      case 'journal':
        return <div className="text-center p-8 text-gray-500">{t?.finance?.journal || 'Journal'} - {t?.common?.loading || 'Loading...'}</div>;
      case 'contra':
        return <FundTransferManager canManage={canManage} />;
      case 'expenses':
        return <ExpenseManager canManage={canManage} />;
      case 'petty_cash':
        return <PettyCashManager canManage={canManage} onNavigateToFundTransfer={() => setActiveTab('contra')} />;
      case 'ledger':
        return <AccountLedger />;
      case 'journal_register':
        return <JournalEntryViewer canManage={canManage} />;
      case 'bank_ledger':
        return <BankLedger />;
      case 'party_ledger':
        return <PartyLedger />;
      case 'bank_recon':
        return <BankReconciliation canManage={canManage} />;
      case 'trial_balance':
        return <FinancialReports initialReport="trial_balance" />;
      case 'pnl':
        return <FinancialReports initialReport="pnl" />;
      case 'balance_sheet':
        return <FinancialReports initialReport="balance_sheet" />;
      case 'receivables':
        return <ReceivablesManager canManage={canManage} />;
      case 'payables':
        return <PayablesManager canManage={canManage} />;
      case 'ageing':
        return <AgeingReport />;
      case 'tax':
        return <TaxReports />;
      case 'ca_reports':
        return <CAReports />;
      case 'coa':
        return <ChartOfAccountsManager canManage={canManage} />;
      case 'suppliers':
        return <SuppliersManager canManage={canManage} />;
      case 'banks':
        return <BankAccountsManager canManage={canManage} />;
      default:
        return <div className="text-center p-8 text-gray-500">{t?.common?.noData || 'No data available'}</div>;
    }
  };

  if (!t || !t.finance) {
    return (
      <Layout>
        <div className="flex items-center justify-center h-screen">
          <div className="text-gray-500">Loading...</div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div className="flex h-screen bg-gray-50">
        {/* Left Sidebar - Compact Menu */}
        {!sidebarCollapsed && (
          <div className="w-48 bg-white border-r border-gray-200 flex flex-col">
            {/* Menu Groups */}
            <div className="flex-1 overflow-y-auto">
              {financeMenu.map((group, groupIdx) => {
                const isCollapsed = collapsedGroups.has(group.label);
                const isCollapsible = group.collapsible;

                return (
                  <div key={group.label} className={groupIdx > 0 ? 'border-t border-gray-200' : ''}>
                    {isCollapsible ? (
                      <button
                        onClick={() => toggleGroup(group.label)}
                        className="w-full px-2 py-1.5 text-[10px] font-semibold text-gray-500 uppercase tracking-wider flex items-center justify-between hover:bg-gray-50"
                      >
                        <span>{group.label}</span>
                        {isCollapsed ? (
                          <ChevronRight className="w-3 h-3" />
                        ) : (
                          <ChevronDown className="w-3 h-3" />
                        )}
                      </button>
                    ) : (
                      <div className="px-2 py-1.5 text-[10px] font-semibold text-gray-500 uppercase tracking-wider">
                        {group.label}
                      </div>
                    )}

                    {!isCollapsed && (
                      <div>
                        {group.items.map((item) => (
                          <button
                            key={item.id}
                            onClick={() => setActiveTab(item.id)}
                            className={`w-full text-left px-3 py-1.5 text-xs transition-colors ${
                              activeTab === item.id
                                ? 'bg-blue-50 text-blue-700 font-medium border-l-2 border-blue-600'
                                : 'text-gray-700 hover:bg-gray-50 border-l-2 border-transparent'
                            }`}
                          >
                            <div className="flex items-center justify-between">
                              <span>{item.label}</span>
                              {item.shortcut && (
                                <span className="text-[10px] text-gray-400">{item.shortcut}</span>
                              )}
                            </div>
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Main Content Area */}
        <div className="flex-1 flex flex-col overflow-hidden">
          {/* Top Bar - Global Date Range ONLY */}
          <div className="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <button
                onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
                className="p-1.5 hover:bg-gray-100 rounded transition-colors"
                title={sidebarCollapsed ? 'Show Menu' : 'Hide Menu'}
              >
                {sidebarCollapsed ? <Menu className="w-5 h-5 text-gray-600" /> : <X className="w-5 h-5 text-gray-600" />}
              </button>
              <h1 className="text-lg font-semibold text-gray-900">{t.finance.title}</h1>
            </div>

            {/* SINGLE GLOBAL DATE RANGE */}
            <div className="flex items-center gap-3 bg-gray-50 px-4 py-2 rounded border border-gray-300">
              <Calendar className="w-4 h-4 text-gray-500" />
              <div className="flex items-center gap-2">
                <span className="text-xs text-gray-600">{t.finance.dateRange}:</span>
                <input
                  type="date"
                  value={dateRange.startDate}
                  onChange={(e) => setDateRange({ ...dateRange, startDate: e.target.value })}
                  className="px-2 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                <span className="text-gray-500">{t.finance.to}</span>
                <input
                  type="date"
                  value={dateRange.endDate}
                  onChange={(e) => setDateRange({ ...dateRange, endDate: e.target.value })}
                  className="px-2 py-1 text-sm border border-gray-300 rounded focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
            </div>
          </div>

          {/* Content Area - Pure White Background */}
          <div className="flex-1 overflow-auto bg-white">
            <div className="p-6">
              {renderContent()}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}

export function Finance() {
  return (
    <FinanceProvider>
      <FinanceContent />
    </FinanceProvider>
  );
}
