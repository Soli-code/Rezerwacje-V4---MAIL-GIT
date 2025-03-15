/*
  # Configure email templates and SMTP settings
  
  1. New Tables
    - `email_templates` - Stores email templates for different types of notifications
    - `email_logs` - Tracks all sent emails
  
  2. Functions
    - `handle_new_reservation_email()` - Sends confirmation email when new reservation is created
  
  3. Security
    - RLS policies to protect email templates and logs
*/

-- Create email templates table if not exists
CREATE TABLE IF NOT EXISTS email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create email logs table if not exists
CREATE TABLE IF NOT EXISTS email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id),
  reservation_id uuid REFERENCES reservations(id),
  recipient text NOT NULL,
  subject text NOT NULL,
  body text NOT NULL,
  status text NOT NULL,
  error_message text,
  sent_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Only admins can manage email templates" ON email_templates;
DROP POLICY IF EXISTS "Only admins can view email logs" ON email_logs;

-- Create new policies
CREATE POLICY "Only admins can manage email templates" ON email_templates
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));

CREATE POLICY "Only admins can view email logs" ON email_logs
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));

-- Drop existing function and trigger if they exist
DROP TRIGGER IF EXISTS send_new_reservation_email ON reservations;
DROP FUNCTION IF EXISTS handle_new_reservation_email();

-- Create function to handle sending new reservation confirmation
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_customer_email text;
  v_template email_templates;
  v_body text;
  v_equipment_list text;
BEGIN
  -- Get customer email
  SELECT email INTO v_customer_email
  FROM customers
  WHERE id = NEW.customer_id;

  -- Get confirmation email template
  SELECT * INTO v_template
  FROM email_templates
  WHERE name = 'reservation_confirmation'
  LIMIT 1;

  -- If template exists, send email
  IF FOUND THEN
    -- Get equipment list
    SELECT string_agg(e.name || ' (x' || ri.quantity || ')', E'\n')
    INTO v_equipment_list
    FROM reservation_items ri
    JOIN equipment e ON e.id = ri.equipment_id
    WHERE ri.reservation_id = NEW.id;

    -- Prepare email body with variables
    v_body := replace(
      replace(
        replace(
          replace(v_template.body, 
            '{{start_date}}', to_char(NEW.start_date, 'DD.MM.YYYY HH24:MI')
          ),
          '{{end_date}}', to_char(NEW.end_date, 'DD.MM.YYYY HH24:MI')
        ),
        '{{total_price}}', NEW.total_price::text
      ),
      '{{equipment_list}}', v_equipment_list
    );

    -- Log email
    INSERT INTO email_logs (
      template_id,
      reservation_id,
      recipient,
      subject,
      body,
      status
    ) VALUES (
      v_template.id,
      NEW.id,
      v_customer_email,
      v_template.subject,
      v_body,
      'pending'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new reservations
CREATE TRIGGER send_new_reservation_email
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_reservation_email();

-- Delete existing templates with the same name
DELETE FROM email_templates WHERE name = 'reservation_confirmation';

-- Insert default email templates
INSERT INTO email_templates (name, subject, body) VALUES
(
  'reservation_confirmation',
  'Potwierdzenie rezerwacji - SOLRENT',
  '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { text-align: center; margin-bottom: 30px; }
    .content { background: #f9f9f9; padding: 20px; border-radius: 5px; }
    .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Potwierdzenie rezerwacji</h1>
    </div>
    <div class="content">
      <p>Dziękujemy za dokonanie rezerwacji w SOLRENT!</p>
      
      <h3>Szczegóły rezerwacji:</h3>
      <p>Data rozpoczęcia: {{start_date}}</p>
      <p>Data zakończenia: {{end_date}}</p>
      
      <h3>Zarezerwowany sprzęt:</h3>
      <pre>{{equipment_list}}</pre>
      
      <p>Całkowity koszt: {{total_price}} zł</p>
      
      <h3>Ważne informacje:</h3>
      <ul>
        <li>Prosimy o odbiór sprzętu o ustalonej godzinie</li>
        <li>Wymagany dokument tożsamości</li>
        <li>Kaucja płatna przy odbiorze</li>
      </ul>
      
      <p>W razie pytań prosimy o kontakt:</p>
      <p>Tel: 694 171 171</p>
      <p>Email: biuro@solrent.pl</p>
    </div>
    <div class="footer">
      <p>SOLRENT - Wypożyczalnia sprzętu budowlanego i ogrodniczego</p>
      <p>ul. Jęczmienna 4, 44-190 Knurów</p>
    </div>
  </div>
</body>
</html>'
);