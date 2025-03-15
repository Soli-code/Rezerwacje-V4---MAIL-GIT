/*
  # Setup email system
  
  1. Changes
    - Add missing columns to email_logs table
    - Add email template variables table
    - Add default templates with variables
    - Update email handling function
  
  2. Security
    - Enable RLS on all new tables
    - Add policies for admin access
*/

-- Add template variables table
CREATE TABLE IF NOT EXISTS email_template_variables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id) ON DELETE CASCADE,
  variable_name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Add missing columns to email_logs
ALTER TABLE email_logs 
ADD COLUMN IF NOT EXISTS smtp_response text,
ADD COLUMN IF NOT EXISTS retry_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS next_retry_at timestamptz;

-- Enable RLS
ALTER TABLE email_template_variables ENABLE ROW LEVEL SECURITY;

-- Add admin policies
CREATE POLICY "Admins can manage template variables" ON email_template_variables
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_admin = true
  ));

-- Update email handling function
CREATE OR REPLACE FUNCTION handle_new_reservation_email()
RETURNS TRIGGER AS $$
DECLARE
  v_customer_email text;
  v_customer_name text;
  v_template email_templates;
  v_body text;
  v_equipment_list text;
  v_total_deposit numeric;
BEGIN
  -- Get customer details
  SELECT 
    email,
    first_name || ' ' || last_name INTO v_customer_email, v_customer_name
  FROM customers
  WHERE id = NEW.customer_id;

  -- Get confirmation email template
  SELECT * INTO v_template
  FROM email_templates
  WHERE name = 'reservation_confirmation'
  LIMIT 1;

  -- If template exists, prepare email
  IF FOUND THEN
    -- Calculate total deposit
    SELECT COALESCE(SUM(ri.deposit * ri.quantity), 0)
    INTO v_total_deposit
    FROM reservation_items ri
    WHERE ri.reservation_id = NEW.id;

    -- Get equipment list with prices
    SELECT string_agg(
      e.name || ' (x' || ri.quantity || ') - ' || 
      (ri.price_per_day * ri.quantity)::text || ' zł/dzień' ||
      CASE WHEN ri.deposit > 0 
        THEN E'\nKaucja: ' || (ri.deposit * ri.quantity)::text || ' zł'
        ELSE ''
      END,
      E'\n'
    )
    INTO v_equipment_list
    FROM reservation_items ri
    JOIN equipment e ON e.id = ri.equipment_id
    WHERE ri.reservation_id = NEW.id;

    -- Prepare email body with variables
    v_body := replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  v_template.body,
                  '{{customer_name}}', v_customer_name
                ),
                '{{reservation_id}}', NEW.id::text
              ),
              '{{start_date}}', to_char(NEW.start_date, 'DD.MM.YYYY')
            ),
            '{{start_time}}', NEW.start_time::text
          ),
          '{{end_date}}', to_char(NEW.end_date, 'DD.MM.YYYY')
        ),
        '{{end_time}}', NEW.end_time::text
      ),
      '{{equipment_list}}', v_equipment_list
    );
    
    v_body := replace(
      replace(
        v_body,
        '{{total_price}}', NEW.total_price::text
      ),
      '{{total_deposit}}', v_total_deposit::text
    );

    -- Log email
    INSERT INTO email_logs (
      template_id,
      reservation_id,
      recipient,
      subject,
      body,
      status,
      retry_count
    ) VALUES (
      v_template.id,
      NEW.id,
      v_customer_email,
      replace(v_template.subject, '{{reservation_id}}', NEW.id::text),
      v_body,
      'pending',
      0
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update existing template with more variables
UPDATE email_templates 
SET subject = 'Potwierdzenie rezerwacji #{{reservation_id}} - SOLRENT',
    body = '<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { text-align: center; margin-bottom: 30px; }
    .content { background: #f9f9f9; padding: 20px; border-radius: 5px; }
    .details { margin: 20px 0; padding: 15px; background: #fff; border-radius: 5px; }
    .equipment { margin: 10px 0; padding: 10px; background: #f5f5f5; border-radius: 3px; }
    .important { color: #ff6b00; font-weight: bold; }
    .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Potwierdzenie rezerwacji #{{reservation_id}}</h1>
    </div>
    <div class="content">
      <p>Szanowny/a {{customer_name}},</p>
      <p>Dziękujemy za dokonanie rezerwacji w SOLRENT! Poniżej znajdziesz szczegóły swojej rezerwacji.</p>
      
      <div class="details">
        <h3>Szczegóły rezerwacji:</h3>
        <p>Data rozpoczęcia: {{start_date}} {{start_time}}</p>
        <p>Data zakończenia: {{end_date}} {{end_time}}</p>
      </div>
      
      <div class="equipment">
        <h3>Zarezerwowany sprzęt:</h3>
        <pre>{{equipment_list}}</pre>
        
        <p>Całkowity koszt wypożyczenia: <strong>{{total_price}} zł</strong></p>
        <p>Wymagana kaucja: <strong>{{total_deposit}} zł</strong></p>
      </div>
      
      <div class="details">
        <h3>Ważne informacje:</h3>
        <ul>
          <li>Prosimy o punktualny odbiór sprzętu o ustalonej godzinie</li>
          <li>Wymagany dokument tożsamości przy odbiorze</li>
          <li class="important">Kaucja płatna przy odbiorze sprzętu</li>
          <li>Sprzęt wydawany jest po podpisaniu umowy najmu</li>
        </ul>
      </div>
      
      <div class="details">
        <h3>Kontakt:</h3>
        <p>W razie pytań prosimy o kontakt:</p>
        <p>Tel: 694 171 171</p>
        <p>Email: biuro@solrent.pl</p>
      </div>
    </div>
    <div class="footer">
      <p>SOLRENT - Wypożyczalnia sprzętu budowlanego i ogrodniczego</p>
      <p>ul. Jęczmienna 4, 44-190 Knurów</p>
      <p><small>Ta wiadomość została wygenerowana automatycznie, prosimy na nią nie odpowiadać.</small></p>
    </div>
  </div>
</body>
</html>'
WHERE name = 'reservation_confirmation';

-- Add template variables
INSERT INTO email_template_variables (template_id, variable_name, description)
SELECT 
  id,
  unnest(ARRAY[
    'customer_name',
    'reservation_id',
    'start_date',
    'start_time',
    'end_date',
    'end_time',
    'equipment_list',
    'total_price',
    'total_deposit'
  ]),
  unnest(ARRAY[
    'Imię i nazwisko klienta',
    'Numer rezerwacji',
    'Data rozpoczęcia',
    'Godzina rozpoczęcia',
    'Data zakończenia',
    'Godzina zakończenia',
    'Lista sprzętu z cenami',
    'Całkowity koszt wypożyczenia',
    'Całkowita kwota kaucji'
  ])
FROM email_templates
WHERE name = 'reservation_confirmation';