import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Package, Users, Calendar, FileText, PenTool as Tool, AlertTriangle, DollarSign, Settings, UserPlus, Phone, Mail, FileCheck, ChevronLeft, BarChart2 } from 'lucide-react';
import AdminProducts from './AdminProducts';
import AdminCustomers from './AdminCustomers';
import AdminCalendar from './AdminCalendar';
import Pipeline from './Pipeline';
import BusinessDashboard from './BusinessDashboard';
import CRMDashboard from './CRMDashboard';
import RentalStatistics from './RentalStatistics';
import AdminAdvertisements from './AdminAdvertisements';

interface AdminPanelProps {
  onLogout: () => void;
}

const AdminPanel: React.FC<AdminPanelProps> = ({ onLogout }) => {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isMobile, setIsMobile] = useState(window.innerWidth < 768);

  useEffect(() => {
    const handleResize = () => setIsMobile(window.innerWidth < 768);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <BusinessDashboard />;
      case 'pipeline':
        return <Pipeline />;
      case 'crm':
        return <CRMDashboard />;
      case 'products':
        return <AdminProducts />;
      case 'advertisements':
        return <AdminAdvertisements />;
      case 'reservations':
        return <AdminCalendar />;
      case 'statistics':
        return <RentalStatistics />;
      default:
        return <div>Wybierz sekcję z menu</div>;
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Nagłówek */}
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex justify-between items-center">
            <h1 className="text-2xl font-bold text-gray-900">Panel Administracyjny</h1>
            <button
              onClick={onLogout}
              className="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
              Wyloguj
            </button>
          </div>
        </div>
      </header>

      <div className="flex h-[calc(100vh-73px)] pt-[73px]">
          {/* Menu boczne */}
          <nav className={`fixed left-0 top-0 h-full bg-white shadow-lg transition-all duration-300 ease-in-out ${isCollapsed ? 'w-16' : 'w-64'} z-40`}>
            <div className="h-[73px] flex items-center justify-center border-b">
              <img 
                src="/assets/solrent-logo.png"
                alt="SOLRENT Logo"
                className={`h-12 object-contain transition-all duration-300 ${isCollapsed ? 'scale-75' : ''}`}
              />
            </div>
            <button
              onClick={() => !isMobile && setIsCollapsed(!isCollapsed)}
              className="absolute -right-3 top-20 bg-white rounded-full p-1.5 shadow-lg border"
              aria-label={isCollapsed ? 'Rozwiń menu' : 'Zwiń menu'}
            >
              <ChevronLeft className={`w-4 h-4 text-gray-600 transition-transform duration-300 ${isCollapsed ? 'rotate-180' : ''}`} />
            </button>
            <div className="space-y-1 p-4">
              <MenuItem
                icon={Package}
                title="Dashboard"
                active={activeTab === 'dashboard'}
                onClick={() => setActiveTab('dashboard')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={Calendar}
                title="Pipeline"
                active={activeTab === 'pipeline'}
                onClick={() => setActiveTab('pipeline')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={UserPlus}
                title="CRM"
                active={activeTab === 'crm'}
                onClick={() => setActiveTab('crm')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={Package}
                title="Produkty"
                active={activeTab === 'products'}
                onClick={() => setActiveTab('products')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={Calendar}
                title="Rezerwacje"
                active={activeTab === 'reservations'}
                onClick={() => setActiveTab('reservations')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={BarChart2}
                title="Statystyki wypożyczeń"
                active={activeTab === 'statistics'}
                onClick={() => setActiveTab('statistics')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={Users}
                title="Klienci"
                active={activeTab === 'customers'}
                onClick={() => setActiveTab('customers')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={Tool}
                title="Konserwacja"
                active={activeTab === 'maintenance'}
                onClick={() => setActiveTab('maintenance')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={AlertTriangle}
                title="Raporty szkód"
                active={activeTab === 'damages'}
                onClick={() => setActiveTab('damages')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={FileText}
                title="Reklamy"
                active={activeTab === 'advertisements'}
                onClick={() => setActiveTab('advertisements')}
                collapsed={isCollapsed}
              />
              <MenuItem
                icon={Settings}
                title="Ustawienia"
                active={activeTab === 'settings'}
                onClick={() => setActiveTab('settings')}
                collapsed={isCollapsed}
              />
            </div>
          </nav>

          {/* Główna zawartość */}
          <main className={`flex-1 bg-white rounded-lg shadow p-6 ${isCollapsed ? 'ml-16' : 'ml-64'} transition-all duration-300 overflow-auto`}>
            {renderContent()}
          </main>
      </div>
    </div>
  );
};

interface MenuItemProps {
  icon: React.ElementType;
  title: string;
  active: boolean;
  onClick: () => void;
  collapsed?: boolean;
}

const MenuItem: React.FC<MenuItemProps> = ({ icon: Icon, title, active, onClick, collapsed = false }) => (
  <button
    onClick={onClick}
    className={`w-full flex items-center ${collapsed ? 'justify-center' : 'justify-start px-3'} py-2 rounded-lg transition-all duration-300 ${
      active 
        ? 'bg-solrent-orange text-white' 
        : 'text-gray-600 hover:bg-gray-100'
    }`}
    title={collapsed ? title : undefined}
  >
    <Icon className="w-5 h-5 flex-shrink-0" />
    <span className={`ml-3 whitespace-nowrap transition-opacity duration-300 ${collapsed ? 'opacity-0 w-0 hidden' : 'opacity-100'}`}>
      {title}
    </span>
  </button>
);

interface StatCardProps {
  icon: React.ElementType;
  title: string;
  value: string | number;
  description: string;
  color: string;
}

const StatCard: React.FC<StatCardProps> = ({ icon: Icon, title, value, description, color }) => (
  <div className="bg-white rounded-lg shadow p-6">
    <div className="flex items-center">
      <div className={`${color} p-3 rounded-lg`}>
        <Icon className="w-6 h-6 text-white" />
      </div>
      <div className="ml-4">
        <h3 className="text-lg font-medium text-gray-900">{title}</h3>
        <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
        <p className="text-sm text-gray-500">{description}</p>
      </div>
    </div>
  </div>
);

export default AdminPanel;