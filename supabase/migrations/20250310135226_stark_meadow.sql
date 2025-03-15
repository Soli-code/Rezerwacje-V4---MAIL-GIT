/*
  # Email System Improvements

  1. Updates to email_notifications table
    - Add delivery tracking fields
    - Add retry tracking
    - Add bounce handling

  2. Security
    - Update RLS policies for better access control
*/

-- Add new columns to email_notifications
ALTER TABLE email_notifications
ADD COLUMN IF NOT EXISTS message_id text,
ADD COLUMN IF NOT EXISTS delivery_attempts integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_attempt_at timestamptz,
ADD COLUMN IF NOT EXISTS bounce_info jsonb,
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Update status check constraint
ALTER TABLE email_notifications
DROP CONSTRAINT IF EXISTS email_notifications_status_check,
ADD CONSTRAINT email_notifications_status_check 
  CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'bounced'));

-- Create index for faster status queries
CREATE INDEX IF NOT EXISTS idx_email_notifications_status 
  ON email_notifications(status);

-- Create function to update timestamp
CREATE OR REPLACE FUNCTION update_email_notification_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for timestamp updates
CREATE TRIGGER update_email_notification_timestamp
  BEFORE UPDATE ON email_notifications
  FOR EACH ROW
  EXECUTE FUNCTION update_email_notification_timestamp();

-- Create function to handle bounced emails
CREATE OR REPLACE FUNCTION handle_email_bounce()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'bounced' THEN
    -- Log bounce in a separate table for analysis
    INSERT INTO email_bounce_logs (
      email_notification_id,
      recipient,
      bounce_info
    ) VALUES (
      NEW.id,
      NEW.recipient,
      NEW.bounce_info
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for bounce handling
CREATE TRIGGER handle_email_bounce_trigger
  AFTER UPDATE OF status ON email_notifications
  FOR EACH ROW
  WHEN (NEW.status = 'bounced')
  EXECUTE FUNCTION handle_email_bounce();

-- Create bounce logs table
CREATE TABLE IF NOT EXISTS email_bounce_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_notification_id uuid REFERENCES email_notifications(id),
  recipient text NOT NULL,
  bounce_info jsonb,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on bounce logs
ALTER TABLE email_bounce_logs ENABLE ROW LEVEL SECURITY;

-- Create policies for bounce logs
CREATE POLICY "Admins can view bounce logs"
  ON email_bounce_logs
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));