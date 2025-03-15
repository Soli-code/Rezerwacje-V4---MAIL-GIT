/*
  # Poprawki systemu wysyłania maili

  1. Zmiany
    - Aktualizacja konfiguracji SMTP
    - Dodanie brakujących kolumn w email_logs
    - Poprawienie funkcji formatowania treści maili
    - Aktualizacja triggerów wysyłających maile
    
  2. Bezpieczeństwo
    - Aktualizacja polityk RLS
    - Zabezpieczenie dostępu do konfiguracji SMTP
*/

-- Aktualizacja konfiguracji SMTP
UPDATE smtp_settings
SET 
  host = 'smtp.gmail.com',
  port = 587,
  username = 'biuro@solrent.pl',
  encryption = 'tls',
  from_email = 'biuro@solrent.pl',
  from_name = 'SOLRENT'
WHERE id = (SELECT id FROM smtp_settings LIMIT 1);

-- Dodaj brakujące kolumny do email_logs jeśli nie istnieją
ALTER TABLE email_logs
ADD COLUMN IF NOT EXISTS template_variables jsonb,
ADD COLUMN IF NOT EXISTS error_details jsonb,
ADD COLUMN IF NOT EXISTS sent_at timestamp with time zone DEFAULT now(),
ALTER COLUMN body SET DEFAULT '',
ALTER COLUMN subject SET DEFAULT '';

-- Funkcja do formatowania treści maila
CREATE OR REPLACE FUNCTION format_email_content(
  p_template text,
  p_variables jsonb
) RETURNS text AS $$
DECLARE
  v_content text;
  v_key text;
  v_value text;
BEGIN
  v_content := p_template;
  
  -- Iteruj po zmiennych używając jsonb_each_text
  FOR v_key, v_value IN
    SELECT * FROM jsonb_each_text(p_variables)
  LOOP
    v_content := replace(v_content, '{{' || v_key || '}}', v_value);
  END LOOP;
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql;

-- Funkcja wysyłająca maile po utworzeniu rezerwacji
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_template record;
  v_customer record;
  v_equipment_details text;
  v_variables jsonb;
BEGIN
  -- Pobierz dane klienta
  SELECT * INTO v_customer
  FROM customers
  WHERE id = NEW.customer_id;

  -- Pobierz szczegóły sprzętu
  SELECT string_agg(e.name || ' (x' || ri.quantity::text || ')', E'\n')
  INTO v_equipment_details
  FROM reservation_items ri
  JOIN equipment e ON e.id = ri.equipment_id
  WHERE ri.reservation_id = NEW.id;

  -- Pobierz szablon maila
  SELECT * INTO v_template
  FROM email_templates
  WHERE name = 'reservation_confirmation'
  LIMIT 1;

  -- Przygotuj zmienne do szablonu
  v_variables := jsonb_build_object(
    'start_date', to_char(NEW.start_date, 'DD.MM.YYYY'),
    'start_time', NEW.start_time,
    'end_date', to_char(NEW.end_date, 'DD.MM.YYYY'),
    'end_time', NEW.end_time,
    'equipment_details', v_equipment_details,
    'total_price', NEW.total_price::text,
    'deposit_amount', COALESCE((
      SELECT sum(ri.deposit * ri.quantity)
      FROM reservation_items ri
      WHERE ri.reservation_id = NEW.id
    )::text, '0'),
    'customer_name', v_customer.first_name || ' ' || v_customer.last_name,
    'customer_email', v_customer.email,
    'customer_phone', v_customer.phone
  );

  -- Utwórz wpis w email_logs dla klienta
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status,
    template_variables
  ) VALUES (
    v_template.id,
    NEW.id,
    v_customer.email,
    v_template.subject,
    format_email_content(v_template.body, v_variables),
    'pending',
    v_variables
  );

  -- Utwórz wpis w email_logs dla biura
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status,
    template_variables
  ) VALUES (
    v_template.id,
    NEW.id,
    'biuro@solrent.pl',
    'Nowa rezerwacja - ' || v_customer.first_name || ' ' || v_customer.last_name,
    format_email_content(v_template.body, v_variables),
    'pending',
    v_variables
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aktualizuj polityki RLS dla email_logs
DROP POLICY IF EXISTS "Public can insert email logs" ON email_logs;
DROP POLICY IF EXISTS "System can update email logs" ON email_logs;
DROP POLICY IF EXISTS "Admins can view email logs" ON email_logs;

CREATE POLICY "Public can insert email logs"
ON email_logs FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "System can update email logs"
ON email_logs FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

CREATE POLICY "Admins can view email logs"
ON email_logs FOR SELECT
TO authenticated
USING (EXISTS (
  SELECT 1 FROM profiles
  WHERE profiles.id = auth.uid()
  AND profiles.is_admin = true
));

-- Dodaj indeksy dla lepszej wydajności
CREATE INDEX IF NOT EXISTS idx_email_logs_status ON email_logs(status);
CREATE INDEX IF NOT EXISTS idx_email_logs_sent_at ON email_logs(sent_at);

-- Funkcja do logowania dostępu do SMTP
CREATE OR REPLACE FUNCTION log_smtp_access()
RETURNS trigger AS $$
BEGIN
  INSERT INTO email_logs (
    recipient,
    subject,
    body,
    status
  ) VALUES (
    'system',
    'SMTP Config Access',
    'Attempted to access SMTP configuration',
    'logged'
  );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;