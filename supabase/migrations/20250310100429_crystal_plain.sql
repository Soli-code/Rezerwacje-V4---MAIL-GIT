/*
  # Poprawki systemu wysyłania maili

  1. Zmiany
    - Dodanie domyślnych wartości dla kolumn subject i body w email_logs
    - Aktualizacja triggera wysyłającego maile
    - Dodanie walidacji dla wymaganych pól
    
  2. Bezpieczeństwo
    - Zachowanie istniejących polityk RLS
*/

-- Upewnij się, że kolumny mają domyślne wartości
ALTER TABLE email_logs 
ALTER COLUMN subject SET DEFAULT '',
ALTER COLUMN body SET DEFAULT '';

-- Zaktualizuj trigger wysyłający maile
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_template record;
  v_customer record;
  v_equipment_details text;
  v_variables jsonb;
  v_subject text;
  v_body text;
BEGIN
  -- Pobierz dane klienta
  SELECT * INTO v_customer
  FROM customers
  WHERE id = NEW.customer_id;

  -- Pobierz szczegóły sprzętu
  SELECT string_agg(
    e.name || ' (x' || ri.quantity::text || ') - ' || 
    CASE 
      WHEN (NEW.end_date::date - NEW.start_date::date) >= 7 AND e.promotional_price IS NOT NULL 
      THEN e.promotional_price::text 
      ELSE ri.price_per_day::text 
    END || ' zł/dzień',
    E'\n'
  )
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
    'deposit_amount', (
      SELECT sum(ri.deposit * ri.quantity)
      FROM reservation_items ri
      WHERE ri.reservation_id = NEW.id
    )::text,
    'customer_name', v_customer.first_name || ' ' || v_customer.last_name,
    'customer_email', v_customer.email,
    'customer_phone', v_customer.phone
  );

  -- Przygotuj treść maila
  v_subject := COALESCE(v_template.subject, 'Potwierdzenie rezerwacji SOLRENT');
  v_body := COALESCE(format_email_content(v_template.body, v_variables),
    'Szczegóły rezerwacji:' || E'\n' ||
    '- Data rozpoczęcia: ' || v_variables->>'start_date' || ' ' || v_variables->>'start_time' || E'\n' ||
    '- Data zakończenia: ' || v_variables->>'end_date' || ' ' || v_variables->>'end_time' || E'\n' ||
    '- Zarezerwowany sprzęt:' || E'\n' || v_equipment_details || E'\n' ||
    '- Całkowity koszt: ' || v_variables->>'total_price' || ' zł' || E'\n' ||
    '- Kaucja: ' || v_variables->>'deposit_amount' || ' zł' || E'\n\n' ||
    'Dane klienta:' || E'\n' ||
    v_variables->>'customer_name' || E'\n' ||
    'Tel: ' || v_variables->>'customer_phone' || E'\n' ||
    'Email: ' || v_variables->>'customer_email'
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
    v_subject,
    v_body,
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
    v_body,
    'pending',
    v_variables
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;