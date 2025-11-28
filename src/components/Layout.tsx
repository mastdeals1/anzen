import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useLanguage } from '../contexts/LanguageContext';
import { useNavigation } from '../contexts/NavigationContext';
import { NotificationDropdown } from './NotificationDropdown';
import {
  LayoutDashboard,
  Package,
  Boxes,
  Warehouse,
  Users,
  UserCircle,
  ShoppingCart,
  DollarSign,
  Settings,
  LogOut,
  Menu,
  X,
  Globe,
  Truck,
  Zap,
  CheckSquare,
  FileText,
  ClipboardCheck,
  TrendingUp,
} from 'lucide-react';
import logo from '../assets/Untitled-1.svg';

interface LayoutProps {
  children: React.ReactNode;
}

export function Layout({ children }: LayoutProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { profile, signOut } = useAuth();
  const { language, setLanguage, t } = useLanguage();
  const { currentPage, setCurrentPage, sidebarCollapsed, setSidebarCollapsed } = useNavigation();

  // Auto-collapse sidebar for specific pages
  const autoCollapsiblePages = ['crm', 'command-center'];
  const shouldAutoCollapse = autoCollapsiblePages.includes(currentPage);

  // Automatically collapse sidebar when entering CRM or Command Center
  useEffect(() => {
    if (shouldAutoCollapse && !sidebarCollapsed) {
      setSidebarCollapsed(true);
    }
  }, [currentPage, shouldAutoCollapse, sidebarCollapsed, setSidebarCollapsed]);

  const menuItems = [
    { id: 'dashboard', label: t('nav.dashboard'), icon: LayoutDashboard, roles: ['admin', 'accounts', 'sales', 'warehouse'] },
    { id: 'products', label: t('nav.products'), icon: Package, roles: ['admin', 'sales', 'warehouse'] },
    { id: 'batches', label: t('nav.batches'), icon: Boxes, roles: ['admin', 'warehouse', 'accounts'] },
    { id: 'stock', label: t('nav.stock'), icon: Warehouse, roles: ['admin', 'sales', 'warehouse', 'accounts'] },
    { id: 'customers', label: t('nav.customers'), icon: Users, roles: ['admin', 'accounts', 'sales'] },
    { id: 'sales-orders', label: 'Sales Orders', icon: FileText, roles: ['admin', 'accounts', 'sales'] },
    { id: 'delivery-challan', label: t('nav.deliveryChallan'), icon: Truck, roles: ['admin', 'accounts', 'sales', 'warehouse'] },
    { id: 'sales', label: t('nav.sales'), icon: ShoppingCart, roles: ['admin', 'accounts', 'sales'] },
    { id: 'import-requirements', label: 'Import Requirements', icon: TrendingUp, roles: ['admin', 'warehouse', 'sales'] },
    { id: 'finance', label: t('nav.finance'), icon: DollarSign, roles: ['admin', 'accounts'] },
    { id: 'crm', label: t('nav.crm'), icon: UserCircle, roles: ['admin', 'sales'] },
    { id: 'command-center', label: 'Command Center', icon: Zap, roles: ['admin', 'sales'] },
    { id: 'tasks', label: 'Tasks', icon: CheckSquare, roles: ['admin', 'accounts', 'sales', 'warehouse'] },
    { id: 'inventory', label: t('nav.inventory'), icon: Warehouse, roles: ['admin', 'warehouse'] },
    { id: 'settings', label: t('nav.settings'), icon: Settings, roles: ['admin'] },
  ];

  const visibleMenuItems = menuItems.filter(item =>
    profile && item.roles.includes(profile.role)
  );

  const toggleLanguage = () => {
    setLanguage(language === 'en' ? 'id' : 'en');
  };

  return (
    <div className="min-h-screen bg-gray-50">
      <div
        className={`fixed inset-0 bg-gray-900 bg-opacity-50 z-20 lg:hidden transition-opacity ${
          sidebarOpen ? 'opacity-100' : 'opacity-0 pointer-events-none'
        }`}
        onClick={() => setSidebarOpen(false)}
      />

      <aside
        className={`fixed top-0 left-0 z-30 h-full bg-white border-r border-gray-200 transform transition-all lg:translate-x-0 ${
          sidebarOpen ? 'translate-x-0' : '-translate-x-full'
        } ${sidebarCollapsed && shouldAutoCollapse ? 'w-16' : 'w-64'} flex flex-col`}
      >
        <div className="flex items-center justify-between p-3 border-b border-gray-200 flex-shrink-0">
          <div className="flex items-center gap-2">
            <img src={logo} alt="Logo" className="h-8 w-8 flex-shrink-0" />
            {!(sidebarCollapsed && shouldAutoCollapse) && (
              <div className="flex flex-col leading-tight">
                <span className="text-xs font-bold text-gray-900">PT. SHUBHAM ANZEN</span>
                <span className="text-xs font-bold text-gray-900">PHARMA JAYA</span>
              </div>
            )}
          </div>
          <button
            onClick={() => setSidebarOpen(false)}
            className="lg:hidden p-1 rounded hover:bg-gray-100"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {visibleMenuItems.map((item) => {
            const Icon = item.icon;
            const isActive = currentPage === item.id;
            return (
              <button
                key={item.id}
                onClick={() => {
                  setCurrentPage(item.id);
                  setSidebarOpen(false);
                }}
                className={`w-full flex items-center gap-2 px-3 py-2 rounded-lg transition ${
                  isActive
                    ? 'bg-blue-50 text-blue-600'
                    : 'text-gray-700 hover:bg-gray-50'
                } ${sidebarCollapsed && shouldAutoCollapse ? 'justify-center' : ''}`}
                title={sidebarCollapsed && shouldAutoCollapse ? item.label : undefined}
              >
                <Icon className="w-5 h-5 flex-shrink-0" />
                {!(sidebarCollapsed && shouldAutoCollapse) && (
                  <span className="font-medium text-sm">{item.label}</span>
                )}
              </button>
            );
          })}
        </nav>
      </aside>

      <div className={`transition-all ${sidebarCollapsed && shouldAutoCollapse ? 'lg:pl-16' : 'lg:pl-64'}`}>
        <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
          <div className="flex items-center justify-between px-4 py-3">
            <div className="flex items-center gap-2">
              <button
                onClick={() => setSidebarOpen(true)}
                className="lg:hidden p-2 rounded hover:bg-gray-100"
              >
                <Menu className="w-6 h-6" />
              </button>
              {shouldAutoCollapse && (
                <button
                  onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
                  className="hidden lg:block p-2 rounded hover:bg-gray-100"
                  title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
                >
                  <Menu className="w-6 h-6" />
                </button>
              )}
            </div>

            <div className="flex-1" />

            <div className="flex items-center gap-3">
              <NotificationDropdown />

              <button
                onClick={toggleLanguage}
                className="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100"
              >
                <Globe className="w-5 h-5 text-gray-600" />
                <span className="text-sm font-medium text-gray-700 uppercase">
                  {language}
                </span>
              </button>

              <button
                onClick={() => signOut()}
                className="flex items-center gap-2 px-3 py-2 rounded hover:bg-gray-100 text-gray-700"
              >
                <LogOut className="w-5 h-5" />
                <span className="text-sm font-medium">{t('auth.logout')}</span>
              </button>
            </div>
          </div>
        </header>

        <main className="p-4 lg:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
