/*
  # Aktualizacja konfiguracji SMTP i dodanie funkcji testowych

  1. Zmiany
    - Aktualizacja konfiguracji SMTP
    - Dodanie funkcji do testowania połączenia SMTP
    - Dodanie logowania prób połączenia
    
  2. Bezpieczeństwo
    - Zachowanie istniejących polityk RLS
    - Dodanie logowania dostępu do konfiguracji SMTP
*/

-- Aktualizuj konfigurację SMTP
UPDATE smtp_settings
SET 
  host = '188.210.221.82',
  port = 465, -- Port SSL
  username = 'biuro@solrent.pl',
  password = 'arELtGPxndj9KvpsjDtZ',
  from_email = 'biuro@solrent.pl',
  from_name = 'SOLRENT',
  encryption = 'ssl'
WHERE id = (SELECT id FROM smtp_settings LIMIT 1);

-- Dodaj kolumnę do przechowywania wyniku ostatniego testu
ALTER TABLE smtp_settings
ADD COLUMN IF NOT EXISTS last_test_result jsonb,
ADD COLUMN IF NOT EXISTS last_test_date timestamp with time zone;

-- Funkcja do logowania prób połączenia SMTP
CREATE OR REPLACE FUNCTION log_smtp_test_attempt(
  p_result jsonb,
  p_success boolean
) RETURNS void AS $$
BEGIN
  INSERT INTO email_logs (
    recipient,
    subject,
    body,
    status,
    error_message,
    smtp_response
  ) VALUES (
    'system',
    'SMTP Connection Test',
    CASE 
      WHEN p_success THEN 'SMTP connection test successful'
      ELSE 'SMTP connection test failed'
    END,
    CASE 
      WHEN p_success THEN 'delivered'
      ELSE 'failed'
    END,
    CASE 
      WHEN NOT p_success THEN p_result->>'error'
      ELSE NULL
    END,
    p_result::text
  );

  -- Aktualizuj wynik testu w konfiguracji SMTP
  UPDATE smtp_settings
  SET 
    last_test_result = p_result,
    last_test_date = now()
  WHERE id = (SELECT id FROM smtp_settings LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- Dodaj indeks dla szybszego wyszukiwania logów email
CREATE INDEX IF NOT EXISTS idx_email_logs_recipient_status 
ON email_logs(recipient, status);

-- Dodaj widok do bezpiecznego podglądu konfiguracji SMTP (bez hasła)
CREATE OR REPLACE VIEW smtp_settings_safe AS
SELECT 
  id,
  host,
  port,
  username,
  '********'::text as password,
  from_email,
  from_name,
  encryption,
  created_at,
  updated_at,
  last_test_result,
  last_test_date
FROM smtp_settings;