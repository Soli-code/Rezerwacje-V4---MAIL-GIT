/*
  # Add email notifications system

  1. New Functions
    - `handle_new_reservation_email()`: Wysyła powiadomienia email po utworzeniu nowej rezerwacji
    
  2. New Tables
    - `email_templates`: Przechowuje szablony wiadomości email
    - `email_logs`: Zapisuje historię wysłanych wiadomości
    
  3. Security
    - Dostęp do tabel tylko dla administratorów
    - Trigger na tabeli reservations
*/

-- Tabela z szablonami email
CREATE TABLE IF NOT EXISTS email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela logów email
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id),
  reservation_id uuid REFERENCES reservations(id),
  recipient text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  status text NOT NULL,
  error_message text,
  sent_at timestamptz DEFAULT now()
);

-- Dodaj podstawowy szablon
INSERT INTO email_templates (name, subject, body) 
VALUES (
  'new_reservation',
  'Nowa rezerwacja - [Data]',
  'Nowa rezerwacja w systemie SOLRENT:

Dane klienta:
Imię i nazwisko: {{customer_name}}
Email: {{customer_email}}
Telefon: {{customer_phone}}

Szczegóły rezerwacji:
Data rozpoczęcia: {{start_date}}
Data zakończenia: {{end_date}}
Godzina odbioru: {{start_time}}
Godzina zwrotu: {{end_time}}

Zarezerwowany sprzęt:
{{equipment_list}}

Dodatkowe uwagi:
{{comment}}

Numer rezerwacji: {{reservation_id}}

Łączna kwota: {{total_price}} PLN
Kaucja: {{deposit_amount}} PLN'
);

-- Funkcja wysyłająca email
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_customer record;
  v_equipment text;
  v_template record;
  v_body text;
  v_subject text;
  v_reservation_items record;
BEGIN
  -- Pobierz dane klienta
  SELECT c.* INTO v_customer
  FROM customers c
  WHERE c.id = NEW.customer_id;

  -- Pobierz szablon
  SELECT * INTO v_template
  FROM email_templates
  WHERE name = 'new_reservation';

  -- Przygotuj listę sprzętu
  SELECT string_agg(
    e.name || ' (x' || ri.quantity || ') - ' || ri.price_per_day || ' PLN/dzień',
    E'\n'
  ) INTO v_equipment
  FROM reservation_items ri
  JOIN equipment e ON e.id = ri.equipment_id
  WHERE ri.reservation_id = NEW.id;

  -- Przygotuj treść
  v_body := v_template.body;
  v_body := replace(v_body, '{{customer_name}}', v_customer.first_name || ' ' || v_customer.last_name);
  v_body := replace(v_body, '{{customer_email}}', v_customer.email);
  v_body := replace(v_body, '{{customer_phone}}', v_customer.phone);
  v_body := replace(v_body, '{{start_date}}', to_char(NEW.start_date, 'DD.MM.YYYY'));
  v_body := replace(v_body, '{{end_date}}', to_char(NEW.end_date, 'DD.MM.YYYY'));
  v_body := replace(v_body, '{{start_time}}', NEW.start_time);
  v_body := replace(v_body, '{{end_time}}', NEW.end_time);
  v_body := replace(v_body, '{{equipment_list}}', v_equipment);
  v_body := replace(v_body, '{{comment}}', COALESCE(NEW.comment, 'Brak'));
  v_body := replace(v_body, '{{reservation_id}}', NEW.id::text);
  v_body := replace(v_body, '{{total_price}}', NEW.total_price::text);
  v_body := replace(v_body, '{{deposit_amount}}', v_customer.deposit_amount::text);

  -- Przygotuj temat
  v_subject := replace(v_template.subject, '[Data]', to_char(NEW.start_date, 'DD.MM.YYYY'));

  -- Wyślij email przez Supabase Edge Functions
  PERFORM net.http_post(
    url := 'https://vzlmzerpjxaikfpzfzdb.supabase.co/functions/v1/send-email',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', current_setting('request.headers')::json->>'apikey'
    ),
    body := jsonb_build_object(
      'to', 'biuro@solrent.pl',
      'subject', v_subject,
      'body', v_body
    )
  );

  -- Zapisz log
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status
  ) VALUES (
    v_template.id,
    NEW.id,
    'biuro@solrent.pl',
    v_subject,
    v_body,
    'sent'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Dodaj trigger
CREATE TRIGGER send_new_reservation_email
AFTER INSERT ON reservations
FOR EACH ROW
EXECUTE FUNCTION handle_new_reservation_email();

-- Zabezpieczenia
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins can manage email templates"
ON email_templates
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  )
);

CREATE POLICY "Only admins can view email logs"
ON email_logs
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  )
);