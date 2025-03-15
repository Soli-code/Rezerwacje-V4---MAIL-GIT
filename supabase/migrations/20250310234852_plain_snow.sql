/*
  # Fix email notifications table structure

  1. Changes
    - Remove template_id references from email notifications
    - Update email notifications table structure
    - Update email sending functions to work without template_id
    
  2. Security
    - Maintain existing RLS policies
    - Keep security context for functions
*/

-- Modify email_notifications table to remove template_id dependency
ALTER TABLE IF EXISTS email_notifications 
  DROP COLUMN IF EXISTS template_id;

-- Update send_email function to not use template_id
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
  v_retry_settings email_retry_settings%ROWTYPE;
  v_attempt_count integer := 0;
  v_result jsonb;
  v_notification_id uuid;
BEGIN
  -- Pobierz ustawienia ponownych prób
  SELECT * INTO v_retry_settings FROM email_retry_settings LIMIT 1;
  
  -- Utwórz wpis w email_notifications
  INSERT INTO email_notifications (
    recipient,
    type,
    status
  ) VALUES (
    p_to,
    CASE WHEN p_to = 'biuro@solrent.pl' THEN 'admin' ELSE 'customer' END,
    'pending'
  ) RETURNING id INTO v_notification_id;
  
  -- Próba wysłania maila z obsługą ponownych prób
  WHILE v_attempt_count < v_retry_settings.max_retries LOOP
    BEGIN
      -- Tutaj logika wysyłania maila
      
      -- Aktualizuj status na sukces
      UPDATE email_notifications SET
        status = 'sent',
        sent_at = now(),
        delivery_attempts = v_attempt_count + 1
      WHERE id = v_notification_id;
      
      RETURN jsonb_build_object(
        'success', true,
        'message', 'Email sent successfully',
        'notification_id', v_notification_id
      );
    EXCEPTION WHEN OTHERS THEN
      v_attempt_count := v_attempt_count + 1;
      
      IF v_attempt_count >= v_retry_settings.max_retries THEN
        -- Aktualizuj status na błąd
        UPDATE email_notifications SET
          status = 'failed',
          error_message = SQLERRM,
          delivery_attempts = v_attempt_count,
          error_details = jsonb_build_object(
            'error', SQLERRM,
            'last_attempt', now(),
            'attempts_made', v_attempt_count
          )
        WHERE id = v_notification_id;
        
        RETURN jsonb_build_object(
          'success', false,
          'message', SQLERRM,
          'notification_id', v_notification_id
        );
      END IF;
      
      -- Czekaj przed kolejną próbą
      PERFORM pg_sleep(v_retry_settings.retry_delay_minutes * 60);
    END;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', false,
    'message', 'Max retry attempts reached',
    'notification_id', v_notification_id
  );
END;
$$;