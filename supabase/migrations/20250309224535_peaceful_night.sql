/*
  # System powiadomień email

  1. Nowe Tabele
    - `email_templates` - szablony wiadomości email
      - id (uuid, primary key)
      - name (text) - nazwa szablonu
      - subject (text) - temat wiadomości
      - body (text) - treść wiadomości
      - created_at (timestamptz)
      - updated_at (timestamptz)
    
    - `email_logs` - logi wysyłek email
      - id (uuid, primary key)
      - template_id (uuid) - powiązanie z szablonem
      - reservation_id (uuid) - powiązanie z rezerwacją
      - recipient (text) - adres odbiorcy
      - subject (text) - temat wysłanej wiadomości
      - body (text) - treść wysłanej wiadomości
      - status (text) - status wysyłki
      - error_message (text) - opis błędu jeśli wystąpił
      - sent_at (timestamptz) - data wysyłki

  2. Funkcje
    - `format_reservation_details()` - formatowanie szczegółów rezerwacji
    - `handle_new_reservation_email()` - obsługa wysyłki maila po utworzeniu rezerwacji
    
  3. Triggery
    - Automatyczna wysyłka maila po utworzeniu rezerwacji
*/

-- Tabela szablonów email (jeśli nie istnieje)
CREATE TABLE IF NOT EXISTS email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Tabela logów email (jeśli nie istnieje)
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id),
  reservation_id uuid REFERENCES reservations(id),
  recipient text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  status text NOT NULL,
  error_message text,
  sent_at timestamptz DEFAULT now()
);

-- Funkcja formatująca szczegóły rezerwacji
CREATE OR REPLACE FUNCTION format_reservation_details(p_reservation_id uuid)
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_details text;
  v_customer record;
  v_reservation record;
  v_items record;
BEGIN
  -- Pobierz dane rezerwacji i klienta
  SELECT 
    r.*,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.comment
  INTO v_reservation
  FROM reservations r
  JOIN customers c ON c.id = r.customer_id
  WHERE r.id = p_reservation_id;

  -- Formatuj podstawowe informacje
  v_details := format(
    'Nowa rezerwacja od: %s %s\n' ||
    'Email: %s\n' ||
    'Telefon: %s\n\n' ||
    'Data rozpoczęcia: %s %s\n' ||
    'Data zakończenia: %s %s\n\n' ||
    'Zarezerwowany sprzęt:\n',
    v_reservation.first_name,
    v_reservation.last_name,
    v_reservation.email,
    v_reservation.phone,
    v_reservation.start_date::date,
    v_reservation.start_time,
    v_reservation.end_date::date,
    v_reservation.end_time
  );

  -- Dodaj listę sprzętu
  FOR v_items IN (
    SELECT 
      e.name,
      ri.quantity,
      ri.price_per_day,
      ri.deposit
    FROM reservation_items ri
    JOIN equipment e ON e.id = ri.equipment_id
    WHERE ri.reservation_id = p_reservation_id
  ) LOOP
    v_details := v_details || format(
      '- %s (x%s) - %s zł/dzień',
      v_items.name,
      v_items.quantity,
      v_items.price_per_day
    );
    IF v_items.deposit > 0 THEN
      v_details := v_details || format(', kaucja: %s zł', v_items.deposit);
    END IF;
    v_details := v_details || E'\n';
  END LOOP;

  -- Dodaj łączną kwotę
  v_details := v_details || format(
    '\nŁączna kwota: %s zł',
    v_reservation.total_price
  );

  -- Dodaj komentarz jeśli istnieje
  IF v_reservation.comment IS NOT NULL THEN
    v_details := v_details || format(
      '\n\nKomentarz klienta:\n%s',
      v_reservation.comment
    );
  END IF;

  RETURN v_details;
END;
$$;

-- Funkcja wysyłająca email po utworzeniu rezerwacji
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_template_id uuid;
  v_customer_email text;
  v_subject text;
  v_body text;
  v_details text;
BEGIN
  -- Pobierz email klienta
  SELECT c.email INTO v_customer_email
  FROM customers c
  WHERE c.id = NEW.customer_id;

  -- Pobierz szablon
  SELECT id, subject, body 
  INTO v_template_id, v_subject, v_body
  FROM email_templates 
  WHERE name = 'new_reservation'
  LIMIT 1;

  -- Jeśli nie ma szablonu, utwórz domyślny
  IF v_template_id IS NULL THEN
    INSERT INTO email_templates (name, subject, body)
    VALUES (
      'new_reservation',
      'Potwierdzenie rezerwacji - [NR_REZERWACJI]',
      'Dziękujemy za dokonanie rezerwacji!\n\n[SZCZEGOLY_REZERWACJI]\n\nPozdrawiamy,\nZespół SOLRENT'
    )
    RETURNING id, subject, body 
    INTO v_template_id, v_subject, v_body;
  END IF;

  -- Przygotuj szczegóły rezerwacji
  v_details := format_reservation_details(NEW.id);
  
  -- Przygotuj treść maila
  v_subject := replace(v_subject, '[NR_REZERWACJI]', NEW.id::text);
  v_body := replace(v_body, '[SZCZEGOLY_REZERWACJI]', v_details);

  -- Zapisz w logach
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status
  ) VALUES (
    v_template_id,
    NEW.id,
    v_customer_email,
    v_subject,
    v_body,
    'pending'
  );

  -- Wyślij kopię do biura
  INSERT INTO email_logs (
    template_id,
    reservation_id,
    recipient,
    subject,
    body,
    status
  ) VALUES (
    v_template_id,
    NEW.id,
    'biuro@solrent.pl',
    'Nowa rezerwacja: ' || v_subject,
    v_body,
    'pending'
  );

  RETURN NEW;
END;
$$;

-- Trigger wysyłający email po utworzeniu rezerwacji
DROP TRIGGER IF EXISTS send_new_reservation_email ON reservations;
CREATE TRIGGER send_new_reservation_email
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_reservation_email();

-- Uprawnienia
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Usuń istniejące polityki jeśli istnieją
DROP POLICY IF EXISTS "Only admins can manage email templates" ON email_templates;
DROP POLICY IF EXISTS "Only admins can view email logs" ON email_logs;

-- Utwórz nowe polityki
CREATE POLICY "Only admins can manage email templates"
  ON email_templates
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));

CREATE POLICY "Only admins can view email logs"
  ON email_logs
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));