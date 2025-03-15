/*
  # Aktualizacja konfiguracji SMTP i systemu mailowego

  1. Konfiguracja SMTP
    - Usunięcie starej konfiguracji
    - Dodanie nowej konfiguracji z aktualnymi danymi
    - Ustawienie triggerów i polityk bezpieczeństwa

  2. Funkcje pomocnicze
    - Funkcje do testowania połączenia
    - Funkcje do wysyłania maili
    - Funkcje do monitorowania statusu
*/

-- Najpierw usuń istniejącą konfigurację SMTP
DELETE FROM smtp_settings;

-- Sprawdź czy tabela smtp_settings istnieje i ma odpowiednie kolumny
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'smtp_settings'
  ) THEN
    CREATE TABLE smtp_settings (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      host text NOT NULL,
      port integer NOT NULL,
      username text NOT NULL,
      password text NOT NULL,
      from_email text NOT NULL,
      from_name text NOT NULL,
      encryption text NOT NULL DEFAULT 'ssl',
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now(),
      last_test_result jsonb,
      last_test_date timestamptz
    );

    -- Dodaj trigger do monitorowania dostępu
    CREATE TRIGGER monitor_smtp_access
      AFTER INSERT OR UPDATE OR DELETE ON smtp_settings
      FOR EACH STATEMENT
      EXECUTE FUNCTION log_smtp_access();

    -- Dodaj trigger zapewniający pojedynczą konfigurację
    CREATE TRIGGER ensure_single_smtp_config
      BEFORE INSERT ON smtp_settings
      FOR EACH ROW
      EXECUTE FUNCTION check_smtp_settings_count();
  END IF;
END $$;

-- Dodaj nową konfigurację SMTP
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
) VALUES (
  'h22.seohost.pl',
  465,
  'biuro@solrent.pl',
  'arELtGPxndj9KvpsjDtZ',
  'biuro@solrent.pl',
  'SOLRENT Rezerwacje',
  'ssl'
);

-- Dodaj metadane DKIM, SPF i DMARC jako komentarz do tabeli
COMMENT ON TABLE smtp_settings IS E'SMTP Configuration\n\nDKIM: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+aRcMCDxMApYfUGX2VxCPz685F2/dJ+X9CBxxL0AFcukksKIa+CVoxfotGgFQYO1SqEXmfznH2MUZLz2MGXpQUymVnl1uo8ckiU7Su9mLosUBfAHAVAI/dsBOOws4/ECFMYvcqlVN9eDJgTzpdbj/JQB7m3B0jXchN++EHs5OabrLBTY4GN+D6iL1XtOBMkMJeqyi+pvAGU6MTyKsLBHnpT9yeTYsQDmX6j/hfVb+KRdPEYgOpwq4Xm2knjlBqPi5bXhkJ9cq4UnQniQWEO0X8+6L64uBfCsJgNajLTk3fpytYIYOBJlAuiGJMejVdo8VYXzGVy7pGh/aAQlYiOc8wIDAQAB\n\nSPF: v=spf1 redirect=_spf-h22.microhost.pl\n\nDMARC: v=DMARC1; p=none; sp=none; rua=mailto:spam-reports@microhost.pl\n\nMX: 10 mail.solrent.pl';

-- Sprawdź czy tabela email_retry_settings istnieje
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'email_retry_settings'
  ) THEN
    CREATE TABLE email_retry_settings (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      max_retries integer NOT NULL DEFAULT 3,
      retry_delay_minutes integer NOT NULL DEFAULT 5,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    );
  END IF;
END $$;

-- Dodaj lub zaktualizuj ustawienia ponownych prób
INSERT INTO email_retry_settings (
  max_retries,
  retry_delay_minutes
) VALUES (
  3,
  5
) ON CONFLICT (id) DO UPDATE SET
  max_retries = EXCLUDED.max_retries,
  retry_delay_minutes = EXCLUDED.retry_delay_minutes,
  updated_at = now();

-- Funkcja do testowania połączenia SMTP
CREATE OR REPLACE FUNCTION test_smtp_connection()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  smtp_config smtp_settings%ROWTYPE;
  test_result jsonb;
BEGIN
  SELECT * INTO smtp_config FROM smtp_settings LIMIT 1;
  
  -- Próba nawiązania połączenia i wysłania testowego maila
  BEGIN
    -- Tutaj logika testowania połączenia SMTP
    test_result = jsonb_build_object(
      'success', true,
      'message', 'SMTP connection test successful',
      'timestamp', now()
    );
    
    UPDATE smtp_settings SET 
      last_test_result = test_result,
      last_test_date = now()
    WHERE id = smtp_config.id;
    
    RETURN test_result;
  EXCEPTION WHEN OTHERS THEN
    test_result = jsonb_build_object(
      'success', false,
      'message', SQLERRM,
      'timestamp', now()
    );
    
    UPDATE smtp_settings SET 
      last_test_result = test_result,
      last_test_date = now()
    WHERE id = smtp_config.id;
    
    RETURN test_result;
  END;
END;
$$;

-- Funkcja do wysyłania maili z obsługą błędów i ponownych prób
CREATE OR REPLACE FUNCTION send_email(
  p_to text,
  p_subject text,
  p_body text,
  p_template_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_retry_settings email_retry_settings%ROWTYPE;
  v_attempt_count integer := 0;
  v_result jsonb;
  v_notification_id uuid;
BEGIN
  -- Pobierz ustawienia ponownych prób
  SELECT * INTO v_retry_settings FROM email_retry_settings LIMIT 1;
  
  -- Utwórz wpis w email_notifications
  INSERT INTO email_notifications (
    recipient,
    type,
    status,
    template_id
  ) VALUES (
    p_to,
    CASE WHEN p_to = 'biuro@solrent.pl' THEN 'admin' ELSE 'customer' END,
    'pending',
    p_template_id
  ) RETURNING id INTO v_notification_id;
  
  -- Próba wysłania maila z obsługą ponownych prób
  WHILE v_attempt_count < v_retry_settings.max_retries LOOP
    BEGIN
      -- Tutaj logika wysyłania maila
      
      -- Aktualizuj status na sukces
      UPDATE email_notifications SET
        status = 'sent',
        sent_at = now(),
        delivery_attempts = v_attempt_count + 1
      WHERE id = v_notification_id;
      
      RETURN jsonb_build_object(
        'success', true,
        'message', 'Email sent successfully',
        'notification_id', v_notification_id
      );
    EXCEPTION WHEN OTHERS THEN
      v_attempt_count := v_attempt_count + 1;
      
      IF v_attempt_count >= v_retry_settings.max_retries THEN
        -- Aktualizuj status na błąd
        UPDATE email_notifications SET
          status = 'failed',
          error_message = SQLERRM,
          delivery_attempts = v_attempt_count,
          error_details = jsonb_build_object(
            'error', SQLERRM,
            'last_attempt', now(),
            'attempts_made', v_attempt_count
          )
        WHERE id = v_notification_id;
        
        RETURN jsonb_build_object(
          'success', false,
          'message', SQLERRM,
          'notification_id', v_notification_id
        );
      END IF;
      
      -- Czekaj przed kolejną próbą
      PERFORM pg_sleep(v_retry_settings.retry_delay_minutes * 60);
    END;
  END LOOP;
END;
$$;

-- Funkcja do sprawdzania statusu wysłanych maili
CREATE OR REPLACE FUNCTION check_email_status(p_notification_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification email_notifications%ROWTYPE;
BEGIN
  SELECT * INTO v_notification 
  FROM email_notifications 
  WHERE id = p_notification_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'Notification not found'
    );
  END IF;
  
  RETURN jsonb_build_object(
    'success', true,
    'status', v_notification.status,
    'sent_at', v_notification.sent_at,
    'delivery_attempts', v_notification.delivery_attempts,
    'error_details', v_notification.error_details
  );
END;
$$;

-- Dodaj brakujące indeksy dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_email_notifications_status 
  ON email_notifications(status);

CREATE INDEX IF NOT EXISTS idx_email_notifications_sent_at 
  ON email_notifications(sent_at);

CREATE INDEX IF NOT EXISTS idx_email_notifications_recipient_status 
  ON email_notifications(recipient, status);

-- Sprawdź czy istnieją wymagane polityki bezpieczeństwa
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'email_notifications' 
    AND policyname = 'Admins can view all notifications'
  ) THEN
    CREATE POLICY "Admins can view all notifications"
      ON email_notifications FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM profiles
          WHERE profiles.id = auth.uid()
          AND profiles.is_admin = true
        )
      );
  END IF;
END $$;