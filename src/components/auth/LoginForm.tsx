import React, { useState } from 'react';
import { Lock, Mail, AlertTriangle, Loader2 } from 'lucide-react';
import { Link } from 'react-router-dom';

interface LoginFormProps {
  onSubmit: (email: string, password: string) => Promise<void>;
  error: string;
  isLoading: boolean;
  isLocked: boolean;
}

const LoginForm: React.FC<LoginFormProps> = ({ 
  onSubmit, 
  error, 
  isLoading, 
  isLocked 
}) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await onSubmit(email, password);
  };

  return (
    <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
      <div className="rounded-md shadow-sm -space-y-px">
        <div className="relative">
          <label htmlFor="email" className="sr-only">
            Email
          </label>
          <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            id="email"
            name="email"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="appearance-none rounded-none relative block w-full px-12 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange focus:z-10 sm:text-sm"
            placeholder="Adres email"
            disabled={isLoading || isLocked}
          />
        </div>
        <div className="relative">
          <label htmlFor="password" className="sr-only">
            Hasło
          </label>
          <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            id="password"
            name="password"
            type="password"
            autoComplete="current-password" 
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="appearance-none rounded-none relative block w-full px-12 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange focus:z-10 sm:text-sm"
            placeholder="Hasło"
            disabled={isLoading || isLocked}
          />
        </div>
      </div>

      {error && (
        <div className="rounded-md bg-red-50 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <AlertTriangle className="h-5 w-5 text-red-400" aria-hidden="true" />
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">
                Błąd logowania
              </h3>
              <div className="mt-2 text-sm text-red-700">
                <p>{error}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      <div>
        <button
          type="submit"
          disabled={isLoading || isLocked}
          className={`group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-md text-white ${
            isLoading || isLocked
              ? 'bg-gray-400 cursor-not-allowed' 
              : 'bg-solrent-orange hover:bg-orange-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-solrent-orange'
          }`}
        >
          {isLoading ? (
            <span className="flex items-center">
              <Loader2 className="w-5 h-5 mr-2 animate-spin" />
              Logowanie...
            </span>
          ) : isLocked ? (
            'Konto tymczasowo zablokowane'
          ) : (
            'Zaloguj się'
          )}
        </button>
      </div>

      <div className="flex items-center justify-center">
        <div className="text-sm">
          <Link to="/admin/forgot-password" className="font-medium text-solrent-orange hover:text-orange-700">
            Zapomniałeś hasła?
          </Link>
        </div>
      </div>
    </form>
  );
};

export default LoginForm; 