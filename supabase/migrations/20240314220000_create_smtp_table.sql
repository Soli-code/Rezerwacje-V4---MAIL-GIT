-- Utworzenie tabeli smtp_settings
CREATE TABLE IF NOT EXISTS smtp_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    host text NOT NULL,
    port integer NOT NULL,
    username text NOT NULL,
    password text NOT NULL,
    from_email text NOT NULL,
    from_name text NOT NULL,
    secure boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Dodanie komentarzy do tabeli
COMMENT ON TABLE smtp_settings IS 'Przechowuje konfigurację SMTP dla systemu mailowego';
COMMENT ON COLUMN smtp_settings.host IS 'Adres serwera SMTP';
COMMENT ON COLUMN smtp_settings.port IS 'Port serwera SMTP';
COMMENT ON COLUMN smtp_settings.username IS 'Nazwa użytkownika do serwera SMTP';
COMMENT ON COLUMN smtp_settings.password IS 'Hasło do serwera SMTP';
COMMENT ON COLUMN smtp_settings.from_email IS 'Adres email nadawcy';
COMMENT ON COLUMN smtp_settings.from_name IS 'Nazwa wyświetlana nadawcy';
COMMENT ON COLUMN smtp_settings.encryption IS 'Typ szyfrowania (ssl/tls)';

-- Dodanie polityki RLS (Row Level Security)
ALTER TABLE smtp_settings ENABLE ROW LEVEL SECURITY;

-- Dodaj politykę dostępu
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'smtp_settings' 
    AND policyname = 'Administratorzy mogą zarządzać ustawieniami SMTP'
  ) THEN
    CREATE POLICY "Administratorzy mogą zarządzać ustawieniami SMTP" ON smtp_settings
    FOR ALL TO authenticated
    USING (auth.jwt() ->> 'role' = 'admin')
    WITH CHECK (auth.jwt() ->> 'role' = 'admin');
  END IF;
END
$$; 