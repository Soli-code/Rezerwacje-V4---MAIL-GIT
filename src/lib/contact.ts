import { supabase } from './supabase';

export interface ContactInfo {
  id: string;
  phone_number: string;
  email: string;
  updated_at: string;
}

export const getContactInfo = async (): Promise<ContactInfo> => {
  // Get the most recently updated contact info
  const { data, error } = await supabase
    .from('contact_info')
    .select('*')
    .order('updated_at', { ascending: false })
    .limit(1)
    .single();

  if (error) {
    console.error('Error fetching contact info:', error);
    // Return default contact info if fetch fails
    return {
      id: '1',
      phone_number: '694 171 171',
      email: 'kontakt@solrent.pl',
      updated_at: new Date().toISOString()
    };
  }

  return data;
};