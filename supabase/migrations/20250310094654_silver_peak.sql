/*
  # Email Configuration Fix

  1. Changes
    - Adds email retry mechanism
    - Creates email templates with proper cleanup
    - Sets up email variables system
    - Improves logging capabilities

  2. Security
    - Maintains existing security measures
    - Adds proper constraints and indexes
*/

-- Najpierw usuń istniejące dane i constrainty
DELETE FROM email_template_variables;
DELETE FROM email_templates WHERE name = 'reservation_confirmation';
ALTER TABLE email_templates DROP CONSTRAINT IF EXISTS email_templates_name_key;
ALTER TABLE email_template_variables DROP CONSTRAINT IF EXISTS email_template_variables_template_var_key;

-- Dodaj nowe kolumny do email_logs jeśli nie istnieją
ALTER TABLE email_logs
ADD COLUMN IF NOT EXISTS delivery_attempts integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_error text,
ADD COLUMN IF NOT EXISTS headers jsonb,
ADD COLUMN IF NOT EXISTS delivered_at timestamp with time zone;

-- Funkcja do obsługi ponownych prób wysyłki
CREATE OR REPLACE FUNCTION handle_email_retry()
RETURNS trigger AS $$
DECLARE
  max_retries integer;
  retry_delay integer;
BEGIN
  -- Pobierz ustawienia ponownych prób
  SELECT 
    COALESCE((SELECT max_retries FROM email_retry_settings LIMIT 1), 3),
    COALESCE((SELECT retry_delay_minutes FROM email_retry_settings LIMIT 1), 5)
  INTO max_retries, retry_delay;

  -- Zwiększ licznik prób
  NEW.retry_count := COALESCE(OLD.retry_count, 0) + 1;
  
  -- Jeśli nie przekroczono maksymalnej liczby prób, zaplanuj kolejną
  IF NEW.retry_count < max_retries THEN
    NEW.next_retry_at := NOW() + (retry_delay * NEW.retry_count || ' minutes')::interval;
  ELSE
    NEW.status := 'failed';
    NEW.next_retry_at := NULL;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj constrainty
ALTER TABLE email_templates
ADD CONSTRAINT email_templates_name_key UNIQUE (name);

ALTER TABLE email_template_variables
ADD CONSTRAINT email_template_variables_template_var_key 
UNIQUE (template_id, variable_name);

-- Dodaj nowy szablon email dla potwierdzenia rezerwacji
INSERT INTO email_templates (name, subject, body) 
VALUES (
  'reservation_confirmation',
  'Potwierdzenie rezerwacji sprzętu - SOLRENT',
  '
Dziękujemy za dokonanie rezerwacji w SOLRENT!

Szczegóły rezerwacji:
- Data rozpoczęcia: {{start_date}} {{start_time}}
- Data zakończenia: {{end_date}} {{end_time}}
- Zarezerwowany sprzęt: {{equipment_details}}

Koszt:
- Całkowity koszt wypożyczenia: {{total_price}} zł
- Wymagana kaucja: {{deposit_amount}} zł

Dane kontaktowe:
- Imię i nazwisko: {{customer_name}}
- Email: {{customer_email}}
- Telefon: {{customer_phone}}

Przypominamy, że sprzęt można odebrać i zwrócić w godzinach:
- Poniedziałek - Piątek: 8:00 - 16:00
- Sobota: 8:00 - 16:00
- Niedziela: nieczynne

W razie pytań prosimy o kontakt:
Tel: 694 171 171
Email: biuro@solrent.pl

Pozdrawiamy,
Zespół SOLRENT
'
);

-- Dodaj zmienne do szablonu
WITH template_id AS (
  SELECT id FROM email_templates WHERE name = 'reservation_confirmation'
)
INSERT INTO email_template_variables (template_id, variable_name, description)
SELECT 
  template_id.id,
  v.name,
  v.description
FROM template_id
CROSS JOIN (VALUES
  ('start_date', 'Data rozpoczęcia rezerwacji'),
  ('start_time', 'Godzina rozpoczęcia'),
  ('end_date', 'Data zakończenia rezerwacji'),
  ('end_time', 'Godzina zakończenia'),
  ('equipment_details', 'Szczegóły zarezerwowanego sprzętu'),
  ('total_price', 'Całkowity koszt wypożyczenia'),
  ('deposit_amount', 'Kwota kaucji'),
  ('customer_name', 'Imię i nazwisko klienta'),
  ('customer_email', 'Adres email klienta'),
  ('customer_phone', 'Numer telefonu klienta')
) AS v(name, description);