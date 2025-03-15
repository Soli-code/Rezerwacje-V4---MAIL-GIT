/*
  # Setup email templates and sending function

  1. Changes
    - Usunięcie istniejącej funkcji send_reservation_emails
    - Dodanie szablonów emaili
    - Ponowne utworzenie funkcji send_reservation_emails

  2. Templates
    - Szablon potwierdzenia rezerwacji dla klienta
    - Szablon powiadomienia dla administratora
*/

-- Najpierw usuń istniejącą funkcję
DROP FUNCTION IF EXISTS send_reservation_emails(text, text, jsonb, uuid[]);

-- Dodaj domyślne szablony emaili
INSERT INTO email_templates (name, subject, content, variables) VALUES
(
  'reservation_confirmation',
  'Potwierdzenie rezerwacji sprzętu - SOLRENT',
  '<!DOCTYPE html>
  <html>
  <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <h2>Dziękujemy za rezerwację sprzętu w SOLRENT!</h2>
    <p>Witaj {{firstName}} {{lastName}},</p>
    <p>Potwierdzamy otrzymanie Twojej rezerwacji:</p>
    
    <div style="background: #f5f5f5; padding: 15px; margin: 20px 0;">
      <h3>Szczegóły rezerwacji:</h3>
      <p>Data rozpoczęcia: {{startDate}} {{startTime}}</p>
      <p>Data zakończenia: {{endDate}} {{endTime}}</p>
      <p>Liczba dni: {{days}}</p>
      
      <h4>Zarezerwowany sprzęt:</h4>
      {{#each equipment}}
      <p>- {{name}} ({{quantity}} szt.) - {{price}} zł/dzień</p>
      {{/each}}
      
      <p><strong>Całkowity koszt wypożyczenia: {{totalPrice}} zł</strong></p>
      <p><strong>Wymagana kaucja: {{deposit}} zł</strong></p>
    </div>

    {{#if companyName}}
    <div style="background: #f5f5f5; padding: 15px; margin: 20px 0;">
      <h3>Dane do faktury:</h3>
      <p>{{companyName}}</p>
      <p>NIP: {{companyNip}}</p>
      <p>{{companyStreet}}</p>
      <p>{{companyPostalCode}} {{companyCity}}</p>
    </div>
    {{/if}}

    <h3>Ważne informacje:</h3>
    <ul>
      <li>Sprzęt można odebrać i zwrócić w godzinach pracy wypożyczalni</li>
      <li>Wymagany dokument tożsamości przy odbiorze</li>
      <li>Kaucja jest pobierana przy odbiorze sprzętu</li>
    </ul>

    <p>W razie pytań prosimy o kontakt:</p>
    <p>Tel: 694 171 171</p>
    <p>Email: biuro@solrent.pl</p>

    <p style="color: #666; font-size: 12px; margin-top: 30px;">
      Wiadomość wygenerowana automatycznie, prosimy na nią nie odpowiadać.
    </p>
  </body>
  </html>',
  '{"firstName": "Imię klienta", "lastName": "Nazwisko klienta", "startDate": "Data rozpoczęcia", "endDate": "Data zakończenia", "startTime": "Godzina rozpoczęcia", "endTime": "Godzina zakończenia", "days": "Liczba dni", "equipment": "Lista sprzętu", "totalPrice": "Całkowity koszt", "deposit": "Kaucja", "companyName": "Nazwa firmy", "companyNip": "NIP", "companyStreet": "Ulica", "companyPostalCode": "Kod pocztowy", "companyCity": "Miasto"}'::jsonb
),
(
  'admin_notification',
  'Nowa rezerwacja sprzętu',
  '<!DOCTYPE html>
  <html>
  <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <h2>Nowa rezerwacja sprzętu</h2>
    
    <div style="background: #f5f5f5; padding: 15px; margin: 20px 0;">
      <h3>Dane klienta:</h3>
      <p>{{firstName}} {{lastName}}</p>
      <p>Email: {{email}}</p>
      <p>Telefon: {{phone}}</p>
      
      {{#if companyName}}
      <h4>Dane firmy:</h4>
      <p>{{companyName}}</p>
      <p>NIP: {{companyNip}}</p>
      <p>{{companyStreet}}</p>
      <p>{{companyPostalCode}} {{companyCity}}</p>
      {{/if}}
    </div>

    <div style="background: #f5f5f5; padding: 15px; margin: 20px 0;">
      <h3>Szczegóły rezerwacji:</h3>
      <p>Data rozpoczęcia: {{startDate}} {{startTime}}</p>
      <p>Data zakończenia: {{endDate}} {{endTime}}</p>
      <p>Liczba dni: {{days}}</p>
      
      <h4>Zarezerwowany sprzęt:</h4>
      {{#each equipment}}
      <p>- {{name}} ({{quantity}} szt.) - {{price}} zł/dzień</p>
      {{/each}}
      
      <p><strong>Całkowity koszt wypożyczenia: {{totalPrice}} zł</strong></p>
      <p><strong>Wymagana kaucja: {{deposit}} zł</strong></p>
    </div>

    {{#if comment}}
    <div style="background: #f5f5f5; padding: 15px; margin: 20px 0;">
      <h3>Komentarz klienta:</h3>
      <p>{{comment}}</p>
    </div>
    {{/if}}
  </body>
  </html>',
  '{"firstName": "Imię klienta", "lastName": "Nazwisko klienta", "email": "Email klienta", "phone": "Telefon klienta", "startDate": "Data rozpoczęcia", "endDate": "Data zakończenia", "startTime": "Godzina rozpoczęcia", "endTime": "Godzina zakończenia", "days": "Liczba dni", "equipment": "Lista sprzętu", "totalPrice": "Całkowity koszt", "deposit": "Kaucja", "companyName": "Nazwa firmy", "companyNip": "NIP", "companyStreet": "Ulica", "companyPostalCode": "Kod pocztowy", "companyCity": "Miasto", "comment": "Komentarz"}'::jsonb
);

-- Funkcja do wysyłania maili dla rezerwacji
CREATE OR REPLACE FUNCTION send_reservation_emails(
  p_customer_email text,
  p_admin_email text,
  p_data jsonb,
  p_notification_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_template email_templates%ROWTYPE;
  v_admin_template email_templates%ROWTYPE;
  v_customer_content text;
  v_admin_content text;
  v_customer_subject text;
  v_admin_subject text;
  v_result jsonb;
BEGIN
  -- Pobierz szablony
  SELECT * INTO v_customer_template 
  FROM email_templates 
  WHERE name = 'reservation_confirmation';
  
  SELECT * INTO v_admin_template 
  FROM email_templates 
  WHERE name = 'admin_notification';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email templates not found';
  END IF;

  -- Przygotuj treść maili używając Handlebars (funkcja zaimplementowana w Edge Function)
  SELECT content INTO v_customer_content 
  FROM http((
    'POST',
    current_setting('app.settings.edge_function_url') || '/render-template',
    ARRAY[http_header('Content-Type', 'application/json')],
    jsonb_build_object(
      'template', v_customer_template.content,
      'data', p_data
    )::text,
    60
  ));

  SELECT content INTO v_admin_content 
  FROM http((
    'POST',
    current_setting('app.settings.edge_function_url') || '/render-template',
    ARRAY[http_header('Content-Type', 'application/json')],
    jsonb_build_object(
      'template', v_admin_template.content,
      'data', p_data
    )::text,
    60
  ));

  -- Wyślij mail do klienta
  v_result := send_email(
    p_customer_email,
    v_customer_template.subject,
    v_customer_content
  );

  -- Zaktualizuj status powiadomienia dla klienta
  UPDATE email_notifications 
  SET 
    status = CASE 
      WHEN (v_result->>'success')::boolean THEN 'sent'
      ELSE 'failed'
    END,
    error_message = v_result->>'error',
    sent_at = NOW()
  WHERE id = p_notification_ids[1];

  -- Wyślij mail do admina
  v_result := send_email(
    p_admin_email,
    v_admin_template.subject,
    v_admin_content
  );

  -- Zaktualizuj status powiadomienia dla admina
  UPDATE email_notifications 
  SET 
    status = CASE 
      WHEN (v_result->>'success')::boolean THEN 'sent'
      ELSE 'failed'
    END,
    error_message = v_result->>'error',
    sent_at = NOW()
  WHERE id = p_notification_ids[2];

EXCEPTION
  WHEN OTHERS THEN
    -- W przypadku błędu oznacz oba powiadomienia jako failed
    UPDATE email_notifications 
    SET 
      status = 'failed',
      error_message = SQLERRM,
      sent_at = NOW()
    WHERE id = ANY(p_notification_ids);
    
    RAISE;
END;
$$;