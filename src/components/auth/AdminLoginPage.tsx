import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import LoginForm from './LoginForm';

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minut

interface AdminLoginPageProps {
  onLogin: () => void;
}

const AdminLoginPage: React.FC<AdminLoginPageProps> = ({ onLogin }) => {
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [loginAttempts, setLoginAttempts] = useState(0);
  const [lockoutUntil, setLockoutUntil] = useState<number | null>(null);

  useEffect(() => {
    // Sprawdź czy użytkownik jest zablokowany
    const storedLockout = localStorage.getItem('adminLoginLockout');
    if (storedLockout) {
      const lockoutTime = parseInt(storedLockout);
      if (lockoutTime > Date.now()) {
        setLockoutUntil(lockoutTime);
      } else {
        localStorage.removeItem('adminLoginLockout');
        setLoginAttempts(0);
      }
    }
  }, []);

  const handleLoginFailure = () => {
    const newAttempts = loginAttempts + 1;
    setLoginAttempts(newAttempts);
    
    if (newAttempts >= MAX_LOGIN_ATTEMPTS) {
      const lockoutTime = Date.now() + LOCKOUT_DURATION;
      setLockoutUntil(lockoutTime);
      localStorage.setItem('adminLoginLockout', lockoutTime.toString());
    }
  };

  const handleSubmit = async (email: string, password: string) => {
    setError('');
    
    // Sprawdź czy użytkownik nie jest zablokowany
    if (lockoutUntil && lockoutUntil > Date.now()) {
      const minutesLeft = Math.ceil((lockoutUntil - Date.now()) / 60000);
      setError(`Zbyt wiele nieudanych prób. Spróbuj ponownie za ${minutesLeft} minut.`);
      return;
    }
    
    setIsLoading(true);
    
    try {
      const { data: { user }, error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password
      });

      if (signInError) throw signInError;
      if (!user) throw new Error('Nie znaleziono użytkownika');

      // Sprawdź czy użytkownik jest administratorem
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .single();

      if (profileError) throw profileError;

      if (!profile?.is_admin) {
        throw new Error('Brak uprawnień administratora');
      }

      // Jeśli logowanie udane, wyczyść licznik prób
      setLoginAttempts(0);
      localStorage.removeItem('adminLoginLockout');

      // Zapisz timestamp ostatniego udanego logowania
      await supabase
        .from('admin_actions')
        .insert({
          action_type: 'login',
          action_details: {
            email: email,
            timestamp: new Date().toISOString(),
            ip_address: await fetch('https://api.ipify.org?format=json').then(res => res.json()).then(data => data.ip)
          }
        });

      onLogin();
    } catch (error) {
      console.error('Login error:', error);
      if (error instanceof Error) {
        setError(
          error.message === 'Invalid login credentials' 
            ? 'Nieprawidłowe dane logowania'
            : error.message === 'Brak uprawnień administratora'
            ? 'Brak uprawnień administratora'
            : 'Wystąpił nieoczekiwany błąd'
        );
      } else {
        setError('Wystąpił nieoczekiwany błąd');
      }
      handleLoginFailure();
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8 bg-white p-8 rounded-lg shadow-lg">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Panel Administracyjny
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Zaloguj się aby zarządzać systemem
          </p>
        </div>

        <LoginForm 
          onSubmit={handleSubmit}
          error={error}
          isLoading={isLoading}
          isLocked={!!lockoutUntil && lockoutUntil > Date.now()}
        />
      </div>
    </div>
  );
};

export default AdminLoginPage; 