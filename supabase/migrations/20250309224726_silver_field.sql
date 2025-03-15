/*
  # Szablony wiadomości email

  1. Dodanie domyślnych szablonów
    - Potwierdzenie rezerwacji
    - Przypomnienie o rezerwacji
    - Status rezerwacji
    - Podziękowanie po zakończeniu

  2. Aktualizacja triggerów
    - Dodanie obsługi różnych statusów
    - Automatyczne przypomnienia
*/

-- Dodaj domyślne szablony email
INSERT INTO email_templates (name, subject, body) VALUES
('reservation_confirmation', 
 'Potwierdzenie rezerwacji - [NR_REZERWACJI]',
 'Dziękujemy za dokonanie rezerwacji w SOLRENT!

[SZCZEGOLY_REZERWACJI]

Prosimy o przygotowanie:
- Dokumentu tożsamości
- Kaucji w wysokości: [KAUCJA] zł

Godziny otwarcia:
Poniedziałek - Piątek: 8:00 - 16:00
Sobota: 8:00 - 13:00
Niedziela: nieczynne

Pozdrawiamy,
Zespół SOLRENT'),

('reservation_reminder',
 'Przypomnienie o rezerwacji - [NR_REZERWACJI]',
 'Przypominamy o zbliżającym się terminie rezerwacji:

[SZCZEGOLY_REZERWACJI]

Prosimy o przygotowanie:
- Dokumentu tożsamości
- Kaucji w wysokości: [KAUCJA] zł

W razie pytań prosimy o kontakt.

Pozdrawiamy,
Zespół SOLRENT'),

('status_update',
 'Aktualizacja statusu rezerwacji - [NR_REZERWACJI]',
 'Informujemy o zmianie statusu Państwa rezerwacji:

Status: [NOWY_STATUS]
[KOMENTARZ]

[SZCZEGOLY_REZERWACJI]

Pozdrawiamy,
Zespół SOLRENT'),

('rental_complete',
 'Dziękujemy za skorzystanie z naszych usług - [NR_REZERWACJI]',
 'Dziękujemy za skorzystanie z usług SOLRENT!

Państwa rezerwacja została zakończona.
Kaucja zostanie zwrócona w ciągu 24 godzin.

[SZCZEGOLY_REZERWACJI]

Zapraszamy ponownie!
Zespół SOLRENT');

-- Funkcja wysyłająca przypomnienie o rezerwacji
CREATE OR REPLACE FUNCTION send_reservation_reminder()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Wyślij przypomnienie na 24h przed rezerwacją
  IF NEW.start_date - INTERVAL '24 hours' <= NOW() AND NEW.status = 'confirmed' THEN
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
      replace(t.subject, '[NR_REZERWACJI]', NEW.id::text),
      replace(
        replace(
          replace(t.body, 
            '[SZCZEGOLY_REZERWACJI]', 
            format_reservation_details(NEW.id)
          ),
          '[KAUCJA]',
          (SELECT SUM(deposit * quantity) 
           FROM reservation_items ri 
           WHERE ri.reservation_id = NEW.id)::text
        ),
        '[NR_REZERWACJI]',
        NEW.id::text
      ),
      'pending'
    FROM email_templates t
    CROSS JOIN customers c
    WHERE t.name = 'reservation_reminder'
    AND c.id = NEW.customer_id;
  END IF;

  RETURN NEW;
END;
$$;