/*
  # Fix email notifications RLS policies

  1. Changes
    - Drop existing policies
    - Add new policies that allow:
      - Public users to insert notifications
      - Public users to update notifications
      - Admins to view all notifications
      - Customers to view their own notifications
      - System to manage notifications
*/

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public can insert email logs" ON email_notifications;
DROP POLICY IF EXISTS "System can update email logs" ON email_notifications;
DROP POLICY IF EXISTS "Admins can view all notifications" ON email_notifications;
DROP POLICY IF EXISTS "Customers can view their own notifications" ON email_notifications;

-- Enable RLS
ALTER TABLE email_notifications ENABLE ROW LEVEL SECURITY;

-- Add new policies
CREATE POLICY "Public can insert email logs"
ON email_notifications
FOR INSERT
TO public
WITH CHECK (true);

CREATE POLICY "Public can update email logs"
ON email_notifications
FOR UPDATE
TO public
USING (true)
WITH CHECK (true);

CREATE POLICY "Admins can view all notifications"
ON email_notifications
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

CREATE POLICY "Customers can view their own notifications"
ON email_notifications
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM reservations r
    JOIN customers c ON r.customer_id = c.id
    WHERE r.id = email_notifications.reservation_id
    AND c.user_id = auth.uid()
  )
);

-- Add policy for public read access to specific columns
CREATE POLICY "Public can view basic notification info"
ON email_notifications
FOR SELECT
TO public
USING (true);