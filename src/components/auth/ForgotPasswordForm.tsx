import React, { useState } from 'react';
import { Mail, AlertTriangle, CheckCircle } from 'lucide-react';
import { Link } from 'react-router-dom';

interface ForgotPasswordFormProps {
  onSubmit: (email: string) => Promise<void>;
  error: string | null;
  isLoading: boolean;
  success: boolean;
}

const ForgotPasswordForm: React.FC<ForgotPasswordFormProps> = ({
  onSubmit,
  error,
  isLoading,
  success
}) => {
  const [email, setEmail] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await onSubmit(email);
  };

  if (success) {
    return (
      <div className="rounded-md bg-green-50 p-6 text-center">
        <CheckCircle className="h-12 w-12 text-green-500 mx-auto mb-4" />
        <h3 className="text-lg font-medium text-green-800 mb-2">
          Link do resetowania hasła został wysłany
        </h3>
        <p className="text-green-700">
          Sprawdź swoją skrzynkę email i postępuj zgodnie z instrukcjami, aby zresetować hasło.
        </p>
      </div>
    );
  }

  return (
    <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
      <div className="rounded-md shadow-sm">
        <div className="relative">
          <label htmlFor="email" className="sr-only">
            Adres email
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
            className="appearance-none relative block w-full px-12 py-3 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-md focus:outline-none focus:ring-solrent-orange focus:border-solrent-orange focus:z-10 sm:text-sm"
            placeholder="Adres email"
            disabled={isLoading}
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
                Błąd resetowania hasła
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
          disabled={isLoading}
          className={`group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-medium rounded-md text-white ${
            isLoading ? 'bg-gray-400 cursor-not-allowed' : 'bg-solrent-orange hover:bg-orange-700'
          }`}
        >
          {isLoading ? 'Wysyłanie...' : 'Wyślij link resetujący'}
        </button>
      </div>

      <div className="text-center mt-4">
        <Link 
          to="/admin" 
          className="text-sm text-solrent-orange hover:text-orange-700"
        >
          Powrót do strony logowania
        </Link>
      </div>
    </form>
  );
};

export default ForgotPasswordForm; 