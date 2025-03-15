/*
  # Configure SMTP Settings

  1. Changes
    - Adds SMTP configuration for email sending
    - Sets up sender details and server configuration
    - Configures security and connection settings

  2. Security
    - Password is stored securely in the database
    - Only admins can access SMTP settings
*/

-- Insert SMTP settings
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
  '********', -- Zastąp rzeczywistym hasłem z Supabase
  'biuro@solrent.pl',
  'SOLRENT',
  'ssl'
);

-- Set default retry settings
INSERT INTO email_retry_settings (
  max_retries,
  retry_delay_minutes
) VALUES (
  3,  -- Maksymalna liczba prób ponownego wysłania
  5   -- Opóźnienie między próbami w minutach
);

-- Ensure only admins can manage SMTP settings
ALTER TABLE smtp_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Only admins can manage SMTP settings"
  ON smtp_settings
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Add trigger to ensure only one SMTP configuration exists
CREATE OR REPLACE FUNCTION check_smtp_settings_count()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM smtp_settings) > 0 AND TG_OP = 'INSERT' THEN
    RAISE EXCEPTION 'Only one SMTP configuration is allowed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_single_smtp_config
  BEFORE INSERT ON smtp_settings
  FOR EACH ROW
  EXECUTE FUNCTION check_smtp_settings_count();