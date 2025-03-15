import React, { useState } from 'react';
import { Lock, AlertTriangle, CheckCircle } from 'lucide-react';
import { validatePassword } from '../../lib/auth';

interface PasswordResetFormProps {
  onSubmit: (password: string) => Promise<void>;
  error: string | null;
  isLoading: boolean;
  success: boolean;
  successMessage?: string;
}

const PasswordResetForm: React.FC<PasswordResetFormProps> = ({
  onSubmit,
  error,
  isLoading,
  success,
  successMessage = 'Hasło zostało zmienione'
}) => {
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [validationError, setValidationError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setValidationError(null);

    // Walidacja haseł
    if (newPassword !== confirmPassword) {
      setValidationError('Hasła nie są identyczne');
      return;
    }

    const passwordErrors = validatePassword(newPassword);
    if (passwordErrors.length > 0) {
      setValidationError(passwordErrors.join('\n'));
      return;
    }

    await onSubmit(newPassword);
  };

  if (success) {
    return (
      <div className="rounded-md bg-green-50 p-6 text-center">
        <CheckCircle className="h-12 w-12 text-green-500 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-green-800 mb-2">
          {successMessage}
        </h3>
        <p className="text-green-700">
          Za chwilę zostaniesz przekierowany do strony logowania.
        </p>
      </div>
    );
  }

  return (
    <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
      <div className="rounded-md shadow-sm -space-y-px">
        <div className="relative">
          <label htmlFor="new-password" className="sr-only">
            Nowe hasło
          </label>
          <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            id="new-password"
            name="new-password"
            type="password"
            required
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            className="appearance-none rounded-none relative block w-full px-12 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange focus:z-10 sm:text-sm"
            placeholder="Nowe hasło"
          />
        </div>
        <div className="relative">
          <label htmlFor="confirm-password" className="sr-only">
            Potwierdź hasło
          </label>
          <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
          <input
            id="confirm-password"
            name="confirm-password"
            type="password"
            required
            value={confirmPassword}
            onChange={(e) => setConfirmPassword(e.target.value)}
            className="appearance-none rounded-none relative block w-full px-12 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange focus:z-10 sm:text-sm"
            placeholder="Potwierdź hasło"
          />
        </div>
      </div>

      {(error || validationError) && (
        <div className="rounded-md bg-red-50 p-4">
          <div className="flex">
            <div className="flex-shrink-0">
              <AlertTriangle className="h-5 w-5 text-red-400" />
            </div>
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">
                Błąd zmiany hasła
              </h3>
              <div className="mt-2 text-sm text-red-700">
                <p>{error || validationError}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      <div>
        <button
          type="submit"
          disabled={isLoading}
          className={`group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-md text-white ${
            isLoading ? 'bg-gray-400 cursor-not-allowed' : 'bg-solrent-orange hover:bg-orange-700'
          }`}
        >
          {isLoading ? 'Zapisywanie...' : 'Zmień hasło'}
        </button>
      </div>
      
      <div className="text-center mt-4">
        <a 
          href="/admin" 
          className="text-sm text-solrent-orange hover:text-orange-700"
        >
          Powrót do strony logowania
        </a>
      </div>
    </form>
  );
};

export default PasswordResetForm; 