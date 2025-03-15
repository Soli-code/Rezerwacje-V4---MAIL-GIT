/*
  # Add error message column to email notifications

  1. Changes
    - Dodanie kolumny error_message do tabeli email_notifications
    - Kolumna będzie przechowywać informacje o błędach podczas wysyłki maili

  2. Details
    - Typ kolumny: text
    - Domyślna wartość: NULL
    - Może być pusta (nullable)
*/

-- Dodaj kolumnę error_message jeśli nie istnieje
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'email_notifications' 
    AND column_name = 'error_message'
  ) THEN
    ALTER TABLE email_notifications 
    ADD COLUMN error_message text;
  END IF;
END $$;