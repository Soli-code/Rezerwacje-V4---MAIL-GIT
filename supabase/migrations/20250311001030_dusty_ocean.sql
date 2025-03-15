/*
  # System obsługi maili

  1. Nowe Tabele
    - `email_templates` - szablony wiadomości email
    - `email_logs` - logi wysłanych maili
    - `email_notifications` - kolejka powiadomień email
    - `smtp_settings` - konfiguracja SMTP
    
  2. Funkcje
    - `send_reservation_emails` - funkcja do wysyłania maili rezerwacji
    
  3. Bezpieczeństwo
    - Włączone RLS dla wszystkich tabel
    - Polityki dostępu dla administratorów i systemu
*/

-- Usuń istniejące polityki
DO $$ 
BEGIN
  -- Usuń polityki dla email_templates
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'email_templates'
  ) THEN
    DROP POLICY IF EXISTS "Admins can manage email templates" ON email_templates;
  END IF;

  -- Usuń polityki dla email_logs
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'email_logs'
  ) THEN
    DROP POLICY IF EXISTS "Admins can view email logs" ON email_logs;
    DROP POLICY IF EXISTS "Public can insert email logs" ON email_logs;
    DROP POLICY IF EXISTS "System can update email logs" ON email_logs;
  END IF;

  -- Usuń polityki dla email_notifications
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'email_notifications'
  ) THEN
    DROP POLICY IF EXISTS "Admins can view all notifications" ON email_notifications;
    DROP POLICY IF EXISTS "Public can view basic notification info" ON email_notifications;
    DROP POLICY IF EXISTS "Public can insert email logs" ON email_notifications;
    DROP POLICY IF EXISTS "Public can update email logs" ON email_notifications;
  END IF;

  -- Usuń polityki dla smtp_settings
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'smtp_settings'
  ) THEN
    DROP POLICY IF EXISTS "Admins can manage SMTP settings" ON smtp_settings;
  END IF;
END $$;

-- Usuń istniejące indeksy
DROP INDEX IF EXISTS idx_email_logs_sent_at;
DROP INDEX IF EXISTS idx_email_logs_status;
DROP INDEX IF EXISTS idx_email_logs_recipient_status;
DROP INDEX IF EXISTS idx_email_notifications_sent_at;
DROP INDEX IF EXISTS idx_email_notifications_status;
DROP INDEX IF EXISTS idx_email_notifications_recipient_status;
DROP INDEX IF EXISTS idx_email_notifications_delivery_time;

-- Usuń istniejące funkcje
DROP FUNCTION IF EXISTS send_reservation_emails(text, text, jsonb, uuid[]);

-- Tabela szablonów email
CREATE TABLE IF NOT EXISTS email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  subject text NOT NULL,
  content text NOT NULL,
  variables jsonb DEFAULT '{}'::jsonb,
  active boolean DEFAULT true,
  version integer DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage email templates"
  ON email_templates
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Tabela logów email
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id),
  reservation_id uuid REFERENCES reservations(id),
  recipient text NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'sent', 'failed', 'delivered', 'bounced')),
  error_message text,
  sent_at timestamptz DEFAULT now(),
  smtp_response text,
  retry_count integer DEFAULT 0,
  next_retry_at timestamptz,
  delivery_attempts integer DEFAULT 0,
  last_error text,
  headers jsonb,
  delivered_at timestamptz,
  template_variables jsonb,
  error_details jsonb,
  metadata jsonb
);

CREATE INDEX idx_email_logs_sent_at ON email_logs(sent_at);
CREATE INDEX idx_email_logs_status ON email_logs(status);
CREATE INDEX idx_email_logs_recipient_status ON email_logs(recipient, status);

ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

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

-- Tabela powiadomień email
CREATE TABLE IF NOT EXISTS email_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  recipient text NOT NULL,
  type text NOT NULL CHECK (type IN ('customer', 'admin')),
  status text NOT NULL CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'bounced')),
  error text,
  sent_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  message_id text,
  delivery_attempts integer DEFAULT 0,
  last_attempt_at timestamptz,
  bounce_info jsonb,
  updated_at timestamptz DEFAULT now(),
  priority text DEFAULT 'normal' CHECK (priority IN ('high', 'normal', 'low')),
  delivery_time interval,
  retry_count integer DEFAULT 0,
  headers jsonb,
  metrics jsonb,
  error_message text,
  error_details jsonb,
  smtp_response text
);

CREATE INDEX idx_email_notifications_sent_at ON email_notifications(sent_at);
CREATE INDEX idx_email_notifications_status ON email_notifications(status);
CREATE INDEX idx_email_notifications_recipient_status ON email_notifications(recipient, status);
CREATE INDEX idx_email_notifications_delivery_time ON email_notifications(delivery_time) WHERE delivery_time IS NOT NULL;

ALTER TABLE email_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view all notifications"
  ON email_notifications
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Public can view basic notification info"
  ON email_notifications
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Public can insert email logs"
  ON email_notifications
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Public can update email logs"
  ON email_notifications
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

-- Tabela ustawień SMTP
CREATE TABLE IF NOT EXISTS smtp_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host text NOT NULL,
  port integer NOT NULL,
  username text NOT NULL,
  password text NOT NULL,
  from_email text NOT NULL,
  from_name text NOT NULL,
  encryption text NOT NULL DEFAULT 'tls',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_test_result jsonb,
  last_test_date timestamptz
);

ALTER TABLE smtp_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage SMTP settings"
  ON smtp_settings
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Funkcja do wysyłania maili
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
  WHERE name = 'reservation_confirmation'
  AND active = true
  ORDER BY version DESC
  LIMIT 1;
  
  SELECT * INTO v_admin_template 
  FROM email_templates 
  WHERE name = 'admin_notification'
  AND active = true
  ORDER BY version DESC
  LIMIT 1;

  IF v_customer_template.id IS NULL OR v_admin_template.id IS NULL THEN
    RAISE EXCEPTION 'Required email templates not found';
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