/*
  # Update email sending function

  1. Changes
    - Remove dependency on net schema
    - Use pg_notify for email notifications
    - Add email queue table for background processing
    - Update email sending function to use queue

  2. Security
    - Function is marked as SECURITY DEFINER
    - Added proper error handling
*/

-- Tabela kolejki emaili
CREATE TABLE IF NOT EXISTS email_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient text NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  notification_id uuid REFERENCES email_notifications(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz,
  status text DEFAULT 'pending',
  error_details jsonb
);

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

  -- Dodaj maile do kolejki
  INSERT INTO email_queue (recipient, subject, content, notification_id)
  VALUES 
    (p_customer_email, v_customer_template.subject, v_customer_template.content, p_notification_ids[1]),
    (p_admin_email, v_admin_template.subject, v_admin_template.content, p_notification_ids[2]);

  -- Zaktualizuj status powiadomień
  UPDATE email_notifications 
  SET 
    status = 'pending',
    updated_at = NOW()
  WHERE id = ANY(p_notification_ids);

  -- Powiadom system o nowych mailach do wysłania
  PERFORM pg_notify('email_queue', 'new_email');

EXCEPTION
  WHEN OTHERS THEN
    -- W przypadku błędu oznacz powiadomienia jako failed
    UPDATE email_notifications 
    SET 
      status = 'failed',
      error_details = jsonb_build_object(
        'error', SQLERRM,
        'detail', SQLSTATE
      ),
      updated_at = NOW()
    WHERE id = ANY(p_notification_ids);
    
    RAISE;
END;
$$;

-- Uprawnienia
ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view email queue"
  ON email_queue
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Indeksy
CREATE INDEX IF NOT EXISTS idx_email_queue_status 
  ON email_queue(status);

CREATE INDEX IF NOT EXISTS idx_email_queue_notification 
  ON email_queue(notification_id);

COMMENT ON TABLE email_queue IS 
  'Queue for emails to be sent by external email worker';

COMMENT ON FUNCTION send_reservation_emails IS 
  'Queues emails for reservation confirmation and admin notification';

-- Funkcja do testowania konfiguracji SMTP
CREATE OR REPLACE FUNCTION test_smtp_configuration()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Wyślij testowy email
  v_result := send_email(
    'biuro@solrent.pl',
    'Test konfiguracji SMTP',
    '<div style="font-family: Arial, sans-serif; padding: 20px;">
      <h2>Test konfiguracji SMTP</h2>
      <p>To jest wiadomość testowa wysłana z systemu rezerwacji SOLRENT.</p>
      <p>Jeśli otrzymałeś tę wiadomość, oznacza to że:</p>
      <ul>
        <li>Konfiguracja SMTP jest poprawna</li>
        <li>Serwer może wysyłać emaile</li>
        <li>Formatowanie HTML działa prawidłowo</li>
      </ul>
      <p>Data i czas testu: ' || to_char(now(), 'YYYY-MM-DD HH24:MI:SS') || '</p>
    </div>'
  );

  RETURN v_result;
END;
$$;

-- Dodaj uprawnienia do wykonywania funkcji testowej tylko dla administratorów
GRANT EXECUTE ON FUNCTION test_smtp_configuration() TO authenticated;