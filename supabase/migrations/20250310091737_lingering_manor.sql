/*
  # Funkcja wysyłająca testowy email

  1. Nowa funkcja
    - `send_test_email(recipient text)` - wysyła testowy email do wskazanego odbiorcy
    - Używa danych z tabeli contact_info
    - Zapisuje logi w email_logs
    - Zwraca status operacji

  2. Bezpieczeństwo
    - Dostępna tylko dla uwierzytelnionych użytkowników
*/

-- Usuwamy starą wersję funkcji jeśli istnieje
DROP FUNCTION IF EXISTS send_test_email(text);

-- Tworzymy nową funkcję
CREATE OR REPLACE FUNCTION send_test_email(recipient text)
RETURNS text
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_contact contact_info%ROWTYPE;
    v_email_body text;
    v_subject text := 'Test połączenia email - SOLRENT';
BEGIN
    -- Sprawdź czy użytkownik jest zalogowany
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Użytkownik musi być zalogowany';
    END IF;

    -- Pobierz dane kontaktowe
    SELECT * INTO v_contact 
    FROM contact_info 
    ORDER BY updated_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Nie znaleziono danych kontaktowych';
    END IF;

    -- Przygotuj treść emaila
    v_email_body := '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #FF6B00;">Test połączenia email</h1>
        <p>To jest testowa wiadomość z systemu SOLRENT.</p>
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin: 20px 0;">
            <p>Jeśli otrzymałeś tę wiadomość, oznacza to że:</p>
            <ul>
                <li>Konfiguracja SMTP jest poprawna</li>
                <li>System może wysyłać emaile</li>
                <li>Formatowanie HTML działa prawidłowo</li>
            </ul>
        </div>
        <p style="color: #666666;">Dane kontaktowe w systemie:</p>
        <p style="color: #666666;">
            Tel: ' || v_contact.phone_number || '<br>
            Email: ' || v_contact.email || '
        </p>
        <hr style="border: 1px solid #f5f5f5; margin: 20px 0;">
        <p style="font-size: 12px; color: #999999;">
            Ta wiadomość została wygenerowana automatycznie w celach testowych.
            <br>Wysłano: ' || to_char(now(), 'YYYY-MM-DD HH24:MI:SS') || '
        </p>
    </div>';

    -- Wyślij email
    PERFORM net.http_post(
        url := current_setting('app.settings.smtp_server'),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.smtp_password')
        ),
        body := jsonb_build_object(
            'to', recipient,
            'from', v_contact.email,
            'subject', v_subject,
            'html', v_email_body
        )
    );

    -- Zapisz log
    INSERT INTO email_logs (
        recipient,
        subject,
        body,
        status
    ) VALUES (
        recipient,
        v_subject,
        v_email_body,
        'sent'
    );

    RETURN 'Email testowy został wysłany do ' || recipient;

EXCEPTION WHEN OTHERS THEN
    -- Zapisz błąd w logach
    INSERT INTO email_logs (
        recipient,
        subject,
        body,
        status,
        error_message
    ) VALUES (
        recipient,
        v_subject,
        v_email_body,
        'error',
        SQLERRM
    );

    RETURN 'Błąd wysyłania emaila: ' || SQLERRM;
END;
$$;