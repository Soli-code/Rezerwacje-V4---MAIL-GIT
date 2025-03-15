/*
  # Configure SMTP Settings

  1. Changes
    - Add SMTP configuration
    - Set up email templates
    - Configure security policies
    
  2. Security
    - Add policies for admin access
*/

-- Dodaj konfigurację SMTP
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
) VALUES (
  '188.210.221.82',
  587,
  'biuro@solrent.pl',
  'arELtGPxndj9KvpsjDtZ',
  'biuro@solrent.pl',
  'SOLRENT',
  'tls'
) ON CONFLICT (id) DO UPDATE SET
  host = EXCLUDED.host,
  port = EXCLUDED.port,
  username = EXCLUDED.username,
  password = EXCLUDED.password,
  from_email = EXCLUDED.from_email,
  from_name = EXCLUDED.from_name,
  encryption = EXCLUDED.encryption,
  updated_at = now();

-- Dodaj domyślne ustawienia ponownych prób
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

-- Dodaj metadane DKIM, SPF i DMARC
COMMENT ON TABLE smtp_settings IS E'SMTP Configuration\n\nDKIM: v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+aRcMCDxMApYfUGX2VxCPz685F2/dJ+X9CBxxL0AFcukksKIa+CVoxfotGgFQYO1SqEXmfznH2MUZLz2MGXpQUymVnl1uo8ckiU7Su9mLosUBfAHAVAI/dsBOOws4/ECFMYvcqlVN9eDJgTzpdbj/JQB7m3B0jXchN++EHs5OabrLBTY4GN+D6iL1XtOBMkMJeqyi+pvAGU6MTyKsLBHnpT9yeTYsQDmX6j/hfVb+KRdPEYgOpwq4Xm2knjlBqPi5bXhkJ9cq4UnQniQWEO0X8+6L64uBfCsJgNajLTk3fpytYIYOBJlAuiGJMejVdo8VYXzGVy7pGh/aAQlYiOc8wIDAQAB\n\nSPF: v=spf1 redirect=_spf-h22.microhost.pl\n\nDMARC: v=DMARC1; p=none; sp=none; rua=mailto:spam-reports@microhost.pl\n\nMX: 10 mail.solrent.pl';

-- Dodaj politykę dla klientów, aby mogli widzieć swoje powiadomienia (jeśli nie istnieje)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'email_notifications' 
    AND policyname = 'Customers can view their own notifications'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "Customers can view their own notifications"
        ON email_notifications FOR SELECT
        TO authenticated
        USING (
          EXISTS (
            SELECT 1 FROM reservations r
            JOIN customers c ON r.customer_id = c.id
            WHERE r.id = email_notifications.reservation_id
            AND c.user_id = auth.uid()
          )
        );
    $policy$;
  END IF;
END
$$;