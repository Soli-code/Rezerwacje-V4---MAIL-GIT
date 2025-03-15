/*
  # Email Notifications Update

  1. Changes
    - Add new columns to email_notifications table
    - Add stored procedure for email handling

  2. Security
    - Add function security definer
*/

-- Add new columns to email_notifications table if they don't exist
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_notifications' AND column_name = 'delivery_time') 
  THEN
    ALTER TABLE email_notifications 
    ADD COLUMN delivery_time interval;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_notifications' AND column_name = 'retry_count') 
  THEN
    ALTER TABLE email_notifications 
    ADD COLUMN retry_count integer DEFAULT 0;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_notifications' AND column_name = 'headers') 
  THEN
    ALTER TABLE email_notifications 
    ADD COLUMN headers jsonb;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'email_notifications' AND column_name = 'metrics') 
  THEN
    ALTER TABLE email_notifications 
    ADD COLUMN metrics jsonb;
  END IF;
END $$;

-- Create stored procedure for sending emails if it doesn't exist
CREATE OR REPLACE FUNCTION send_reservation_emails(
  p_customer_email text,
  p_admin_email text,
  p_data jsonb,
  p_notification_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Wywołanie Edge Function do wysłania maili
  PERFORM net.http_post(
    url := current_setting('app.settings.email_function_url'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', current_setting('app.settings.email_function_key')
    ),
    body := jsonb_build_object(
      'customer_email', p_customer_email,
      'admin_email', p_admin_email,
      'data', p_data,
      'notification_ids', p_notification_ids
    )
  );
END;
$$;