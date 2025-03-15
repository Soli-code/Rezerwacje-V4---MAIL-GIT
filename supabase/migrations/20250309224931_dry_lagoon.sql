/*
  # Testowa wiadomość email

  1. Dodanie szablonu testowego emaila
  2. Dodanie funkcji do wysyłki testowej
  3. Dodanie testowych danych rezerwacji
*/

-- Dodaj szablon testowej wiadomości
INSERT INTO email_templates (name, subject, body)
VALUES (
  'test_reservation',
  'Potwierdzenie rezerwacji - TEST-2023-001',
  'Dziękujemy za dokonanie rezerwacji w SOLRENT!

Numer rezerwacji: TEST-2023-001

Szczegóły rezerwacji:
- Sprzęt: Kamera Sony FX3
- Data wypożyczenia: 15.12.2023
- Data zwrotu: 17.12.2023
- Koszt wypożyczenia: 500 PLN
- Status płatności: Oczekująca

Prosimy o przygotowanie:
- Dokumentu tożsamości
- Kaucji w wysokości: 1000 PLN

Godziny otwarcia:
Poniedziałek - Piątek: 8:00 - 16:00
Sobota: 8:00 - 13:00
Niedziela: nieczynne

W razie pytań prosimy o kontakt:
Tel: 694 171 171
Email: biuro@solrent.pl

Pozdrawiamy,
Zespół SOLRENT'
);

-- Funkcja do wysyłki testowej wiadomości
CREATE OR REPLACE FUNCTION send_test_email(p_recipient text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_template_id uuid;
BEGIN
  -- Pobierz ID szablonu
  SELECT id INTO v_template_id
  FROM email_templates
  WHERE name = 'test_reservation'
  LIMIT 1;

  -- Zapisz w logach
  INSERT INTO email_logs (
    template_id,
    recipient,
    subject,
    body,
    status
  )
  SELECT
    v_template_id,
    p_recipient,
    subject,
    body,
    'pending'
  FROM email_templates
  WHERE id = v_template_id;

  -- Wyślij kopię do biura
  INSERT INTO email_logs (
    template_id,
    recipient,
    subject,
    body,
    status
  )
  SELECT
    v_template_id,
    'biuro@solrent.pl',
    'Kopia: ' || subject,
    body,
    'pending'
  FROM email_templates
  WHERE id = v_template_id;
END;
$$;

-- Wyślij testową wiadomość
SELECT send_test_email('kubens11r@gmail.com');