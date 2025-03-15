import { supabase } from './supabase';
import { retryWithBackoff } from './utils';

interface EmailData {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  startDate: string;
  endDate: string;
  startTime: string;
  endTime: string;
  days: number;
  equipment: Array<{
    name: string;
    quantity: number;
    price: number;
  }>;
  totalPrice: number;
  deposit: number;
  companyName?: string;
  companyNip?: string;
  companyStreet?: string;
  companyPostalCode?: string;
  companyCity?: string;
  comment?: string;
}

export const sendEmails = async (data: EmailData): Promise<void> => {
  return retryWithBackoff(async () => {
    // Walidacja danych przed wysyłką
    if (!data.email || !data.firstName || !data.lastName) {
      throw new Error('Brak wymaganych danych do wysyłki maila');
    }

    // Walidacja długości i formatu danych
    if (data.phone.replace(/\s/g, '').length !== 9) {
      throw new Error('Nieprawidłowy format numeru telefonu');
    }

    if (data.comment && data.comment.length > 500) {
      throw new Error('Komentarz nie może przekraczać 500 znaków');
    }

    // Zapisz informację o mailach w bazie
    const { data: notifications, error: notificationError } = await supabase
      .from('email_notifications')
      .insert([
        {
          recipient: data.email,
          type: 'customer',
          status: 'pending',
          priority: 'high'
        },
        {
          recipient: 'biuro@solrent.pl',
          type: 'admin',
          status: 'pending',
          priority: 'high'
        }
      ])
      .select();

    if (notificationError) throw notificationError;

    // Wywołaj funkcję Edge Function do wysłania maili
    const { error: rpcError } = await supabase.rpc('send_reservation_emails', {
      p_customer_email: data.email,
      p_admin_email: 'biuro@solrent.pl',
      p_data: data,
      p_notification_ids: notifications.map(n => n.id)
    });

    if (rpcError) throw rpcError;
  }, 3, 1000); // 3 próby, zaczynając od 1 sekundy
};