/*
  # Update email system

  1. Changes
    - Remove dependency on Edge Functions for email templates
    - Add direct email sending using PostgreSQL functions
    - Update email notifications table structure
    - Add new email sending function

  2. Security
    - Function is marked as SECURITY DEFINER to allow proper email sending
*/

-- Dodaj kolumny do tabeli email_notifications
ALTER TABLE email_notifications 
ADD COLUMN IF NOT EXISTS error_details jsonb,
ADD COLUMN IF NOT EXISTS smtp_response text;

-- Funkcja do wysyłania maili dla rezerwacji
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
  v_customer_template email_templates%ROWTYPE;
  v_admin_template email_templates%ROWTYPE;
  v_smtp_settings smtp_settings%ROWTYPE;
  v_result jsonb;
BEGIN
  -- Pobierz szablony
  SELECT * INTO v_customer_template 
  FROM email_templates 
  WHERE name = 'reservation_confirmation';
  
  SELECT * INTO v_admin_template 
  FROM email_templates 
  WHERE name = 'admin_notification';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Email templates not found';
  END IF;

  -- Pobierz ustawienia SMTP
  SELECT * INTO v_smtp_settings
  FROM smtp_settings
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SMTP settings not found';
  END IF;

  -- Wyślij mail do klienta
  PERFORM net.mail_send(
    sender := v_smtp_settings.from_email,
    recipient := p_customer_email,
    subject := v_customer_template.subject,
    body := v_customer_template.content,
    html := true
  );

  -- Zaktualizuj status powiadomienia dla klienta
  UPDATE email_notifications 
  SET 
    status = 'sent',
    sent_at = NOW()
  WHERE id = p_notification_ids[1];

  -- Wyślij mail do admina
  PERFORM net.mail_send(
    sender := v_smtp_settings.from_email,
    recipient := p_admin_email,
    subject := v_admin_template.subject,
    body := v_admin_template.content,
    html := true
  );

  -- Zaktualizuj status powiadomienia dla admina
  UPDATE email_notifications 
  SET 
    status = 'sent',
    sent_at = NOW()
  WHERE id = p_notification_ids[2];

EXCEPTION
  WHEN OTHERS THEN
    -- W przypadku błędu oznacz oba powiadomienia jako failed
    UPDATE email_notifications 
    SET 
      status = 'failed',
      error_details = jsonb_build_object(
        'error', SQLERRM,
        'detail', SQLSTATE
      ),
      sent_at = NOW()
    WHERE id = ANY(p_notification_ids);
    
    RAISE;
END;
$$;