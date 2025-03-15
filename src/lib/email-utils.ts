// Funkcja pomocnicza do wysyłania emaili z szablonami
export async function sendTemplateEmail({
  recipientEmail,
  subject,
  htmlContent,
  templateData
}: {
  recipientEmail: string;
  subject: string;
  htmlContent: string;
  templateData: Record<string, string | number>;
}) {
  try {
    // Używamy klucza anonimowego do autoryzacji - działa dla wszystkich użytkowników
    const response = await fetch(
      `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/send-email-template`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY}`,
        },
        body: JSON.stringify({
          recipientEmail,
          subject,
          htmlContent,
          templateData,
        }),
      }
    );
    
    if (!response.ok) {
      const errorData = await response.json();
      console.error('Błąd wysyłania emaila:', errorData);
      throw new Error(`Błąd wysyłania emaila: ${errorData.error || response.statusText}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Błąd wysyłania emaila:', error);
    throw error;
  }
}

// Szablony emaili
export const emailTemplates = {
  newReservation: {
    subject: 'Potwierdzenie rezerwacji sprzętu',
    htmlContent: `<h1>Potwierdzenie rezerwacji</h1>
      <p>Szanowny/a {{first_name}} {{last_name}},</p>
      <p>Dziękujemy za dokonanie rezerwacji w SOLRENT. Poniżej znajdują się szczegóły Twojej rezerwacji:</p>
      <p>Data rozpoczęcia: {{start_date}} {{start_time}}<br>
      Data zakończenia: {{end_date}} {{end_time}}<br>
      Liczba dni: {{days}}</p>
      <p>Wybrany sprzęt:<br>{{equipment}}</p>
      <p>Całkowity koszt wypożyczenia: {{total_price}} zł<br>
      Wymagana kaucja: {{deposit}} zł</p>
      <p>Prosimy o przygotowanie:<br>
      - Dokumentu tożsamości<br>
      - Kaucji w wysokości {{deposit}} zł</p>
      <p>Przypominamy o godzinach otwarcia:<br>
      Poniedziałek - Piątek: 8:00 - 16:00<br>
      Sobota: 8:00 - 13:00<br>
      Niedziela: nieczynne</p>
      <p>W razie pytań prosimy o kontakt:<br>
      Tel: 694 171 171<br>
      Email: biuro@solrent.pl</p>
      <p>Pozdrawiamy,<br>
      Zespół SOLRENT</p>`
  },
  statusUpdate: {
    subject: 'Aktualizacja statusu rezerwacji',
    htmlContent: `<h1>Aktualizacja statusu rezerwacji</h1>
      <p>Szanowny/a {{first_name}} {{last_name}},</p>
      <p>Informujemy, że status Twojej rezerwacji został zmieniony na: <strong>{{status}}</strong></p>
      <p>Szczegóły rezerwacji:</p>
      <p>Data rozpoczęcia: {{start_date}} {{start_time}}<br>
      Data zakończenia: {{end_date}} {{end_time}}<br>
      Liczba dni: {{days}}</p>
      <p>Wybrany sprzęt:<br>{{equipment}}</p>
      <p>W razie pytań prosimy o kontakt:<br>
      Tel: 694 171 171<br>
      Email: biuro@solrent.pl</p>
      <p>Pozdrawiamy,<br>
      Zespół SOLRENT</p>`
  },
  cancelReservation: {
    subject: 'Anulowanie rezerwacji',
    htmlContent: `<h1>Anulowanie rezerwacji</h1>
      <p>Szanowny/a {{first_name}} {{last_name}},</p>
      <p>Informujemy, że Twoja rezerwacja została anulowana.</p>
      <p>Szczegóły anulowanej rezerwacji:</p>
      <p>Data rozpoczęcia: {{start_date}} {{start_time}}<br>
      Data zakończenia: {{end_date}} {{end_time}}<br>
      Liczba dni: {{days}}</p>
      <p>Wybrany sprzęt:<br>{{equipment}}</p>
      <p>Jeśli masz jakiekolwiek pytania, prosimy o kontakt:<br>
      Tel: 694 171 171<br>
      Email: biuro@solrent.pl</p>
      <p>Pozdrawiamy,<br>
      Zespół SOLRENT</p>`
  }
}; 