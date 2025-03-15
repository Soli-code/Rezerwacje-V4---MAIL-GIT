import { supabase } from './supabase';

export const signIn = async (email: string, password: string) => {
  console.log('Próba logowania dla:', email);
  
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (error) {
    console.error('Błąd logowania:', error);
    console.error('Kod błędu:', error.code);
    console.error('Wiadomość błędu:', error.message);
    throw error;
  }
  
  console.log('Logowanie zakończone sukcesem');
  return data;
};

export const signOut = async () => {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
};

export const checkIsAdmin = async () => {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;

  const { data: profile } = await supabase
    .from('profiles')
    .select('is_admin')
    .eq('id', user.id)
    .single();

  return profile?.is_admin || false;
};

export const resetPassword = async (email: string) => {
  console.log('Wysyłanie żądania resetowania hasła dla:', email);
  
  try {
    // Dodatkowe logowanie dla specyficznych adresów email
    if (email === 'kubens11r@gmail.com' || email === 'biuro@solrent.pl' || email.includes('test') || email.includes('demo')) {
      console.log('Wykryto specjalny adres email. Dodatkowe logowanie dla celów diagnostycznych.');
    }
    
    // Sprawdź, czy używamy lokalnego środowiska czy produkcyjnego
    const isLocalhost = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    
    // Ustaw adres przekierowania na podstawie środowiska
    let redirectTo;
    if (isLocalhost) {
      redirectTo = 'http://localhost:5173/admin/reset-password';
    } else if (window.location.hostname === 'rezerwacje.solrent.pl') {
      redirectTo = 'https://rezerwacje.solrent.pl/admin/reset-password';
    } else {
      // Dla innych domen używamy dynamicznego origin
      redirectTo = `${window.location.origin}/admin/reset-password`;
    }
    
    console.log('Używany adres przekierowania:', redirectTo);
    
    // Próba resetowania hasła z jawnie określonym adresem przekierowania
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: redirectTo,
    });
    
    if (error) {
      console.error('Błąd resetowania hasła:', error);
      console.error('Kod błędu:', error.code);
      console.error('Wiadomość błędu:', error.message);
      console.error('Szczegóły błędu:', error.status);
      
      // Jeśli błąd dotyczy URL przekierowania, spróbuj bez niego
      if (error.message.includes('redirect') || error.message.includes('URL')) {
        console.log('Próba resetowania hasła bez określania adresu przekierowania...');
        const { error: fallbackError } = await supabase.auth.resetPasswordForEmail(email);
        
        if (fallbackError) {
          console.error('Błąd podczas próby alternatywnej:', fallbackError);
          throw fallbackError;
        } else {
          console.log('Alternatywna metoda resetowania hasła zakończona sukcesem');
          return;
        }
      }
      
      // Jeśli to specyficzny adres email, spróbuj jeszcze jedną metodę
      if (email === 'kubens11r@gmail.com' || email === 'biuro@solrent.pl') {
        console.log('Próba specjalnej metody resetowania hasła dla:', email);
        
        // Próba z pełnym URL jako redirectTo
        const fullRedirectUrl = isLocalhost 
          ? 'http://localhost:5173/admin/reset-password' 
          : 'https://rezerwacje.solrent.pl/admin/reset-password';
          
        const { error: specialError } = await supabase.auth.resetPasswordForEmail(email, {
          redirectTo: fullRedirectUrl,
        });
        
        if (specialError) {
          console.error('Błąd podczas specjalnej próby:', specialError);
        } else {
          console.log('Specjalna metoda resetowania hasła zakończona sukcesem');
          return;
        }
      }
      
      throw error;
    }
    
    console.log('Żądanie resetowania hasła wysłane pomyślnie');
  } catch (err) {
    console.error('Wyjątek podczas resetowania hasła:', err);
    // Dodatkowe logowanie dla wyjątku
    if (err instanceof Error) {
      console.error('Nazwa błędu:', err.name);
      console.error('Wiadomość błędu:', err.message);
      console.error('Stack trace:', err.stack);
    }
    throw err;
  }
};

export const updatePassword = async (newPassword: string) => {
  console.log('Próba aktualizacji hasła...');
  
  try {
    // Sprawdź, czy użytkownik jest zalogowany
    const { data: { session } } = await supabase.auth.getSession();
    
    if (!session) {
      console.error('Brak aktywnej sesji podczas próby aktualizacji hasła');
      throw new Error('Brak aktywnej sesji. Spróbuj ponownie zresetować hasło.');
    }
    
    console.log('Sesja użytkownika istnieje, aktualizacja hasła...');
    console.log('ID użytkownika:', session.user.id);
    console.log('Email użytkownika:', session.user.email);
    
    // Aktualizacja hasła
    const { error } = await supabase.auth.updateUser({
      password: newPassword
    });

    if (error) {
      console.error('Błąd podczas aktualizacji hasła:', error);
      console.error('Kod błędu:', error.code);
      console.error('Wiadomość błędu:', error.message);
      console.error('Status błędu:', error.status);
      throw error;
    }
    
    console.log('Hasło zostało pomyślnie zaktualizowane');
    
    // Opcjonalnie: wyloguj użytkownika po zmianie hasła, aby wymusić ponowne logowanie
    // await supabase.auth.signOut();
  } catch (err) {
    console.error('Wyjątek podczas aktualizacji hasła:', err);
    if (err instanceof Error) {
      console.error('Nazwa błędu:', err.name);
      console.error('Wiadomość błędu:', err.message);
      console.error('Stack trace:', err.stack);
    }
    throw err;
  }
};

export const validatePassword = (password: string): string[] => {
  const errors: string[] = [];
  
  if (password.length < 8) {
    errors.push('Hasło musi mieć co najmniej 8 znaków');
  }
  
  if (!/[A-Z]/.test(password)) {
    errors.push('Hasło musi zawierać co najmniej jedną wielką literę');
  }
  
  if (!/[0-9]/.test(password)) {
    errors.push('Hasło musi zawierać co najmniej jedną cyfrę');
  }

  return errors;
};

export const checkUserExists = async (email: string): Promise<boolean> => {
  try {
    console.log('Sprawdzanie, czy użytkownik istnieje:', email);
    
    // Używamy metody signInWithOtp bez hasła, aby sprawdzić, czy użytkownik istnieje
    // Jeśli użytkownik nie istnieje, Supabase zwróci błąd
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        shouldCreateUser: false
      }
    });
    
    if (error) {
      console.log('Błąd podczas sprawdzania użytkownika:', error.message);
      // Jeśli błąd to "User not found", to użytkownik nie istnieje
      if (error.message.includes('User not found') || error.message.includes('Invalid login credentials')) {
        return false;
      }
      // Dla innych błędów zakładamy, że użytkownik może istnieć
      return true;
    }
    
    // Jeśli nie ma błędu, użytkownik istnieje
    console.log('Użytkownik istnieje');
    return true;
  } catch (err) {
    console.error('Wyjątek podczas sprawdzania użytkownika:', err);
    // W przypadku wyjątku zakładamy, że użytkownik może istnieć
    return true;
  }
};

export const createTestUser = async (email: string, password: string = 'Test123456'): Promise<boolean> => {
  try {
    console.log('Tworzenie testowego użytkownika:', email);
    
    // Sprawdź, czy użytkownik już istnieje
    const userExists = await checkUserExists(email);
    if (userExists) {
      console.log('Użytkownik już istnieje, pomijam tworzenie');
      return true;
    }
    
    // Utwórz nowego użytkownika
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${window.location.origin}/admin/reset-password`
      }
    });
    
    if (error) {
      console.error('Błąd podczas tworzenia użytkownika:', error);
      return false;
    }
    
    console.log('Użytkownik testowy utworzony pomyślnie');
    
    // Dodaj uprawnienia administratora dla nowego użytkownika
    // Uwaga: To wymaga dodatkowej logiki po stronie serwera, aby działało poprawnie
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        await supabase
          .from('profiles')
          .upsert({ 
            id: user.id, 
            is_admin: true,
            updated_at: new Date().toISOString()
          });
      }
    } catch (profileError) {
      console.error('Błąd podczas ustawiania uprawnień administratora:', profileError);
      // Nie przerywamy procesu, jeśli nie udało się ustawić uprawnień
    }
    
    return true;
  } catch (err) {
    console.error('Wyjątek podczas tworzenia użytkownika:', err);
    return false;
  }
};