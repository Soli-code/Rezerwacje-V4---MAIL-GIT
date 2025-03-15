-- Aktualizacja konfiguracji SMTP
UPDATE smtp_settings
SET 
  host = 'h22.seohost.pl',
  port = 465,
  username = 'biuro@solrent.pl',
  password = 'arELtGPxndj9KvpsjDtZ',
  from_email = 'biuro@solrent.pl',
  from_name = 'SOLRENT Rezerwacje',
  encryption = 'ssl',
  updated_at = now()
WHERE id = (SELECT id FROM smtp_settings LIMIT 1);

-- Jeśli nie ma żadnych ustawień, dodaj nowe
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
)
SELECT 
  'h22.seohost.pl',
  465,
  'biuro@solrent.pl',
  'arELtGPxndj9KvpsjDtZ',
  'biuro@solrent.pl',
  'SOLRENT Rezerwacje',
  'ssl'
WHERE NOT EXISTS (SELECT 1 FROM smtp_settings);

-- Dodaj indeks dla optymalizacji
CREATE INDEX IF NOT EXISTS idx_smtp_settings_updated_at 
  ON smtp_settings(updated_at);

-- Dodaj trigger do aktualizacji updated_at
CREATE OR REPLACE FUNCTION update_smtp_settings_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_smtp_settings_timestamp ON smtp_settings;
CREATE TRIGGER update_smtp_settings_timestamp
  BEFORE UPDATE ON smtp_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_smtp_settings_updated_at(); 