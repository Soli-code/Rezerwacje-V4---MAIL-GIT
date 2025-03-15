/*
  # Konfiguracja systemu emaili

  1. Nowe Tabele (jeśli nie istnieją)
    - `email_templates` - przechowuje szablony emaili
      - `id` (uuid, primary key)
      - `name` (text) - nazwa szablonu
      - `subject` (text) - temat emaila
      - `body` (text) - treść emaila w formacie HTML
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Funkcje
    - `send_reservation_email()` - wysyła email z potwierdzeniem rezerwacji
    - `handle_new_reservation_email()` - trigger function wywoływana po utworzeniu nowej rezerwacji

  3. Triggery
    - Automatyczne wysyłanie emaila po utworzeniu rezerwacji
*/

-- Sprawdź i utwórz tabelę email_templates jeśli nie istnieje
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'email_templates') THEN
    CREATE TABLE email_templates (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      name text NOT NULL,
      subject text NOT NULL,
      body text NOT NULL,
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    );
  END IF;
END $$;

-- Sprawdź czy szablon już istnieje przed dodaniem
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM email_templates 
    WHERE name = 'reservation_confirmation'
  ) THEN
    INSERT INTO email_templates (name, subject, body)
    VALUES (
      'reservation_confirmation',
      'Potwierdzenie rezerwacji sprzętu - SOLRENT',
      '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #FF6B00;">Potwierdzenie rezerwacji</h1>
        <p>Dziękujemy za dokonanie rezerwacji w SOLRENT!</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <h2 style="color: #333333; margin-top: 0;">Szczegóły rezerwacji:</h2>
          <p><strong>Numer rezerwacji:</strong> {{reservation_id}}</p>
          <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
          <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          <p><strong>Zarezerwowany sprzęt:</strong></p>
          <ul style="list-style-type: none; padding-left: 0;">
            {{equipment_list}}
          </ul>
          <p><strong>Całkowity koszt:</strong> {{total_price}} PLN</p>
          <p><strong>Kaucja:</strong> {{deposit_amount}} PLN</p>
        </div>
        <div style="background-color: #fff3e0; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #FF6B00; margin-top: 0;">Ważne informacje:</h3>
          <ul>
            <li>Prosimy o odbiór sprzętu w ustalonym terminie</li>
            <li>Wymagane jest okazanie dokumentu tożsamości</li>
            <li>Kaucja jest pobierana przy odbiorze sprzętu</li>
            <li>Płatność możliwa jest gotówką lub kartą przy odbiorze</li>
          </ul>
        </div>
        <p style="color: #666666;">W razie pytań prosimy o kontakt:</p>
        <p style="color: #666666;">
          Tel: {{contact_phone}}<br>
          Email: {{contact_email}}
        </p>
        <hr style="border: 1px solid #f5f5f5; margin: 20px 0;">
        <p style="font-size: 12px; color: #999999;">
          Ta wiadomość została wygenerowana automatycznie. Prosimy na nią nie odpowiadać.
        </p>
      </div>'
    );
  END IF;
END $$;

-- Funkcja wysyłająca email z potwierdzeniem rezerwacji
CREATE OR REPLACE FUNCTION send_reservation_email(reservation_id uuid)
RETURNS void AS $$
DECLARE
    v_template email_templates%ROWTYPE;
    v_reservation reservations%ROWTYPE;
    v_customer customers%ROWTYPE;
    v_contact contact_info%ROWTYPE;
    v_equipment_list text := '';
    v_email_body text;
    v_item record;
BEGIN
    -- Pobierz szablon emaila
    SELECT * INTO v_template 
    FROM email_templates 
    WHERE name = 'reservation_confirmation';

    -- Pobierz dane rezerwacji
    SELECT * INTO v_reservation 
    FROM reservations 
    WHERE id = reservation_id;

    -- Pobierz dane klienta
    SELECT * INTO v_customer 
    FROM customers 
    WHERE id = v_reservation.customer_id;

    -- Pobierz dane kontaktowe
    SELECT * INTO v_contact 
    FROM contact_info 
    LIMIT 1;

    -- Przygotuj listę sprzętu
    FOR v_item IN (
        SELECT e.name, ri.quantity, ri.price_per_day, ri.deposit
        FROM reservation_items ri
        JOIN equipment e ON e.id = ri.equipment_id
        WHERE ri.reservation_id = reservation_id
    ) LOOP
        v_equipment_list := v_equipment_list || 
            '<li style="margin-bottom: 10px;">' ||
            v_item.name || ' (x' || v_item.quantity || ') - ' ||
            v_item.price_per_day || ' PLN/dzień' ||
            CASE WHEN v_item.deposit > 0 
                THEN ', kaucja: ' || v_item.deposit || ' PLN'
                ELSE ''
            END ||
            '</li>';
    END LOOP;

    -- Przygotuj treść emaila
    v_email_body := replace(v_template.body, '{{reservation_id}}', reservation_id::text);
    v_email_body := replace(v_email_body, '{{start_date}}', 
        to_char(v_reservation.start_date, 'DD.MM.YYYY') || ' ' || v_reservation.start_time);
    v_email_body := replace(v_email_body, '{{end_date}}', 
        to_char(v_reservation.end_date, 'DD.MM.YYYY') || ' ' || v_reservation.end_time);
    v_email_body := replace(v_email_body, '{{equipment_list}}', v_equipment_list);
    v_email_body := replace(v_email_body, '{{total_price}}', v_reservation.total_price::text);
    v_email_body := replace(v_email_body, '{{deposit_amount}}', 
        (SELECT COALESCE(SUM(deposit * quantity), 0) 
         FROM reservation_items 
         WHERE reservation_id = v_reservation.id)::text);
    v_email_body := replace(v_email_body, '{{contact_phone}}', v_contact.phone_number);
    v_email_body := replace(v_email_body, '{{contact_email}}', v_contact.email);

    -- Wyślij email
    PERFORM net.http_post(
        url := current_setting('app.settings.smtp_server'),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.smtp_password')
        ),
        body := jsonb_build_object(
            'to', v_customer.email,
            'subject', v_template.subject,
            'html', v_email_body
        )
    );

    -- Zapisz log wysłania emaila
    INSERT INTO email_logs (
        template_id,
        reservation_id,
        recipient,
        subject,
        body,
        status
    ) VALUES (
        v_template.id,
        reservation_id,
        v_customer.email,
        v_template.subject,
        v_email_body,
        'sent'
    );

EXCEPTION WHEN OTHERS THEN
    -- W przypadku błędu zapisz log z informacją o błędzie
    INSERT INTO email_logs (
        template_id,
        reservation_id,
        recipient,
        subject,
        body,
        status,
        error_message
    ) VALUES (
        v_template.id,
        reservation_id,
        v_customer.email,
        v_template.subject,
        v_email_body,
        'error',
        SQLERRM
    );
END;
$$ LANGUAGE plpgsql;

-- Trigger function do automatycznego wysyłania emaila po utworzeniu rezerwacji
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM send_reservation_email(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Usuń trigger jeśli istnieje i utwórz go na nowo
DO $$
BEGIN
    DROP TRIGGER IF EXISTS send_new_reservation_email ON reservations;
    
    CREATE TRIGGER send_new_reservation_email
    AFTER INSERT ON reservations
    FOR EACH ROW
    EXECUTE FUNCTION handle_new_reservation_email();
END $$;