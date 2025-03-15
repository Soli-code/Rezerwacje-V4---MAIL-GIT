/*
  # Setup email sending functions with safe trigger creation

  1. Functions
    - `send_email` - wysyła email przez SMTP
    - `handle_email_retry` - obsługuje ponowne próby wysyłki
    - `update_email_delivery_time` - aktualizuje czas dostarczenia
    - `handle_email_bounce` - obsługuje odbite maile

  2. Changes
    - Bezpieczne dodanie triggerów dla email_notifications
*/

-- Funkcja do wysyłania maili przez SMTP
CREATE OR REPLACE FUNCTION send_email(
  p_to text,
  p_subject text,
  p_body text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_smtp_settings smtp_settings%ROWTYPE;
  v_result jsonb;
  v_error_details text;
BEGIN
  -- Pobierz konfigurację SMTP
  SELECT * INTO v_smtp_settings FROM smtp_settings LIMIT 1;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'SMTP configuration not found';
  END IF;

  -- Wywołaj Edge Function do wysłania maila
  BEGIN
    SELECT http((
      'POST',
      current_setting('app.settings.edge_function_url') || '/send-email',
      ARRAY[http_header('Content-Type', 'application/json')],
      jsonb_build_object(
        'to', p_to,
        'from', v_smtp_settings.from_email,
        'fromName', v_smtp_settings.from_name,
        'subject', p_subject,
        'body', p_body,
        'smtp', jsonb_build_object(
          'host', v_smtp_settings.host,
          'port', v_smtp_settings.port,
          'user', v_smtp_settings.username,
          'pass', v_smtp_settings.password,
          'secure', true,
          'tls', jsonb_build_object(
            'rejectUnauthorized', false
          )
        )
      )::text,
      60 -- timeout in seconds
    )) INTO v_result;

    -- Zapisz log wysłania
    INSERT INTO email_logs (
      recipient,
      subject,
      content,
      status,
      smtp_response,
      headers,
      metadata
    ) VALUES (
      p_to,
      p_subject,
      p_body,
      CASE 
        WHEN (v_result->>'statusCode')::int = 200 THEN 'sent'
        ELSE 'failed'
      END,
      v_result::text,
      jsonb_build_object('smtp_host', v_smtp_settings.host),
      jsonb_build_object(
        'attempt_timestamp', now(),
        'response_code', v_result->>'statusCode'
      )
    );

    RETURN v_result;
  EXCEPTION
    WHEN OTHERS THEN
      v_error_details := SQLERRM;
      
      -- Zapisz szczegóły błędu
      INSERT INTO email_logs (
        recipient,
        subject,
        content,
        status,
        error_message,
        error_details,
        headers,
        metadata
      ) VALUES (
        p_to,
        p_subject,
        p_body,
        'failed',
        v_error_details,
        jsonb_build_object(
          'error_code', SQLSTATE,
          'error_message', v_error_details,
          'smtp_host', v_smtp_settings.host,
          'smtp_port', v_smtp_settings.port
        ),
        jsonb_build_object('smtp_host', v_smtp_settings.host),
        jsonb_build_object(
          'attempt_timestamp', now(),
          'error_type', 'smtp_connection_error'
        )
      );

      RETURN jsonb_build_object(
        'success', false,
        'error', v_error_details,
        'details', jsonb_build_object(
          'timestamp', now(),
          'smtp_host', v_smtp_settings.host,
          'recipient', p_to
        )
      );
  END;
END;
$$;

-- Funkcja do obsługi ponownych prób wysyłki
CREATE OR REPLACE FUNCTION handle_email_retry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_settings email_retry_settings%ROWTYPE;
BEGIN
  -- Pobierz ustawienia ponownych prób
  SELECT * INTO v_settings FROM email_retry_settings LIMIT 1;
  
  IF NOT FOUND THEN
    v_settings.max_retries := 3;
    v_settings.retry_delay_minutes := 5;
  END IF;

  -- Zwiększ licznik prób
  NEW.retry_count := COALESCE(OLD.retry_count, 0) + 1;
  
  -- Jeśli nie przekroczono maksymalnej liczby prób, zaplanuj kolejną
  IF NEW.retry_count < v_settings.max_retries THEN
    NEW.status := 'pending';
    NEW.next_retry_at := NOW() + (v_settings.retry_delay_minutes * NEW.retry_count || ' minutes')::interval;
  ELSE
    NEW.status := 'failed';
    NEW.next_retry_at := NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- Funkcja do aktualizacji czasu dostarczenia
CREATE OR REPLACE FUNCTION update_email_delivery_time()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'delivered' AND OLD.status != 'delivered' THEN
    NEW.delivery_time := NOW() - NEW.sent_at;
  END IF;
  RETURN NEW;
END;
$$;

-- Funkcja do obsługi odbitych maili
CREATE OR REPLACE FUNCTION handle_email_bounce()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Zapisz informacje o odbiciu w logu
  INSERT INTO email_bounce_logs (
    email_notification_id,
    recipient,
    bounce_info
  ) VALUES (
    NEW.id,
    NEW.recipient,
    NEW.bounce_info
  );
  
  RETURN NEW;
END;
$$;

-- Bezpieczne tworzenie triggerów
DO $$
BEGIN
  -- Sprawdź i utwórz trigger handle_email_retry_trigger
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_retry_trigger'
  ) THEN
    CREATE TRIGGER handle_email_retry_trigger
      BEFORE UPDATE OF status ON email_notifications
      FOR EACH ROW
      WHEN (NEW.status = 'failed')
      EXECUTE FUNCTION handle_email_retry();
  END IF;

  -- Sprawdź i utwórz trigger calculate_delivery_time
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'calculate_delivery_time'
  ) THEN
    CREATE TRIGGER calculate_delivery_time
      BEFORE UPDATE OF status ON email_notifications
      FOR EACH ROW
      EXECUTE FUNCTION update_email_delivery_time();
  END IF;

  -- Sprawdź i utwórz trigger handle_email_bounce_trigger
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'handle_email_bounce_trigger'
  ) THEN
    CREATE TRIGGER handle_email_bounce_trigger
      AFTER UPDATE OF status ON email_notifications
      FOR EACH ROW
      WHEN (NEW.status = 'bounced')
      EXECUTE FUNCTION handle_email_bounce();
  END IF;

  -- Sprawdź i utwórz trigger update_email_notification_timestamp
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_email_notification_timestamp'
  ) THEN
    CREATE TRIGGER update_email_notification_timestamp
      BEFORE UPDATE ON email_notifications
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END;
$$;