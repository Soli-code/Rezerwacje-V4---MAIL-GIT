/*
  # Setup email templates and functions

  1. New Tables
    - `email_templates` - przechowuje szablony emaili
    - `email_template_variables` - przechowuje zmienne używane w szablonach

  2. Functions
    - `get_email_template` - pobiera i formatuje szablon emaila
    - `format_reservation_email` - formatuje email dla rezerwacji
    - `send_reservation_emails` - wysyła emaile do klienta i admina

  3. Data
    - Domyślne szablony dla klienta i admina
*/

-- Dodaj domyślne szablony emaili
INSERT INTO email_templates (name, subject, content, variables, active, version)
VALUES
(
  'customer_reservation',
  'Potwierdzenie rezerwacji sprzętu - SOLRENT',
  E'Szanowny/a {{first_name}} {{last_name}},\n\n' ||
  E'Dziękujemy za dokonanie rezerwacji w SOLRENT. Poniżej znajdują się szczegóły Twojej rezerwacji:\n\n' ||
  E'Data rozpoczęcia: {{start_date}} {{start_time}}\n' ||
  E'Data zakończenia: {{end_date}} {{end_time}}\n' ||
  E'Liczba dni: {{days}}\n\n' ||
  E'Wybrany sprzęt:\n{{equipment}}\n\n' ||
  E'Całkowity koszt wypożyczenia: {{total_price}} zł\n' ||
  E'Wymagana kaucja: {{deposit}} zł\n\n' ||
  E'Prosimy o przygotowanie:\n' ||
  E'- Dokumentu tożsamości\n' ||
  E'- Kaucji w wysokości {{deposit}} zł\n\n' ||
  E'Przypominamy o godzinach otwarcia:\n' ||
  E'Poniedziałek - Piątek: 8:00 - 16:00\n' ||
  E'Sobota: 8:00 - 13:00\n' ||
  E'Niedziela: nieczynne\n\n' ||
  E'W razie pytań prosimy o kontakt:\n' ||
  E'Tel: 694 171 171\n' ||
  E'Email: biuro@solrent.pl\n\n' ||
  E'Pozdrawiamy,\nZespół SOLRENT',
  '{"first_name": "Imię klienta", "last_name": "Nazwisko klienta", "start_date": "Data rozpoczęcia", "end_date": "Data zakończenia", "start_time": "Godzina rozpoczęcia", "end_time": "Godzina zakończenia", "days": "Liczba dni", "equipment": "Lista sprzętu", "total_price": "Całkowita cena", "deposit": "Kaucja"}',
  true,
  1
),
(
  'admin_reservation',
  'Nowa rezerwacja sprzętu',
  E'Nowa rezerwacja sprzętu\n\n' ||
  E'Dane klienta:\n' ||
  E'Imię i nazwisko: {{first_name}} {{last_name}}\n' ||
  E'Email: {{email}}\n' ||
  E'Telefon: {{phone}}\n\n' ||
  CASE WHEN '{{company_name}}' IS NOT NULL THEN
    E'Dane firmy:\n' ||
    E'Nazwa: {{company_name}}\n' ||
    E'NIP: {{company_nip}}\n' ||
    E'Adres: {{company_address}}\n\n'
  ELSE '' END ||
  E'Szczegóły rezerwacji:\n' ||
  E'Data rozpoczęcia: {{start_date}} {{start_time}}\n' ||
  E'Data zakończenia: {{end_date}} {{end_time}}\n' ||
  E'Liczba dni: {{days}}\n\n' ||
  E'Wybrany sprzęt:\n{{equipment}}\n\n' ||
  E'Całkowity koszt wypożyczenia: {{total_price}} zł\n' ||
  E'Wymagana kaucja: {{deposit}} zł\n\n' ||
  CASE WHEN '{{comment}}' IS NOT NULL THEN
    E'Komentarz klienta:\n{{comment}}\n\n'
  ELSE '' END,
  '{"first_name": "Imię klienta", "last_name": "Nazwisko klienta", "email": "Email klienta", "phone": "Telefon klienta", "start_date": "Data rozpoczęcia", "end_date": "Data zakończenia", "start_time": "Godzina rozpoczęcia", "end_time": "Godzina zakończenia", "days": "Liczba dni", "equipment": "Lista sprzętu", "total_price": "Całkowita cena", "deposit": "Kaucja", "company_name": "Nazwa firmy", "company_nip": "NIP firmy", "company_address": "Adres firmy", "comment": "Komentarz"}',
  true,
  1
);

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
    v_content := replace(v_content, '{{' || v_key || '}}', COALESCE(v_value, ''));
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
  v_equipment_list text;
BEGIN
  -- Wybierz odpowiedni szablon
  v_template_name := CASE 
    WHEN p_is_admin THEN 'admin_reservation'
    ELSE 'customer_reservation'
  END;

  -- Przygotuj listę sprzętu
  SELECT string_agg(
    item->>'name' || ' (x' || (item->>'quantity')::text || ') - ' || 
    (item->>'price')::text || ' zł/dzień',
    E'\n'
  )
  INTO v_equipment_list
  FROM jsonb_array_elements(p_data->'equipment') AS item;

  -- Przygotuj zmienne dla szablonu
  v_variables := jsonb_build_object(
    'first_name', p_data->>'firstName',
    'last_name', p_data->>'lastName',
    'email', p_data->>'email',
    'phone', p_data->>'phone',
    'start_date', p_data->>'startDate',
    'end_date', p_data->>'endDate',
    'start_time', p_data->>'startTime',
    'end_time', p_data->>'endTime',
    'days', p_data->>'days',
    'total_price', p_data->>'totalPrice',
    'deposit', p_data->>'deposit',
    'equipment', v_equipment_list,
    'comment', p_data->>'comment'
  );

  -- Dodaj dane firmy jeśli są
  IF p_data->>'companyName' IS NOT NULL THEN
    v_variables := v_variables || jsonb_build_object(
      'company_name', p_data->>'companyName',
      'company_nip', p_data->>'companyNip',
      'company_address', p_data->>'companyStreet' || ', ' || 
                        p_data->>'companyPostalCode' || ' ' || 
                        p_data->>'companyCity'
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
    v_customer_email->>'subject',
    v_customer_email->>'content'
  );

  -- Wyślij mail do admina
  v_admin_result := send_email(
    p_admin_email,
    v_admin_email->>'subject',
    v_admin_email->>'content'
  );

  -- Zwróć wyniki
  RETURN jsonb_build_object(
    'customer_email', v_customer_result,
    'admin_email', v_admin_result
  );
END;
$$;