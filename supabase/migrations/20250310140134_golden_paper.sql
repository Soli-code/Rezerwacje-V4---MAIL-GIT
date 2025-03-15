/*
  # Email Templates System

  1. New Tables
    - `email_templates`
      - `id` (uuid, primary key)
      - `name` (text) - nazwa szablonu
      - `subject` (text) - temat emaila
      - `content` (text) - treść w formacie Handlebars
      - `type` (text) - typ szablonu (customer/admin)
      - `active` (boolean) - czy szablon jest aktywny
      - `variables` (jsonb) - lista zmiennych używanych w szablonie
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
      - `version` (integer) - wersja szablonu

  2. Security
    - Enable RLS
    - Add policies for admin access
*/

-- Create email templates table
CREATE TABLE IF NOT EXISTS email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  type text NOT NULL,
  active boolean DEFAULT true,
  variables jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  version integer DEFAULT 1,
  CONSTRAINT valid_template_type CHECK (type IN ('customer', 'admin'))
);

-- Enable RLS
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Admins can manage templates"
  ON email_templates
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Add template versioning function
CREATE OR REPLACE FUNCTION increment_template_version()
RETURNS TRIGGER AS $$
BEGIN
  IF (OLD.content != NEW.content OR OLD.subject != NEW.subject) THEN
    NEW.version = OLD.version + 1;
    NEW.updated_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for version control
CREATE TRIGGER template_version_trigger
  BEFORE UPDATE ON email_templates
  FOR EACH ROW
  EXECUTE FUNCTION increment_template_version();

-- Insert default templates
INSERT INTO email_templates (name, subject, content, type, variables) VALUES
(
  'reservation_confirmation_customer',
  'Potwierdzenie rezerwacji sprzętu - SOLRENT',
  E'Witaj {{firstName}} {{lastName}},\n\n' ||
  E'Dziękujemy za dokonanie rezerwacji w SOLRENT. Poniżej znajdziesz szczegóły:\n\n' ||
  E'Data rozpoczęcia: {{startDate}} {{startTime}}\n' ||
  E'Data zakończenia: {{endDate}} {{endTime}}\n' ||
  E'Liczba dni: {{days}}\n\n' ||
  E'Zarezerwowany sprzęt:\n' ||
  E'{{#each equipment}}\n' ||
  E'- {{name}} ({{quantity}} szt.) - {{price}} zł/dzień\n' ||
  E'{{/each}}\n\n' ||
  E'Całkowity koszt: {{totalPrice}} zł\n' ||
  E'Wymagana kaucja: {{deposit}} zł\n\n' ||
  E'Przypominamy o konieczności wpłacenia kaucji przed rozpoczęciem wynajmu.\n\n' ||
  E'Pozdrawiamy,\n' ||
  E'Zespół SOLRENT',
  'customer',
  '{"firstName": "string", "lastName": "string", "startDate": "string", "endDate": "string", "startTime": "string", "endTime": "string", "days": "number", "equipment": "array", "totalPrice": "number", "deposit": "number"}'
),
(
  'reservation_notification_admin',
  'Nowa rezerwacja sprzętu',
  E'Nowa rezerwacja w systemie\n\n' ||
  E'Klient: {{firstName}} {{lastName}}\n' ||
  E'Email: {{email}}\n' ||
  E'Telefon: {{phone}}\n\n' ||
  E'Data rozpoczęcia: {{startDate}} {{startTime}}\n' ||
  E'Data zakończenia: {{endDate}} {{endTime}}\n' ||
  E'Liczba dni: {{days}}\n\n' ||
  E'Zarezerwowany sprzęt:\n' ||
  E'{{#each equipment}}\n' ||
  E'- {{name}} ({{quantity}} szt.) - {{price}} zł/dzień\n' ||
  E'{{/each}}\n\n' ||
  E'Całkowity koszt: {{totalPrice}} zł\n' ||
  E'Kaucja: {{deposit}} zł\n\n' ||
  E'{{#if companyName}}\n' ||
  E'Dane firmowe:\n' ||
  E'Nazwa: {{companyName}}\n' ||
  E'NIP: {{companyNip}}\n' ||
  E'Adres: {{companyStreet}}, {{companyPostalCode}} {{companyCity}}\n' ||
  E'{{/if}}\n\n' ||
  E'{{#if comment}}\n' ||
  E'Komentarz klienta:\n' ||
  E'{{comment}}\n' ||
  E'{{/if}}',
  'admin',
  '{"firstName": "string", "lastName": "string", "email": "string", "phone": "string", "startDate": "string", "endDate": "string", "startTime": "string", "endTime": "string", "days": "number", "equipment": "array", "totalPrice": "number", "deposit": "number", "companyName": "string?", "companyNip": "string?", "companyStreet": "string?", "companyPostalCode": "string?", "companyCity": "string?", "comment": "string?"}'
);