import { useEffect } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { LanguageProvider } from './contexts/LanguageContext';
import { NavigationProvider, useNavigation } from './contexts/NavigationContext';
import { Login } from './components/Login';
import { Dashboard } from './pages/Dashboard';
import { Products } from './pages/Products';
import { Customers } from './pages/Customers';
import { Stock } from './pages/Stock';
import { Batches } from './pages/Batches';
import { Inventory } from './pages/Inventory';
import { CRM } from './pages/CRM';
import { CRMCommandCenter } from './pages/CRMCommandCenter';
import { Tasks } from './pages/Tasks';
import { DeliveryChallan } from './pages/DeliveryChallan';
import { Sales } from './pages/Sales';
import { Finance } from './pages/Finance';
import { Settings } from './pages/Settings';
import { Setup } from './pages/Setup';
import { GmailCallback } from './pages/GmailCallback';
import SalesOrders from './pages/SalesOrders';
import ImportRequirements from './pages/ImportRequirements';
import { ApprovalNotifications } from './components/ApprovalNotifications';
import { initializeNotificationChecks } from './utils/notifications';

function AppContent() {
  const { user, profile, loading } = useAuth();
  const { currentPage } = useNavigation();

  useEffect(() => {
    if (user && profile) {
      initializeNotificationChecks();
    }
  }, [user, profile]);

  if (window.location.pathname === '/setup') {
    return <Setup />;
  }

  if (window.location.pathname === '/auth/gmail/callback') {
    return <GmailCallback />;
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-blue-600 mx-auto" />
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user || !profile) {
    return <Login />;
  }

  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard />;
      case 'products':
        return <Products />;
      case 'stock':
        return <Stock />;
      case 'batches':
        return <Batches />;
      case 'inventory':
        return <Inventory />;
      case 'customers':
        return <Customers />;
      case 'sales-orders':
        return <SalesOrders />;
      case 'import-requirements':
        return <ImportRequirements />;
      case 'crm':
        return <CRM />;
      case 'command-center':
        return <CRMCommandCenter />;
      case 'tasks':
        return <Tasks />;
      case 'delivery-challan':
        return <DeliveryChallan />;
      case 'sales':
        return <Sales />;
      case 'finance':
        return <Finance />;
      case 'settings':
        return <Settings />;
      default:
        return <Dashboard />;
    }
  };

  return (
    <>
      {renderPage()}
      <ApprovalNotifications />
    </>
  );
}

function App() {
  return (
    <AuthProvider>
      <LanguageProvider>
        <NavigationProvider>
          <AppContent />
        </NavigationProvider>
      </LanguageProvider>
    </AuthProvider>
  );
}

export default App;
