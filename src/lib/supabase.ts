import { createClient } from '@supabase/supabase-js';
import type { Database } from '../types/supabase';

const supabaseUrl = process.env.VITE_SUPABASE_URL || import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Brak wymaganych zmiennych środowiskowych Supabase. Upewnij się, że plik .env zawiera VITE_SUPABASE_URL i VITE_SUPABASE_ANON_KEY.');
}

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true
  },
  global: {
    headers: {
      'x-application-name': 'rezerwacje-v4'
    }
  }
});

export const checkIsAdmin = async () => {
  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError) throw userError;
    if (!user) return false;

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single();
    
    if (profileError) throw profileError;
    return profile?.is_admin || false;
  } catch (error) {
    console.error('Błąd podczas sprawdzania uprawnień administratora:', error);
    return false;
  }
};

// Helper do sprawdzania stanu połączenia
export const checkSupabaseConnection = async () => {
  try {
    const { data, error } = await supabase.from('profiles').select('id').limit(1);
    if (error) throw error;
    return true;
  } catch (error) {
    console.error('Błąd połączenia z Supabase:', error);
    return false;
  }
};