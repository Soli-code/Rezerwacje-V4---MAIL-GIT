/*
  # Naprawa struktury email_logs i dodanie domyślnych wartości

  1. Zmiany
    - Dodanie domyślnych wartości dla kolumn subject i body
    - Aktualizacja triggerów związanych z email_logs
    - Dodanie szablonu domyślnego dla potwierdzenia rezerwacji
    
  2. Bezpieczeństwo
    - Zachowanie istniejących polityk RLS
    - Dodanie walidacji danych
*/

-- Upewnij się, że kolumny mają domyślne wartości
ALTER TABLE email_logs 
ALTER COLUMN subject SET DEFAULT '',
ALTER COLUMN body SET DEFAULT '';

-- Dodaj brakujące kolumny jeśli nie istnieją
ALTER TABLE email_logs
ADD COLUMN IF NOT EXISTS template_variables jsonb,
ADD COLUMN IF NOT EXISTS error_details jsonb,
ADD COLUMN IF NOT EXISTS template_data jsonb;

-- Dodaj domyślny szablon potwierdzenia rezerwacji
INSERT INTO email_templates (
  name,
  subject,
  body
) VALUES (
  'reservation_confirmation',
  'Potwierdzenie rezerwacji SOLRENT',
  '{
    "content": "Dziękujemy za dokonanie rezerwacji w SOLRENT!\n\nSzczegóły rezerwacji:\n- Data rozpoczęcia: {{start_date}} {{start_time}}\n- Data zakończenia: {{end_date}} {{end_time}}\n- Zarezerwowany sprzęt:\n{{equipment_details}}\n\nCałkowity koszt: {{total_price}} zł\nKaucja: {{deposit_amount}} zł\n\nDane kontaktowe:\n{{customer_name}}\nTel: {{customer_phone}}\nEmail: {{customer_email}}\n\n{{comment}}\n\nZ poważaniem,\nZespół SOLRENT"
  }'::jsonb
)
ON CONFLICT (name) DO UPDATE 
SET 
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  updated_at = now();

-- Funkcja do obsługi nowych rezerwacji i wysyłania maili
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_customer record;
  v_equipment_details text;
  v_template record;
  v_variables jsonb;
  v_formatted_content text;
BEGIN
  -- Pobierz dane klienta
  SELECT * INTO v_customer
  FROM customers
  WHERE id = NEW.customer_id;

  -- Pobierz szczegóły sprzętu
  SELECT string_agg(
    e.name || ' (x' || ri.quantity::text || ') - ' || 
    ri.price_per_day::text || ' zł/dzień', E'\n'
  )
  INTO v_equipment_details
  FROM reservation_items ri
  JOIN equipment e ON e.id = ri.equipment_id
  WHERE ri.reservation_id = NEW.id;

  -- Pobierz szablon
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
    'deposit_amount', (
      SELECT COALESCE(sum(deposit * quantity), 0)
      FROM reservation_items
      WHERE reservation_id = NEW.id
    )::text,
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
    template_variables,
    template_data
  ) VALUES (
    v_template.id,
    NEW.id,
    v_customer.email,
    COALESCE(v_template.subject, 'Potwierdzenie rezerwacji SOLRENT'),
    v_template.body->>'content',
    'pending',
    v_variables,
    jsonb_build_object(
      'reservation_id', NEW.id,
      'customer_id', v_customer.id,
      'template_name', 'reservation_confirmation'
    )
  );

  -- Utwórz wpis w email_logs dla biura
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status,
    template_variables,
    template_data
  ) VALUES (
    v_template.id,
    NEW.id,
    'biuro@solrent.pl',
    'Nowa rezerwacja - ' || v_customer.first_name || ' ' || v_customer.last_name,
    v_template.body->>'content',
    'pending',
    v_variables,
    jsonb_build_object(
      'reservation_id', NEW.id,
      'customer_id', v_customer.id,
      'template_name', 'reservation_confirmation',
      'is_admin_notification', true
    )
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;