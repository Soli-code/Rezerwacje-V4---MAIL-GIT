/*
  # Naprawa szablonów email i logów

  1. Zmiany
    - Dodanie domyślnych wartości dla kolumn w email_logs
    - Usunięcie i ponowne utworzenie funkcji format_email_content
    - Aktualizacja funkcji obsługującej emaile
    
  2. Bezpieczeństwo
    - Zachowanie istniejących polityk RLS
*/

-- Upewnij się, że kolumny w email_logs mają domyślne wartości
ALTER TABLE email_logs 
ALTER COLUMN subject SET DEFAULT '',
ALTER COLUMN subject SET NOT NULL,
ALTER COLUMN body SET DEFAULT '',
ALTER COLUMN body SET NOT NULL;

-- Najpierw usuń istniejącą funkcję
DROP FUNCTION IF EXISTS format_email_content(jsonb, jsonb);

-- Utwórz funkcję z nowymi nazwami parametrów
CREATE OR REPLACE FUNCTION format_email_content(
  template_data jsonb,
  template_vars jsonb
) RETURNS text AS $$
DECLARE
  formatted_content text := '';
  section record;
  content_line text;
  key_value record;
BEGIN
  -- Dodaj tytuł
  formatted_content := template_data->>'title' || E'\n\n';
  
  -- Przetwórz każdą sekcję
  FOR section IN SELECT * FROM jsonb_array_elements(template_data->'sections')
  LOOP
    -- Dodaj nagłówek sekcji
    IF section.value->>'heading' IS NOT NULL THEN
      formatted_content := formatted_content || section.value->>'heading' || E'\n';
    END IF;
    
    -- Przetwórz zawartość sekcji
    FOR content_line IN SELECT * FROM jsonb_array_elements_text(section.value->'content')
    LOOP
      -- Zastąp zmienne w linii
      FOR key_value IN SELECT * FROM jsonb_each_text(template_vars)
      LOOP
        content_line := replace(
          content_line,
          '{{' || key_value.key || '}}',
          COALESCE(key_value.value, '')
        );
      END LOOP;
      
      formatted_content := formatted_content || content_line || E'\n';
    END LOOP;
    
    formatted_content := formatted_content || E'\n';
  END LOOP;
  
  RETURN formatted_content;
END;
$$ LANGUAGE plpgsql;

-- Dodaj domyślny szablon email
INSERT INTO email_templates (
  name,
  subject,
  body
) VALUES (
  'reservation_confirmation',
  'Potwierdzenie rezerwacji SOLRENT',
  jsonb_build_object(
    'title', 'Dziękujemy za dokonanie rezerwacji w SOLRENT!',
    'sections', jsonb_build_array(
      jsonb_build_object(
        'heading', 'Szczegóły rezerwacji',
        'content', jsonb_build_array(
          'Data rozpoczęcia: {{start_date}} {{start_time}}',
          'Data zakończenia: {{end_date}} {{end_time}}',
          'Zarezerwowany sprzęt:',
          '{{equipment_details}}'
        )
      ),
      jsonb_build_object(
        'heading', 'Koszty',
        'content', jsonb_build_array(
          'Całkowity koszt: {{total_price}} zł',
          'Kaucja: {{deposit_amount}} zł'
        )
      ),
      jsonb_build_object(
        'heading', 'Dane kontaktowe',
        'content', jsonb_build_array(
          '{{customer_name}}',
          'Tel: {{customer_phone}}',
          'Email: {{customer_email}}',
          '{{comment}}'
        )
      ),
      jsonb_build_object(
        'heading', 'Pozdrowienia',
        'content', jsonb_build_array(
          'Z poważaniem,',
          'Zespół SOLRENT'
        )
      )
    )
  )
)
ON CONFLICT (name) 
DO UPDATE SET 
  subject = EXCLUDED.subject,
  body = EXCLUDED.body,
  updated_at = now();

-- Aktualizuj trigger do obsługi emaili
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_customer record;
  v_equipment_details text;
  v_template record;
  v_variables jsonb;
  v_formatted_body text;
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

  IF v_template IS NULL THEN
    RAISE EXCEPTION 'Email template not found';
  END IF;

  -- Przygotuj zmienne
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

  -- Sformatuj treść
  v_formatted_body := format_email_content(v_template.body, v_variables);

  -- Email dla klienta
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
    v_formatted_body,
    'pending',
    v_variables
  );

  -- Email dla biura
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
    v_formatted_body,
    'pending',
    v_variables
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;