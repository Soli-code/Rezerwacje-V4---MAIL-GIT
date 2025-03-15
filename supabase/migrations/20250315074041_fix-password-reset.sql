-- Upewnij się, że konfiguracja SMTP jest poprawna
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
WHERE id = (
  SELECT id FROM smtp_settings LIMIT 1
);

-- Dodaj komentarz wyjaśniający cel migracji
COMMENT ON TABLE auth.users IS 'Tabela użytkowników z włączoną funkcją resetowania hasła';

-- Upewnij się, że użytkownik biuro@solrent.pl ma ustawione email_confirmed_at
UPDATE auth.users
SET 
  email_confirmed_at = now(),
  updated_at = now(),
  recovery_sent_at = NULL,
  recovery_token = NULL
WHERE email = 'biuro@solrent.pl';
