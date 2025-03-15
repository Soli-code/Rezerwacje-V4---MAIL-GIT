-- Zaktualizuj konto administratora, ustawiając email_confirmed_at
UPDATE auth.users
SET 
  email_confirmed_at = now(),
  updated_at = now()
WHERE email = 'biuro@solrent.pl';