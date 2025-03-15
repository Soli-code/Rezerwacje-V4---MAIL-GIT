/*
  # Naprawa struktury tabel email i szablonów

  1. Zmiany
    - Zmiana typu kolumny body w email_templates na jsonb
    - Dodanie kolumny template_data do email_logs
    - Aktualizacja triggerów i funkcji
    
  2. Bezpieczeństwo
    - Zachowanie istniejących polityk RLS
    - Dodanie walidacji danych
*/

-- Dodaj nową kolumnę template_data do email_logs
ALTER TABLE email_logs
ADD COLUMN IF NOT EXISTS template_data jsonb;

-- Zmień typ kolumny body w email_templates na jsonb
ALTER TABLE email_templates
ALTER COLUMN body TYPE jsonb USING jsonb_build_object('content', body);

-- Zaktualizuj domyślny szablon potwierdzenia rezerwacji
INSERT INTO email_templates (name, subject, body)
VALUES (
  'reservation_confirmation',
  'Potwierdzenie rezerwacji SOLRENT',
  jsonb_build_object(
    'content', 
    'Dziękujemy za dokonanie rezerwacji w SOLRENT!

Szczegóły rezerwacji:
- Data rozpoczęcia: {{start_date}} {{start_time}}
- Data zakończenia: {{end_date}} {{end_time}}
- Zarezerwowany sprzęt: {{equipment_details}}
- Całkowity koszt: {{total_price}} zł

Dane klienta:
{{customer_name}}
Tel: {{customer_phone}}
Email: {{customer_email}}

{{comment}}

Z poważaniem,
Zespół SOLRENT'
  )
)
ON CONFLICT (name) 
DO UPDATE SET 
  body = EXCLUDED.body,
  updated_at = now();

-- Funkcja do formatowania treści maila
CREATE OR REPLACE FUNCTION format_email_content(
  p_template jsonb,
  p_variables jsonb
) RETURNS text AS $$
DECLARE
  v_content text;
  v_key text;
  v_value text;
BEGIN
  -- Pobierz treść szablonu
  v_content := p_template->>'content';
  
  -- Podstaw wszystkie zmienne
  FOR v_key, v_value IN
    SELECT key, value::text 
    FROM jsonb_each_text(p_variables)
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
    'customer_name', v_customer.first_name || ' ' || v_customer.last_name,
    'customer_email', v_customer.email,
    'customer_phone', v_customer.phone,
    'comment', COALESCE(NEW.comment, '')
  );

  -- Utwórz wpis w email_logs dla klienta
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status,
    template_data
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
    template_data
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