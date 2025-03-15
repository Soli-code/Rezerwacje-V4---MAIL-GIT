/*
  # Aktualizacja konfiguracji email

  1. Zmiany
    - Aktualizacja konfiguracji SMTP
    - Aktualizacja szablonu email dla nowych rezerwacji
    - Dodanie zmiennych szablonu
*/

-- Usuń starą konfigurację SMTP jeśli istnieje
DELETE FROM smtp_settings;

-- Dodaj nową konfigurację SMTP
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
) VALUES (
  '188.210.221.82',
  465,
  'biuro@solrent.pl',
  'arELtGPxndj9KvpsjDtZ',
  'biuro@solrent.pl',
  'SOLRENT',
  'tls'
);

-- Usuń stary szablon jeśli istnieje
DELETE FROM email_template_variables;
DELETE FROM email_templates;

-- Dodaj nowy szablon potwierdzenia rezerwacji
WITH new_template AS (
  INSERT INTO email_templates (name, subject, body)
  VALUES (
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
  )
  RETURNING id
)
-- Dodaj zmienne szablonu
INSERT INTO email_template_variables (template_id, variable_name, description)
SELECT 
  t.id,
  v.variable_name,
  v.description
FROM new_template t
CROSS JOIN (
  VALUES 
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
    ('deposit_amount', 'Kwota kaucji')
) AS v(variable_name, description);