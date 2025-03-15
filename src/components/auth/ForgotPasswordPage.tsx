import React, { useState } from 'react';
import { resetPassword } from '../../lib/auth';
import ForgotPasswordForm from './ForgotPasswordForm';

const ForgotPasswordPage: React.FC = () => {
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (email: string) => {
    setError(null);
    setIsLoading(true);
    
    try {
      await resetPassword(email);
      setSuccess(true);
    } catch (err) {
      console.error('Błąd resetowania hasła:', err);
      if (err instanceof Error) {
        setError(`Nie udało się wysłać linku resetującego: ${err.message}`);
      } else {
        setError('Nie udało się wysłać linku resetującego. Spróbuj ponownie.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8 bg-white p-8 rounded-lg shadow-lg">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Resetowanie hasła
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Podaj swój adres email, aby otrzymać link do resetowania hasła
          </p>
        </div>

        <ForgotPasswordForm
          onSubmit={handleSubmit}
          error={error}
          isLoading={isLoading}
          success={success}
        />
      </div>
    </div>
  );
};

export default ForgotPasswordPage; 