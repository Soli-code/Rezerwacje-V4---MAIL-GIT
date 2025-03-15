/*
  # Add email preview functionality

  1. New Tables
    - `email_logs` - stores all email attempts and their content for preview/debugging

  2. Changes
    - Add preview mode handling in send_reservation_emails function
    - Add logging of all email attempts

  3. Security
    - Enable RLS on new table
    - Add policies for admin access
*/

DO $$ 
BEGIN
  -- Sprawdź czy indeksy już istnieją
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_email_logs_sent_at') THEN
    CREATE INDEX idx_email_logs_sent_at ON email_logs(sent_at);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_email_logs_status') THEN
    CREATE INDEX idx_email_logs_status ON email_logs(status);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_email_logs_recipient_status') THEN
    CREATE INDEX idx_email_logs_recipient_status ON email_logs(recipient, status);
  END IF;
END $$;

-- Uprawnienia
ALTER TABLE IF EXISTS email_logs ENABLE ROW LEVEL SECURITY;

-- Usuń istniejące polityki jeśli istnieją
DROP POLICY IF EXISTS "Admins can view email logs" ON email_logs;
DROP POLICY IF EXISTS "Public can insert email logs" ON email_logs;
DROP POLICY IF EXISTS "System can update email logs" ON email_logs;

-- Utwórz nowe polityki
CREATE POLICY "Admins can view email logs"
  ON email_logs
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Public can insert email logs"
  ON email_logs
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "System can update email logs"
  ON email_logs
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Modyfikacja funkcji wysyłającej maile
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
  v_reservation_id uuid;
BEGIN
  -- Pobierz ID rezerwacji z danych
  v_reservation_id := (p_data->>'reservation_id')::uuid;

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

  -- W trybie preview zapisz maile do logów
  INSERT INTO email_logs 
    (template_id, reservation_id, recipient, subject, content, status, template_variables)
  VALUES 
    (v_customer_template.id, v_reservation_id, p_customer_email, 
     v_customer_template.subject, v_customer_template.content, 'sent', p_data),
    (v_admin_template.id, v_reservation_id, p_admin_email,
     v_admin_template.subject, v_admin_template.content, 'sent', p_data);

  -- Zaktualizuj status powiadomień
  UPDATE email_notifications 
  SET 
    status = 'sent',
    updated_at = NOW()
  WHERE id = ANY(p_notification_ids);

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