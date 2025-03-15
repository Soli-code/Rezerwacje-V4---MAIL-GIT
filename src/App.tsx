import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import ReservationWidget from './components/reservation/ReservationWidget';
import ContactButton from './components/ui/ContactButton';
import AdminLoginPage from './components/auth/AdminLoginPage';
import ForgotPasswordPage from './components/auth/ForgotPasswordPage';
import PasswordResetPage from './components/auth/PasswordResetPage';
import AdminLayout from './components/admin/AdminLayout';
import BusinessDashboard from './components/admin/BusinessDashboard';
import Pipeline from './components/admin/Pipeline';
import AdminCustomers from './components/admin/AdminCustomers';
import CRMDashboard from './components/admin/CRMDashboard';
import AdminProducts from './components/admin/AdminProducts';
import AdminAdvertisements from './components/admin/AdminAdvertisements';
import ReservationCalendar from './components/admin/ReservationCalendar';
import RentalStatistics from './components/admin/RentalStatistics';
import CustomerDetailsView from './components/customer/CustomerDetailsView';
import CustomerProfile from './components/customer/CustomerProfile';
import { useEffect, useState } from 'react';
import { checkSupabaseConnection } from './lib/supabase';

// Komponent do obsługi przekierowań
const RedirectToHome = () => {
  useEffect(() => {
    window.location.href = '/';
  }, []);
  return null;
};

function App() {
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  useEffect(() => {
    const checkConnection = async () => {
      try {
        setIsLoading(true);
        const connected = await checkSupabaseConnection();
        setIsConnected(connected);
      } catch (error) {
        console.error('Błąd podczas sprawdzania połączenia:', error);
        setIsConnected(false);
      } finally {
        setIsLoading(false);
      }
    };

    checkConnection();
  }, []);

  return (
    <Router>
      <div className="relative min-h-screen">
        <Routes>
          <Route path="/admin" element={<AdminLoginPage onLogin={() => window.location.href = '/admin/panel'} />} />
          <Route path="/admin/forgot-password" element={<ForgotPasswordPage />} />
          <Route path="/admin/reset-password" element={<PasswordResetPage />} />
          <Route path="/admin/panel" element={<AdminLayout onLogout={() => window.location.href = '/admin'} />}>
            <Route index element={<Navigate to="/admin/panel/dashboard" replace />} />
            <Route path="dashboard" element={<BusinessDashboard />} />
            <Route path="reservations" element={<Pipeline />} />
            <Route path="reservations/:id" element={<CustomerDetailsView />} />
            <Route path="crm" element={<CRMDashboard />} />
            <Route path="equipment" element={<AdminProducts />} />
            <Route path="advertisements" element={<AdminAdvertisements />} />
            <Route path="calendar" element={<ReservationCalendar />} />
            <Route path="customers" element={<AdminCustomers />} />
            <Route path="customers/:id" element={<CustomerProfile />} />
            <Route path="statistics" element={<RentalStatistics />} />
          </Route>
          <Route path="/admin/*" element={<RedirectToHome />} />
          <Route path="/" element={
            <div className="min-h-screen bg-solrent-light relative">
              <div className="container mx-auto px-4 sm:px-6 lg:px-8 relative pt-28">
                <img 
                  src="/assets/solrent-logo.png"
                  alt="SOLRENT Logo"
                  className="absolute top-4 left-4 md:left-8 h-20 object-contain"
                />
                <h1 className="text-3xl md:text-4xl lg:text-5xl font-bold text-center mb-8 md:mb-12 text-solrent-dark max-w-4xl mx-auto">
                  Rezerwacja sprzętu budowlanego i ogrodniczego
                </h1>
                <div className="max-w-6xl mx-auto">
                  <ReservationWidget />
                </div>
              </div>
              <ContactButton />
            </div>
          } />
        </Routes>
        <div className="fixed bottom-4 right-4 bg-white p-3 rounded-lg shadow-lg border border-gray-200">
          {isLoading ? (
            <p className="text-gray-600">
              <span className="inline-block animate-spin mr-2">⭮</span>
              Sprawdzanie połączenia z bazą danych...
            </p>
          ) : (
            <p className="flex items-center gap-2">
              Status połączenia z bazą: {' '}
              <span className={`px-2 py-1 rounded ${isConnected ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                {isConnected ? '✓ Połączono' : '✕ Brak połączenia'}
              </span>
            </p>
          )}
        </div>
      </div>
    </Router>
  );
}

export default App;