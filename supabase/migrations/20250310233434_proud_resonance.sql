/*
  # Add Email Handling Functions

  1. Changes
    - Add http_header function for email headers
    - Add send_reservation_emails function
    
  2. Security
    - Functions are accessible to public
*/

-- Funkcja pomocnicza do tworzenia nagłówków HTTP
CREATE OR REPLACE FUNCTION http_header(
  "field" text,
  "val" text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT field || ': ' || val;
$$;

-- Funkcja do wysyłania emaili z rezerwacją
CREATE OR REPLACE FUNCTION send_reservation_emails(
  p_customer_email text,
  p_admin_email text,
  p_data jsonb,
  p_notification_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_smtp_settings smtp_settings%ROWTYPE;
  v_customer_template email_templates%ROWTYPE;
  v_admin_template email_templates%ROWTYPE;
  v_headers text[];
  v_customer_content text;
  v_admin_content text;
BEGIN
  -- Pobierz ustawienia SMTP
  SELECT * INTO v_smtp_settings FROM smtp_settings LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SMTP settings not configured';
  END IF;

  -- Ustaw nagłówki
  v_headers := ARRAY[
    http_header('Content-Type', 'text/html; charset=utf-8'),
    http_header('From', format('%s <%s>', v_smtp_settings.from_name, v_smtp_settings.from_email))
  ];

  -- Wyślij email do klienta
  SELECT * INTO v_customer_template 
  FROM email_templates 
  WHERE name = 'reservation_confirmation' 
  AND active = true 
  ORDER BY version DESC 
  LIMIT 1;

  IF FOUND THEN
    -- Tutaj możesz dodać logikę formatowania treści emaila
    v_customer_content := v_customer_template.content;
    
    PERFORM net.http_post(
      url := format('smtp://%s:%s', v_smtp_settings.host, v_smtp_settings.port),
      headers := v_headers,
      body := v_customer_content
    );
  END IF;

  -- Wyślij email do admina
  SELECT * INTO v_admin_template 
  FROM email_templates 
  WHERE name = 'admin_notification' 
  AND active = true 
  ORDER BY version DESC 
  LIMIT 1;

  IF FOUND THEN
    -- Tutaj możesz dodać logikę formatowania treści emaila dla admina
    v_admin_content := v_admin_template.content;
    
    PERFORM net.http_post(
      url := format('smtp://%s:%s', v_smtp_settings.host, v_smtp_settings.port),
      headers := v_headers,
      body := v_admin_content
    );
  END IF;

  -- Aktualizuj status powiadomień
  UPDATE email_notifications 
  SET 
    status = 'sent',
    sent_at = now(),
    headers = to_jsonb(v_headers)
  WHERE id = ANY(p_notification_ids);

EXCEPTION WHEN OTHERS THEN
  -- W przypadku błędu, zaktualizuj status powiadomień
  UPDATE email_notifications 
  SET 
    status = 'failed',
    error_message = SQLERRM,
    error_details = jsonb_build_object(
      'sqlstate', SQLSTATE,
      'message', SQLERRM,
      'context', context
    ),
    retry_count = retry_count + 1
  WHERE id = ANY(p_notification_ids);
  
  RAISE;
END;
$$;