/*
  # Poprawka systemu powiadomień email

  1. Zmiany
    - Dodanie polityk RLS dla email_logs
    - Aktualizacja triggerów dla email_logs
    - Dodanie funkcji obsługi powiadomień email
    
  2. Bezpieczeństwo
    - Polityki RLS dla dostępu publicznego
    - Uprawnienia dla administratorów
*/

-- Upewnij się, że tabela email_logs ma odpowiednie kolumny
ALTER TABLE email_logs
ADD COLUMN IF NOT EXISTS delivery_attempts integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_error text,
ADD COLUMN IF NOT EXISTS headers jsonb,
ADD COLUMN IF NOT EXISTS delivered_at timestamp with time zone;

-- Włącz RLS dla email_logs
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Usuń istniejące polityki
DROP POLICY IF EXISTS "Public can insert email logs" ON email_logs;
DROP POLICY IF EXISTS "System can update email logs" ON email_logs;
DROP POLICY IF EXISTS "Only admins can view email logs" ON email_logs;
DROP POLICY IF EXISTS "Admins can view email logs" ON email_logs;

-- Dodaj nowe polityki
CREATE POLICY "Public can insert email logs"
ON email_logs FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "System can update email logs"
ON email_logs FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

CREATE POLICY "Admins can view email logs"
ON email_logs FOR SELECT
TO authenticated
USING (EXISTS (
  SELECT 1 FROM profiles
  WHERE profiles.id = auth.uid()
  AND profiles.is_admin = true
));

-- Funkcja do obsługi nowych rezerwacji
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
BEGIN
  -- Dodaj wpis do email_logs
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status
  )
  SELECT
    t.id,
    NEW.id,
    c.email,
    'Potwierdzenie rezerwacji - SOLRENT',
    'Dziękujemy za dokonanie rezerwacji w SOLRENT. Szczegóły rezerwacji zostaną przesłane w osobnej wiadomości.',
    'pending'
  FROM reservations r
  JOIN customers c ON c.id = r.customer_id
  CROSS JOIN (
    SELECT id FROM email_templates 
    WHERE name = 'reservation_confirmation' 
    LIMIT 1
  ) t
  WHERE r.id = NEW.id;

  -- Wyślij kopię do biura
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status
  )
  SELECT
    t.id,
    NEW.id,
    'biuro@solrent.pl',
    'Nowa rezerwacja - SOLRENT',
    'Otrzymano nową rezerwację. Szczegóły dostępne w panelu administracyjnym.',
    'pending'
  FROM reservations r
  CROSS JOIN (
    SELECT id FROM email_templates 
    WHERE name = 'reservation_confirmation' 
    LIMIT 1
  ) t
  WHERE r.id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger dla nowych rezerwacji
DROP TRIGGER IF EXISTS send_new_reservation_email ON reservations;
CREATE TRIGGER send_new_reservation_email
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_reservation_email();