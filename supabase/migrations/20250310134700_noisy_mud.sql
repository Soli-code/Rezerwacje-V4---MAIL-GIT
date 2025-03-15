/*
  # Add email notifications tracking

  1. New Tables
    - `email_notifications`
      - `id` (uuid, primary key)
      - `reservation_id` (uuid, foreign key to reservations)
      - `recipient` (text) - email address
      - `type` (text) - customer/admin
      - `status` (text) - sent/failed
      - `error` (text) - error message if failed
      - `sent_at` (timestamp)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `email_notifications` table
    - Add policies for admins to view all notifications
    - Add policies for customers to view their own notifications
*/

-- Create email notifications table
CREATE TABLE IF NOT EXISTS email_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  recipient text NOT NULL,
  type text NOT NULL CHECK (type IN ('customer', 'admin')),
  status text NOT NULL CHECK (status IN ('sent', 'failed')),
  error text,
  sent_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE email_notifications ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Admins can view all notifications"
  ON email_notifications
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Customers can view their own notifications"
  ON email_notifications
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM reservations r
    JOIN customers c ON r.customer_id = c.id
    WHERE r.id = email_notifications.reservation_id
    AND c.user_id = auth.uid()
  ));