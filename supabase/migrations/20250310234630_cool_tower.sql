/*
  # Poprawka operatorów JSON w funkcjach email

  1. Zmiany
    - Dodanie jawnego rzutowania typów dla operatorów JSON
    - Poprawa obsługi typów w funkcjach email
    
  2. Bezpieczeństwo
    - Funkcje działają w kontekście security definer
    - Dostęp tylko dla authenticated użytkowników
*/

-- Usuń istniejące funkcje
DROP FUNCTION IF EXISTS get_email_template(text, jsonb);
DROP FUNCTION IF EXISTS format_reservation_email(jsonb, boolean);
DROP FUNCTION IF EXISTS send_reservation_emails(text, text, jsonb, uuid[]);

-- Funkcja do pobierania i formatowania szablonu maila
CREATE OR REPLACE FUNCTION get_email_template(
  p_template_name text,
  p_variables jsonb
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template email_templates%ROWTYPE;
  v_content text;
  v_key text;
  v_value text;
BEGIN
  -- Pobierz aktywny szablon
  SELECT * INTO v_template
  FROM email_templates
  WHERE name = p_template_name
  AND active = true
  ORDER BY version DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template % not found', p_template_name;
  END IF;

  -- Użyj treści szablonu
  v_content := v_template.content;

  -- Zastąp zmienne w szablonie
  FOR v_key, v_value IN
    SELECT * FROM jsonb_each_text(p_variables)
  LOOP
    v_content := replace(v_content, '{{' || v_key || '}}', v_value);
  END LOOP;

  RETURN v_content;
END;
$$;

-- Funkcja do formatowania maila rezerwacji
CREATE OR REPLACE FUNCTION format_reservation_email(
  p_data jsonb,
  p_is_admin boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_template_name text;
  v_variables jsonb;
  v_subject text;
  v_content text;
BEGIN
  -- Wybierz odpowiedni szablon
  v_template_name := CASE 
    WHEN p_is_admin THEN 'admin_reservation'
    ELSE 'customer_reservation'
  END;

  -- Przygotuj zmienne dla szablonu
  v_variables := jsonb_build_object(
    'first_name', (p_data->>'firstName')::text,
    'last_name', (p_data->>'lastName')::text,
    'email', (p_data->>'email')::text,
    'phone', (p_data->>'phone')::text,
    'start_date', (p_data->>'startDate')::text,
    'end_date', (p_data->>'endDate')::text,
    'start_time', (p_data->>'startTime')::text,
    'end_time', (p_data->>'endTime')::text,
    'days', (p_data->>'days')::text,
    'total_price', (p_data->>'totalPrice')::text,
    'deposit', (p_data->>'deposit')::text,
    'equipment', p_data->'equipment'
  );

  -- Dodaj dane firmy jeśli są
  IF (p_data->>'companyName')::text IS NOT NULL THEN
    v_variables := v_variables || jsonb_build_object(
      'company_name', (p_data->>'companyName')::text,
      'company_nip', (p_data->>'companyNip')::text,
      'company_address', (p_data->>'companyStreet')::text || ', ' || 
                        (p_data->>'companyPostalCode')::text || ' ' || 
                        (p_data->>'companyCity')::text
    );
  END IF;

  -- Pobierz i sformatuj treść
  SELECT 
    t.subject,
    get_email_template(v_template_name, v_variables)
  INTO v_subject, v_content
  FROM email_templates t
  WHERE t.name = v_template_name
  AND t.active = true
  ORDER BY t.version DESC
  LIMIT 1;

  RETURN jsonb_build_object(
    'subject', v_subject,
    'content', v_content
  );
END;
$$;

-- Główna funkcja do wysyłania maili rezerwacji
CREATE OR REPLACE FUNCTION send_reservation_emails(
  p_customer_email text,
  p_admin_email text,
  p_data jsonb,
  p_notification_ids uuid[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_customer_email jsonb;
  v_admin_email jsonb;
  v_customer_result jsonb;
  v_admin_result jsonb;
  v_smtp_settings smtp_settings%ROWTYPE;
BEGIN
  -- Pobierz konfigurację SMTP
  SELECT * INTO v_smtp_settings FROM smtp_settings LIMIT 1;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SMTP configuration not found';
  END IF;

  -- Przygotuj treść maili
  v_customer_email := format_reservation_email(p_data, false);
  v_admin_email := format_reservation_email(p_data, true);

  -- Wyślij mail do klienta
  v_customer_result := send_email(
    p_customer_email,
    (v_customer_email->>'subject')::text,
    (v_customer_email->>'content')::text
  );

  -- Wyślij mail do admina
  v_admin_result := send_email(
    p_admin_email,
    (v_admin_email->>'subject')::text,
    (v_admin_email->>'content')::text
  );

  -- Zwróć wyniki
  RETURN jsonb_build_object(
    'customer_email', v_customer_result,
    'admin_email', v_admin_result
  );
END;
$$;