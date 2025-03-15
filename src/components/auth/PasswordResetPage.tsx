import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { updatePassword } from '../../lib/auth';
import { supabase } from '../../lib/supabase';
import PasswordResetForm from './PasswordResetForm';

const PasswordResetPage: React.FC = () => {
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [sessionChecked, setSessionChecked] = useState(false);
  const [debugInfo, setDebugInfo] = useState<string | null>(null);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    const checkSession = async () => {
      try {
        console.log('Rozpoczynam sprawdzanie sesji...');
        console.log('URL:', window.location.href);
        console.log('Hash:', location.hash);
        console.log('Search params:', location.search);
        
        // Sprawdź, czy mamy parametry w URL (access_token, refresh_token)
        const hash = location.hash;
        const searchParams = new URLSearchParams(location.search);
        
        // Sprawdź parametry w hash
        if (hash) {
          console.log('Znaleziono hash w URL');
          const params = new URLSearchParams(hash.substring(1));
          const accessToken = params.get('access_token');
          const refreshToken = params.get('refresh_token');
          const type = params.get('type');
          
          console.log('Parametry z hash:', { 
            accessToken: accessToken ? 'istnieje' : 'brak', 
            refreshToken: refreshToken ? 'istnieje' : 'brak', 
            type 
          });
          
          if (accessToken && refreshToken && type === 'recovery') {
            console.log('Ustawianie sesji na podstawie tokenów z hash...');
            try {
              const { error } = await supabase.auth.setSession({
                access_token: accessToken,
                refresh_token: refreshToken
              });
              
              if (error) {
                console.error('Błąd podczas ustawiania sesji z hash:', error);
                setDebugInfo(`Błąd sesji (hash): ${error.message}`);
              } else {
                console.log('Sesja ustawiona pomyślnie z hash');
              }
            } catch (err) {
              console.error('Wyjątek podczas ustawiania sesji z hash:', err);
              setDebugInfo(`Wyjątek sesji (hash): ${err instanceof Error ? err.message : String(err)}`);
            }
          }
        }
        
        // Sprawdź parametry w query string
        const queryToken = searchParams.get('token');
        const queryType = searchParams.get('type');
        
        if (queryToken) {
          console.log('Znaleziono token w query string:', queryType);
          
          try {
            // Próba ustawienia sesji na podstawie tokena z URL
            const { error } = await supabase.auth.verifyOtp({
              token_hash: queryToken,
              type: (queryType as any) || 'recovery',
            });
            
            if (error) {
              console.error('Błąd podczas weryfikacji tokena z URL:', error);
              setDebugInfo(`Błąd weryfikacji tokena: ${error.message}`);
            } else {
              console.log('Token z URL zweryfikowany pomyślnie');
            }
          } catch (err) {
            console.error('Wyjątek podczas weryfikacji tokena z URL:', err);
            setDebugInfo(`Wyjątek weryfikacji tokena: ${err instanceof Error ? err.message : String(err)}`);
          }
        }
        
        // Sprawdź, czy użytkownik jest zalogowany
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError) {
          console.error('Błąd podczas pobierania sesji:', sessionError);
          setDebugInfo(`Błąd pobierania sesji: ${sessionError.message}`);
        }
        
        console.log('Sesja użytkownika:', session ? 'Istnieje' : 'Brak');
        if (session) {
          console.log('ID użytkownika:', session.user.id);
          console.log('Email użytkownika:', session.user.email);
        }
        
        if (!session) {
          setError('Brak aktywnej sesji. Link do resetowania hasła mógł wygasnąć. Spróbuj ponownie zresetować hasło.');
        }
        
        setSessionChecked(true);
      } catch (err) {
        console.error('Błąd podczas sprawdzania sesji:', err);
        setError('Wystąpił błąd podczas weryfikacji sesji. Spróbuj ponownie zresetować hasło.');
        setDebugInfo(`Wyjątek główny: ${err instanceof Error ? err.message : String(err)}`);
        setSessionChecked(true);
      }
    };
    
    checkSession();
  }, [location]);

  const handleSubmit = async (newPassword: string) => {
    setIsLoading(true);
    try {
      console.log('Rozpoczynam aktualizację hasła...');
      await updatePassword(newPassword);
      console.log('Hasło zaktualizowane pomyślnie');
      setSuccess(true);
      setTimeout(() => {
        navigate('/admin');
      }, 3000);
    } catch (err) {
      console.error('Błąd podczas zmiany hasła:', err);
      if (err instanceof Error) {
        setError(`Nie udało się zmienić hasła: ${err.message}`);
      } else {
        setError('Nie udało się zmienić hasła. Spróbuj ponownie.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  if (!sessionChecked) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-md w-full space-y-8 bg-white p-8 rounded-lg shadow-lg">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-solrent-orange mx-auto"></div>
            <p className="mt-4 text-gray-600">Weryfikacja sesji...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8 bg-white p-8 rounded-lg shadow-lg">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Zmiana hasła
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Wprowadź nowe hasło
          </p>
        </div>

        <PasswordResetForm
          onSubmit={handleSubmit}
          error={error}
          isLoading={isLoading}
          success={success}
        />

        {debugInfo && (
          <div className="rounded-md bg-blue-50 p-4 text-xs">
            <p className="text-blue-800">Informacje diagnostyczne:</p>
            <p className="text-blue-700 break-all">{debugInfo}</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default PasswordResetPage; 