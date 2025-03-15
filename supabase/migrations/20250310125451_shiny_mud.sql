/*
  # Aktualizacja konfiguracji SMTP

  1. Zmiany
    - Usuwa istniejącą konfigurację SMTP
    - Dodaje nową konfigurację SMTP
    - Upewnia się, że polityki dostępu są poprawnie ustawione
  
  2. Bezpieczeństwo
    - Tylko administratorzy mogą zarządzać konfiguracją SMTP
*/

-- Najpierw usuń istniejącą konfigurację
DELETE FROM smtp_settings;

-- Dodaj nową konfigurację SMTP
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
)
VALUES (
  'smtp.gmail.com',
  587,
  'noreply@solrent.pl',
  'your_smtp_password',
  'noreply@solrent.pl',
  'SOLRENT',
  'tls'
);

-- Upewnij się, że polityki dostępu są ustawione
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'smtp_settings' 
    AND policyname = 'Only admins can manage SMTP settings'
  ) THEN
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
      )
      WITH CHECK (
        EXISTS (
          SELECT 1 FROM profiles
          WHERE profiles.id = auth.uid()
          AND profiles.is_admin = true
        )
      );
  END IF;
END $$;