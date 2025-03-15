/*
  # Email Logs System

  1. New Tables
    - `email_logs`
      - `id` (uuid, primary key)
      - `notification_id` (uuid) - powiązanie z email_notifications
      - `template_id` (uuid) - użyty szablon
      - `template_version` (integer) - wersja szablonu
      - `recipient` (text) - adres email odbiorcy
      - `subject` (text) - temat emaila
      - `content` (text) - wysłana treść
      - `status` (text) - status wysyłki
      - `sent_at` (timestamptz) - data wysłania
      - `delivery_status` (text) - status dostarczenia
      - `error` (text) - opis błędu
      - `metadata` (jsonb) - dodatkowe informacje
      - `created_at` (timestamptz)

  2. Security
    - Enable RLS
    - Add policies for admin access
*/

-- Create email logs table
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid REFERENCES email_notifications(id) ON DELETE SET NULL,
  template_id uuid REFERENCES email_templates(id),
  template_version integer NOT NULL,
  recipient text NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  status text NOT NULL,
  sent_at timestamptz DEFAULT now(),
  delivery_status text,
  error text,
  metadata jsonb,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_log_status CHECK (status IN ('success', 'error', 'bounced')),
  CONSTRAINT valid_delivery_status CHECK (delivery_status IN ('delivered', 'failed', 'bounced', 'delayed', null))
);

-- Enable RLS
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Admins can view logs"
  ON email_logs
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Create index for better query performance
CREATE INDEX idx_email_logs_notification_id ON email_logs(notification_id);
CREATE INDEX idx_email_logs_sent_at ON email_logs(sent_at);
CREATE INDEX idx_email_logs_status ON email_logs(status);

-- Create function to clean old logs
CREATE OR REPLACE FUNCTION clean_old_email_logs()
RETURNS void AS $$
BEGIN
  -- Usuń logi starsze niż 90 dni
  DELETE FROM email_logs
  WHERE created_at < now() - interval '90 days';
END;
$$ LANGUAGE plpgsql;