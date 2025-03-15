/*
  # Email System Functions Fix

  1. Changes
    - Fix variable declarations in format_email_content function
    - Recreate email handling functions with proper syntax
    - Update triggers for email handling
    
  2. Security
    - Maintain secure SMTP configuration
    - Proper error handling and logging
*/

-- Drop existing functions and triggers first
DROP TRIGGER IF EXISTS send_new_reservation_email ON reservations;
DROP TRIGGER IF EXISTS handle_email_retry_trigger ON email_logs;
DROP FUNCTION IF EXISTS format_email_content(text, jsonb);
DROP FUNCTION IF EXISTS handle_new_reservation_email();
DROP FUNCTION IF EXISTS handle_email_retry();

-- Recreate funkcja formatująca treść emaila z poprawną deklaracją zmiennych
CREATE FUNCTION format_email_content(
  template_name text,
  variables jsonb
) RETURNS jsonb AS $$
DECLARE
  template_record RECORD;
  formatted_text text;
  formatted_html text;
  var_key text;
  var_value text;
BEGIN
  -- Pobierz szablon
  SELECT * INTO template_record
  FROM email_templates
  WHERE name = template_name;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email template not found: %', template_name;
  END IF;

  -- Przygotuj tekst i HTML
  formatted_text := template_record.body->>'text';
  formatted_html := template_record.body->>'html';

  -- Zastąp zmienne w tekście
  FOR var_key, var_value IN
    SELECT * FROM jsonb_each_text(variables)
  LOOP
    formatted_text := replace(formatted_text, '{{' || var_key || '}}', var_value);
    formatted_html := replace(formatted_html, '{{' || var_key || '}}', var_value);
  END LOOP;

  RETURN jsonb_build_object(
    'text', formatted_text,
    'html', formatted_html
  );
END;
$$ LANGUAGE plpgsql;

-- Recreate funkcja wysyłająca email po nowej rezerwacji
CREATE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  customer_record RECORD;
  equipment_list text;
  email_vars jsonb;
  email_content jsonb;
  smtp_settings_record RECORD;
BEGIN
  -- Pobierz dane klienta
  SELECT c.*, 
         string_agg(e.name || ' x' || ri.quantity, E'\n') as equipment_names,
         sum(ri.price_per_day * ri.quantity) as total_price,
         sum(ri.deposit) as total_deposit
  INTO customer_record
  FROM customers c
  LEFT JOIN reservation_items ri ON ri.reservation_id = NEW.id
  LEFT JOIN equipment e ON e.id = ri.equipment_id
  WHERE c.id = NEW.customer_id
  GROUP BY c.id;

  -- Przygotuj zmienne dla szablonu
  email_vars := jsonb_build_object(
    'customer_name', customer_record.first_name || ' ' || customer_record.last_name,
    'start_date', to_char(NEW.start_date, 'DD.MM.YYYY HH24:MI'),
    'end_date', to_char(NEW.end_date, 'DD.MM.YYYY HH24:MI'),
    'equipment_list', customer_record.equipment_names,
    'total_price', customer_record.total_price::text,
    'deposit_amount', customer_record.total_deposit::text
  );

  -- Formatuj treść emaila
  email_content := format_email_content('new_reservation', email_vars);

  -- Zapisz próbę wysłania w logach
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status,
    template_variables
  ) VALUES (
    (SELECT id FROM email_templates WHERE name = 'new_reservation'),
    NEW.id,
    customer_record.email,
    'Potwierdzenie rezerwacji - SOLRENT',
    email_content,
    'pending',
    email_vars
  );

  -- Wyślij kopię do administratora
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status,
    template_variables
  ) VALUES (
    (SELECT id FROM email_templates WHERE name = 'admin_notification'),
    NEW.id,
    'kubens11r@gmail.com',
    'Nowa rezerwacja - SOLRENT',
    format_email_content('admin_notification', jsonb_build_object(
      'customer_name', customer_record.first_name || ' ' || customer_record.last_name,
      'customer_email', customer_record.email,
      'customer_phone', customer_record.phone,
      'start_date', to_char(NEW.start_date, 'DD.MM.YYYY HH24:MI'),
      'end_date', to_char(NEW.end_date, 'DD.MM.YYYY HH24:MI'),
      'equipment_list', customer_record.equipment_names,
      'total_price', customer_record.total_price::text,
      'deposit_amount', customer_record.total_deposit::text
    )),
    'pending',
    email_vars
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate funkcja obsługująca ponowne próby wysyłki
CREATE FUNCTION handle_email_retry()
RETURNS TRIGGER AS $$
BEGIN
  -- Zwiększ licznik prób
  NEW.retry_count := COALESCE(OLD.retry_count, 0) + 1;
  
  -- Ustaw następną próbę za 5 minut
  NEW.next_retry_at := CASE
    WHEN NEW.retry_count <= 3 THEN NOW() + interval '5 minutes'
    ELSE NULL
  END;

  -- Aktualizuj status
  IF NEW.retry_count > 3 THEN
    NEW.status := 'failed';
    NEW.error_details := jsonb_build_object(
      'final_error', NEW.last_error,
      'retry_count', NEW.retry_count,
      'last_attempt', NOW()
    );
  ELSE
    NEW.status := 'pending';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate triggers
CREATE TRIGGER send_new_reservation_email
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_reservation_email();

CREATE TRIGGER handle_email_retry_trigger
  BEFORE UPDATE OF status ON email_logs
  FOR EACH ROW
  WHEN (NEW.status = 'failed')
  EXECUTE FUNCTION handle_email_retry();

-- Aktualizacja ustawień SMTP
UPDATE smtp_settings
SET 
  host = '188.210.221.82',
  port = 585,
  username = 'biuro@solrent.pl',
  password = 'arELtGPxndj9KvpsjDtZ',
  from_email = 'biuro@solrent.pl',
  from_name = 'SOLRENT',
  encryption = 'ssl',
  updated_at = NOW()
WHERE id = (SELECT id FROM smtp_settings LIMIT 1);

-- Dodaj indeksy dla optymalizacji zapytań
CREATE INDEX IF NOT EXISTS idx_email_logs_status ON email_logs(status);
CREATE INDEX IF NOT EXISTS idx_email_logs_recipient_status ON email_logs(recipient, status);
CREATE INDEX IF NOT EXISTS idx_email_logs_sent_at ON email_logs(sent_at);