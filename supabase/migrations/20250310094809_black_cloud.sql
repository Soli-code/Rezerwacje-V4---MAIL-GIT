/*
  # Email Logs Security Fix

  1. Changes
    - Adds proper RLS policies for email_logs table
    - Enables public insert access for logging emails
    - Restricts viewing logs to admins only

  2. Security
    - Enables RLS on email_logs table
    - Adds specific policies for different operations
*/

-- Włącz RLS dla tabeli email_logs
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Usuń istniejące polityki
DROP POLICY IF EXISTS "Public can insert email logs" ON email_logs;
DROP POLICY IF EXISTS "Admins can view email logs" ON email_logs;

-- Polityka pozwalająca na dodawanie logów przez wszystkich
CREATE POLICY "Public can insert email logs"
ON email_logs
FOR INSERT
TO public
WITH CHECK (true);

-- Polityka pozwalająca na przeglądanie logów przez administratorów
CREATE POLICY "Admins can view email logs"
ON email_logs
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Polityka pozwalająca na aktualizację logów przez system
CREATE POLICY "System can update email logs"
ON email_logs
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);