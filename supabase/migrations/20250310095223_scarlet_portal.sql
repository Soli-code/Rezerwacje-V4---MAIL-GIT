/*
  # Konfiguracja systemu email

  1. Zmiany
    - Dodanie kolumn do email_logs dla śledzenia statusu dostarczenia
    - Aktualizacja szablonu email dla potwierdzenia rezerwacji
    - Dodanie polityk bezpieczeństwa dla email_logs
    
  2. Bezpieczeństwo
    - Polityki RLS dla email_logs
    - Uprawnienia dla użytkowników publicznych
*/

-- Dodaj nowe kolumny do email_logs
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

-- Dodaj trigger dla obsługi ponownych prób
DROP TRIGGER IF EXISTS handle_email_retry_trigger ON email_logs;
CREATE TRIGGER handle_email_retry_trigger
  BEFORE UPDATE OF status ON email_logs
  FOR EACH ROW
  WHEN (NEW.status = 'failed')
  EXECUTE FUNCTION handle_email_retry();

-- Usuń istniejący szablon email jeśli istnieje
DELETE FROM email_template_variables 
WHERE template_id IN (SELECT id FROM email_templates WHERE name = 'reservation_confirmation');

DELETE FROM email_templates WHERE name = 'reservation_confirmation';

-- Dodaj szablon email dla potwierdzenia rezerwacji
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
INSERT INTO email_template_variables (template_id, variable_name, description)
SELECT 
  t.id,
  v.name,
  v.description
FROM email_templates t
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
) AS v(name, description)
WHERE t.name = 'reservation_confirmation';

-- Dodaj polityki RLS dla email_logs
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Polityka dla publicznego dostępu do tworzenia logów
DROP POLICY IF EXISTS "Public can insert email logs" ON email_logs;
CREATE POLICY "Public can insert email logs" ON email_logs
  FOR INSERT TO public
  WITH CHECK (true);

-- Polityka dla aktualizacji statusu
DROP POLICY IF EXISTS "System can update email logs" ON email_logs;
CREATE POLICY "System can update email logs" ON email_logs
  FOR UPDATE TO public
  USING (true)
  WITH CHECK (true);

-- Polityka dla odczytu logów przez administratorów
DROP POLICY IF EXISTS "Only admins can view email logs" ON email_logs;
CREATE POLICY "Only admins can view email logs" ON email_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );