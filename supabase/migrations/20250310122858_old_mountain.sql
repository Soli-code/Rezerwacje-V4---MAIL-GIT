/*
  # Konfiguracja systemu mailowego
  
  1. Nowe Szablony
     - Szablon potwierdzenia rezerwacji dla klienta
     - Szablon powiadomienia wewnętrznego
  
  2. Zmienne Szablonów
     - Dane klienta (imię, nazwisko, kontakt)
     - Szczegóły rezerwacji (data, godzina, sprzęt)
     - Informacje o płatnościach
  
  3. Konfiguracja SMTP i ustawienia retry
*/

-- Bezpieczne dodawanie szablonu potwierdzenia rezerwacji
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
END $$;

-- Bezpieczne dodawanie szablonu powiadomienia wewnętrznego
DO $$
BEGIN
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

-- Bezpieczne dodawanie konfiguracji SMTP
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

-- Bezpieczne dodawanie ustawień ponownych prób
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

-- Bezpieczne dodawanie zmiennych szablonów
DO $$
DECLARE
  template_record RECORD;
  variable_names text[] := ARRAY[
    'first_name',
    'last_name',
    'email',
    'phone',
    'start_date',
    'end_date',
    'start_time',
    'end_time',
    'equipment_list',
    'total_price',
    'deposit_amount',
    'comment'
  ];
  variable_descriptions text[] := ARRAY[
    'Imię klienta',
    'Nazwisko klienta',
    'Adres email klienta',
    'Numer telefonu klienta',
    'Data rozpoczęcia',
    'Data zakończenia',
    'Godzina rozpoczęcia',
    'Godzina zakończenia',
    'Lista zarezerwowanego sprzętu',
    'Całkowity koszt',
    'Kwota kaucji',
    'Komentarz klienta'
  ];
  i int;
BEGIN
  FOR template_record IN SELECT id FROM email_templates WHERE name IN ('new_reservation', 'internal_notification')
  LOOP
    FOR i IN 1..array_length(variable_names, 1)
    LOOP
      IF NOT EXISTS (
        SELECT 1 
        FROM email_template_variables 
        WHERE template_id = template_record.id 
        AND variable_name = variable_names[i]
      ) THEN
        INSERT INTO email_template_variables (
          id,
          template_id, 
          variable_name, 
          description
        ) VALUES (
          gen_random_uuid(),
          template_record.id,
          variable_names[i],
          variable_descriptions[i]
        );
      END IF;
    END LOOP;
  END LOOP;
END $$;