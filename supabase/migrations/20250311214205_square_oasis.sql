/*
  # Add email notifications debug trigger

  1. Changes
    - Add trigger to log reservation creation
    - Add function to handle email notifications
    - Add logging table for debugging
*/

-- Create debug logging table
CREATE TABLE IF NOT EXISTS debug_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  event_data jsonb,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE debug_logs ENABLE ROW LEVEL SECURITY;

-- Add policy for admins
CREATE POLICY "Admins can view debug logs"
  ON debug_logs
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Create debug trigger function
CREATE OR REPLACE FUNCTION log_reservation_creation()
RETURNS trigger AS $$
BEGIN
  -- Log reservation data
  INSERT INTO debug_logs (event_type, event_data)
  VALUES (
    'reservation_created',
    jsonb_build_object(
      'reservation_id', NEW.id,
      'customer_id', NEW.customer_id,
      'start_date', NEW.start_date,
      'end_date', NEW.end_date,
      'total_price', NEW.total_price,
      'status', NEW.status
    )
  );

  -- Create email notifications
  INSERT INTO email_notifications (
    reservation_id,
    recipient,
    type,
    status
  )
  SELECT 
    NEW.id,
    c.email,
    'customer',
    'pending'
  FROM customers c
  WHERE c.id = NEW.customer_id;

  -- Create notification for admin
  INSERT INTO email_notifications (
    reservation_id,
    recipient,
    type,
    status
  )
  VALUES (
    NEW.id,
    'biuro@solrent.pl',
    'admin',
    'pending'
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to reservations table
DROP TRIGGER IF EXISTS debug_reservation_creation ON reservations;
CREATE TRIGGER debug_reservation_creation
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION log_reservation_creation();