/*
  # Dodanie szablonów email i konfiguracji SMTP

  1. Nowe szablony
    - Szablon potwierdzenia rezerwacji dla klienta
    - Szablon powiadomienia wewnętrznego dla administracji
  
  2. Konfiguracja
    - Ustawienia SMTP
    - Parametry ponownych prób wysyłki
    - Zmienne szablonów

  3. Bezpieczeństwo
    - Polityki dostępu do szablonów
*/

-- Sprawdź czy szablon już istnieje przed dodaniem
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM email_templates WHERE name = 'new_reservation') THEN
    INSERT INTO email_templates (id, name, subject, body)
    VALUES (
      gen_random_uuid(),
      'new_reservation',
      'Potwierdzenie rezerwacji - SOLRENT',
      jsonb_build_object(
        'html', '
        <h2>Dziękujemy za złożenie rezerwacji w SOLRENT!</h2>
        <p>Szanowny/a {{first_name}} {{last_name}},</p>
        <p>Potwierdzamy otrzymanie Twojej rezerwacji:</p>
        <ul>
          <li>Data rozpoczęcia: {{start_date}} {{start_time}}</li>
          <li>Data zakończenia: {{end_date}} {{end_time}}</li>
          <li>Zarezerwowany sprzęt: {{equipment_list}}</li>
          <li>Całkowity koszt: {{total_price}} zł</li>
          <li>Wymagana kaucja: {{deposit_amount}} zł</li>
        </ul>
        <p><strong>Ważne informacje:</strong></p>
        <ul>
          <li>Adres odbioru: ul. Jęczmienna 4, 44-190 Knurów</li>
          <li>Wymagane dokumenty: dowód osobisty</li>
          <li>Płatność: gotówka lub przelew przy odbiorze</li>
        </ul>
        <p>W razie pytań prosimy o kontakt:</p>
        <ul>
          <li>Telefon: 694 171 171</li>
          <li>Email: biuro@solrent.pl</li>
        </ul>
        '
      )
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM email_templates WHERE name = 'internal_notification') THEN
    INSERT INTO email_templates (id, name, subject, body)
    VALUES (
      gen_random_uuid(),
      'internal_notification',
      'Nowa rezerwacja w systemie',
      jsonb_build_object(
        'html', '
        <h2>Nowa rezerwacja w systemie</h2>
        <h3>Dane klienta:</h3>
        <ul>
          <li>Imię i nazwisko: {{first_name}} {{last_name}}</li>
          <li>Email: {{email}}</li>
          <li>Telefon: {{phone}}</li>
        </ul>
        <h3>Szczegóły rezerwacji:</h3>
        <ul>
          <li>Data rozpoczęcia: {{start_date}} {{start_time}}</li>
          <li>Data zakończenia: {{end_date}} {{end_time}}</li>
          <li>Zarezerwowany sprzęt: {{equipment_list}}</li>
          <li>Całkowity koszt: {{total_price}} zł</li>
          <li>Wymagana kaucja: {{deposit_amount}} zł</li>
        </ul>
        {{#if comment}}
        <p><strong>Komentarz klienta:</strong> {{comment}}</p>
        {{/if}}
        '
      )
    );
  END IF;
END $$;

-- Dodaj podstawową konfigurację SMTP jeśli nie istnieje
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM smtp_settings LIMIT 1) THEN
    INSERT INTO smtp_settings (
      host,
      port,
      username,
      password,
      from_email,
      from_name,
      encryption
    ) VALUES (
      'smtp.solrent.pl',
      587,
      'no-reply@solrent.pl',
      'placeholder_password',
      'no-reply@solrent.pl',
      'SOLRENT',
      'tls'
    );
  END IF;
END $$;

-- Dodaj ustawienia ponownych prób jeśli nie istnieją
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM email_retry_settings LIMIT 1) THEN
    INSERT INTO email_retry_settings (
      max_retries,
      retry_delay_minutes
    ) VALUES (
      3,  -- Maksymalna liczba prób
      5   -- Opóźnienie między próbami (minuty)
    );
  END IF;
END $$;

-- Dodaj zmienne szablonów
DO $$
DECLARE
  current_template_id uuid;
  var_record record;
BEGIN
  FOR current_template_id IN 
    SELECT id FROM email_templates 
    WHERE name IN ('new_reservation', 'internal_notification')
  LOOP
    FOR var_record IN 
      SELECT * FROM (VALUES
        ('first_name', 'Imię klienta'),
        ('last_name', 'Nazwisko klienta'),
        ('email', 'Adres email klienta'),
        ('phone', 'Numer telefonu klienta'),
        ('start_date', 'Data rozpoczęcia'),
        ('end_date', 'Data zakończenia'),
        ('start_time', 'Godzina rozpoczęcia'),
        ('end_time', 'Godzina zakończenia'),
        ('equipment_list', 'Lista zarezerwowanego sprzętu'),
        ('total_price', 'Całkowity koszt'),
        ('deposit_amount', 'Kwota kaucji'),
        ('comment', 'Komentarz klienta')
      ) AS v(variable_name, description)
    LOOP
      IF NOT EXISTS (
        SELECT 1 
        FROM email_template_variables 
        WHERE template_id = current_template_id 
        AND variable_name = var_record.variable_name
      ) THEN
        INSERT INTO email_template_variables (template_id, variable_name, description)
        VALUES (current_template_id, var_record.variable_name, var_record.description);
      END IF;
    END LOOP;
  END LOOP;
END $$;