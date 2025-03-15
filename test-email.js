const testEmail = async () => {
  const response = await fetch(
    'https://klumxecllfauamqnrckf.supabase.co/functions/v1/send-email',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsdW14ZWNsbGZhdWFtcW5yY2tmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE2NDcyNzUsImV4cCI6MjA1NzIyMzI3NX0.S20v_K_5pDY0oA-4ztB1mlRWRF4vyt-NETZkvyx0PjE'
      },
      body: JSON.stringify({
        to: 'biuro@solrent.pl',
        from: 'biuro@solrent.pl',
        fromName: 'SOLRENT Rezerwacje',
        subject: 'Test konfiguracji SMTP',
        body: `
          <div style="font-family: Arial, sans-serif; padding: 20px;">
            <h2>Test konfiguracji SMTP</h2>
            <p>To jest wiadomość testowa wysłana z systemu rezerwacji SOLRENT.</p>
            <p>Data i czas testu: ${new Date().toLocaleString()}</p>
          </div>
        `,
        smtp: {
          host: 'h22.seohost.pl',
          port: 465,
          user: 'biuro@solrent.pl',
          pass: 'arELtGPxndj9KvpsjDtZ'
        }
      })
    }
  );

  const result = await response.json();
  console.log('Wynik testu:', result);
};

testEmail().catch(console.error); 