/*
  # Add SMTP settings and retry mechanism
  
  1. New Tables
    - smtp_settings: Stores SMTP configuration
    - email_retry_settings: Stores retry configuration
  
  2. Changes
    - Add retry mechanism to email handling
    - Add SMTP configuration management
*/

-- Create SMTP settings table
CREATE TABLE IF NOT EXISTS smtp_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host text NOT NULL,
  port integer NOT NULL,
  username text NOT NULL,
  password text NOT NULL,
  from_email text NOT NULL,
  from_name text NOT NULL,
  encryption text NOT NULL DEFAULT 'tls',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create retry settings table
CREATE TABLE IF NOT EXISTS email_retry_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  max_retries integer NOT NULL DEFAULT 3,
  retry_delay_minutes integer NOT NULL DEFAULT 5,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE smtp_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_retry_settings ENABLE ROW LEVEL SECURITY;

-- Add admin policies
CREATE POLICY "Admins can manage SMTP settings" ON smtp_settings
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));

CREATE POLICY "Admins can manage retry settings" ON email_retry_settings
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));

-- Function to handle email retries
CREATE OR REPLACE FUNCTION handle_email_retry()
RETURNS TRIGGER AS $$
DECLARE
  v_retry_settings email_retry_settings;
BEGIN
  -- Get retry settings
  SELECT * INTO v_retry_settings
  FROM email_retry_settings
  LIMIT 1;

  IF NOT FOUND THEN
    -- Use default settings
    v_retry_settings.max_retries := 3;
    v_retry_settings.retry_delay_minutes := 5;
  END IF;

  -- Update retry count and next retry time
  IF NEW.status = 'failed' AND (NEW.retry_count IS NULL OR NEW.retry_count < v_retry_settings.max_retries) THEN
    NEW.retry_count := COALESCE(NEW.retry_count, 0) + 1;
    NEW.next_retry_at := NOW() + (v_retry_settings.retry_delay_minutes * INTERVAL '1 minute');
    NEW.status := 'pending_retry';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for email retries
CREATE TRIGGER handle_email_retry_trigger
  BEFORE UPDATE OF status ON email_logs
  FOR EACH ROW
  WHEN (NEW.status = 'failed')
  EXECUTE FUNCTION handle_email_retry();

-- Insert default SMTP settings
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
) VALUES (
  'smtp.gmail.com',
  587,
  'noreply@solrent.pl',
  'placeholder_password',
  'noreply@solrent.pl',
  'SOLRENT',
  'tls'
);

-- Insert default retry settings
INSERT INTO email_retry_settings (
  max_retries,
  retry_delay_minutes
) VALUES (
  3,
  5
);