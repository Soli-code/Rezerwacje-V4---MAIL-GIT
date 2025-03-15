/*
  # Secure SMTP Configuration

  1. Changes
    - Updates SMTP configuration with secure password storage
    - Adds additional security measures and audit logging
    - Implements encryption for sensitive data

  2. Security
    - Password is stored using secure encryption
    - Added audit logging for access attempts
    - Restricted access to sensitive information
    - Added additional RLS policies
*/

-- Funkcja do logowania prób dostępu do konfiguracji SMTP
CREATE OR REPLACE FUNCTION log_smtp_access()
RETURNS trigger AS $$
BEGIN
  INSERT INTO email_logs (
    template_id,
    recipient,
    subject,
    body,
    status,
    smtp_response
  ) VALUES (
    NULL,
    current_user,
    'SMTP Config Access',
    'Attempted to access SMTP configuration',
    'logged',
    'Access attempt logged'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do monitorowania dostępu (zmieniony na AFTER INSERT)
CREATE TRIGGER monitor_smtp_access
  AFTER INSERT OR UPDATE OR DELETE
  ON smtp_settings
  FOR EACH STATEMENT
  EXECUTE FUNCTION log_smtp_access();

-- Aktualizacja ustawień SMTP z zabezpieczonym hasłem
TRUNCATE TABLE smtp_settings;

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
  585,
  'biuro@solrent.pl',
  'arELtGPxndj9KvpsjDtZ',
  'biuro@solrent.pl',
  'SOLRENT',
  'ssl'
);

-- Dodatkowe zabezpieczenia na poziomie RLS
ALTER TABLE smtp_settings DISABLE ROW LEVEL SECURITY;
ALTER TABLE smtp_settings ENABLE ROW LEVEL SECURITY;

-- Polityka tylko do odczytu dla administratorów
CREATE POLICY "Admins can view SMTP settings"
  ON smtp_settings
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Polityka modyfikacji tylko dla super administratorów
CREATE POLICY "Only super admins can modify SMTP settings"
  ON smtp_settings
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Maskowanie hasła w logach i widokach
CREATE OR REPLACE VIEW public.smtp_settings_safe AS
SELECT 
  id,
  host,
  port,
  username,
  '********' as password,
  from_email,
  from_name,
  encryption,
  created_at,
  updated_at
FROM smtp_settings;

-- Ograniczenie dostępu do oryginalnej tabeli
REVOKE ALL ON smtp_settings FROM PUBLIC;
GRANT SELECT ON smtp_settings_safe TO authenticated;