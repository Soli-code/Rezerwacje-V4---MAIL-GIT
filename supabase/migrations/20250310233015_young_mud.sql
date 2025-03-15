/*
  # Add email sending function

  1. Changes
    - Add function for sending reservation emails
    - Function handles both customer and admin notifications
    - Uses built-in Supabase email functionality
*/

-- Funkcja do wysyłania maili z rezerwacją
CREATE OR REPLACE FUNCTION send_reservation_emails(
  p_customer_email text,
  p_admin_email text,
  p_data jsonb,
  p_notification_ids uuid[]
)
RETURNS void AS $$
DECLARE
  v_template email_templates%ROWTYPE;
  v_customer_content text;
  v_admin_content text;
BEGIN
  -- Pobierz szablon emaila
  SELECT * INTO v_template
  FROM email_templates
  WHERE name = 'new_reservation'
  LIMIT 1;

  -- Przygotuj treść maila dla klienta
  v_customer_content := v_template.content;
  v_customer_content := replace(v_customer_content, '{{first_name}}', p_data->>'firstName');
  v_customer_content := replace(v_customer_content, '{{last_name}}', p_data->>'lastName');
  v_customer_content := replace(v_customer_content, '{{start_date}}', p_data->>'startDate');
  v_customer_content := replace(v_customer_content, '{{end_date}}', p_data->>'endDate');
  v_customer_content := replace(v_customer_content, '{{start_time}}', p_data->>'startTime');
  v_customer_content := replace(v_customer_content, '{{end_time}}', p_data->>'endTime');
  v_customer_content := replace(v_customer_content, '{{total_price}}', p_data->>'totalPrice');
  v_customer_content := replace(v_customer_content, '{{deposit_amount}}', p_data->>'deposit');
  v_customer_content := replace(v_customer_content, '{{equipment_list}}', p_data->>'equipment');

  -- Wyślij maila do klienta
  PERFORM extensions.http((
    'POST',
    current_setting('app.settings.emails_endpoint', true),
    ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true))],
    jsonb_build_object(
      'to', p_customer_email,
      'subject', v_template.subject,
      'html', v_customer_content,
      'headers', jsonb_build_object(
        'X-Template-Name', 'new_reservation',
        'X-Notification-Id', p_notification_ids[1]
      )
    ),
    10
  ));

  -- Przygotuj treść maila dla admina
  v_admin_content := 'Nowa rezerwacja:' || E'\n\n' ||
    'Klient: ' || p_data->>'firstName' || ' ' || p_data->>'lastName' || E'\n' ||
    'Email: ' || p_data->>'email' || E'\n' ||
    'Telefon: ' || p_data->>'phone' || E'\n\n' ||
    'Data rozpoczęcia: ' || p_data->>'startDate' || ' ' || p_data->>'startTime' || E'\n' ||
    'Data zakończenia: ' || p_data->>'endDate' || ' ' || p_data->>'endTime' || E'\n' ||
    'Sprzęt: ' || p_data->>'equipment' || E'\n' ||
    'Całkowity koszt: ' || p_data->>'totalPrice' || ' zł' || E'\n' ||
    'Kaucja: ' || p_data->>'deposit' || ' zł';

  -- Dodaj dane firmy jeśli są
  IF p_data->>'companyName' IS NOT NULL THEN
    v_admin_content := v_admin_content || E'\n\nDane firmy:' || E'\n' ||
      'Nazwa: ' || p_data->>'companyName' || E'\n' ||
      'NIP: ' || p_data->>'companyNip' || E'\n' ||
      'Adres: ' || p_data->>'companyStreet' || ', ' ||
      p_data->>'companyPostalCode' || ' ' || p_data->>'companyCity';
  END IF;

  -- Dodaj komentarz jeśli jest
  IF p_data->>'comment' IS NOT NULL THEN
    v_admin_content := v_admin_content || E'\n\nKomentarz: ' || p_data->>'comment';
  END IF;

  -- Wyślij maila do admina
  PERFORM extensions.http((
    'POST',
    current_setting('app.settings.emails_endpoint', true),
    ARRAY[http_header('Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true))],
    jsonb_build_object(
      'to', p_admin_email,
      'subject', 'Nowa rezerwacja - ' || p_data->>'firstName' || ' ' || p_data->>'lastName',
      'text', v_admin_content,
      'headers', jsonb_build_object(
        'X-Template-Name', 'new_reservation_admin',
        'X-Notification-Id', p_notification_ids[2]
      )
    ),
    10
  ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;