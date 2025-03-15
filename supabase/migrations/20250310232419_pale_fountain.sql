/*
  # System obsługi emaili

  1. Nowe tabele
    - email_templates: szablony emaili
    - email_template_variables: zmienne używane w szablonach
    - email_logs: logi wysyłki emaili
    - email_retry_settings: ustawienia ponownych prób
    - smtp_settings: konfiguracja SMTP

  2. Bezpieczeństwo
    - RLS włączone dla wszystkich tabel
    - Polityki dostępu dla administratorów
    - Polityki dostępu dla systemu

  3. Optymalizacja
    - Indeksy dla często używanych kolumn
    - Triggery dla automatyzacji procesów
*/

-- Usuń istniejące tabele jeśli istnieją
DROP TABLE IF EXISTS email_logs CASCADE;
DROP TABLE IF EXISTS email_template_variables CASCADE;
DROP TABLE IF EXISTS email_templates CASCADE;
DROP TABLE IF EXISTS email_retry_settings CASCADE;
DROP TABLE IF EXISTS smtp_settings CASCADE;

-- Utwórz tabelę email_templates
CREATE TABLE email_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  variables jsonb DEFAULT '{}',
  active boolean DEFAULT true,
  version integer DEFAULT 1,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(name)
);

-- Utwórz tabelę email_template_variables
CREATE TABLE email_template_variables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id) ON DELETE CASCADE,
  variable_name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(template_id, variable_name)
);

-- Utwórz tabelę email_logs
CREATE TABLE email_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid REFERENCES email_templates(id),
  reservation_id uuid REFERENCES reservations(id),
  recipient text NOT NULL,
  subject text NOT NULL,
  content text NOT NULL,
  status text NOT NULL CHECK (status IN ('pending', 'sent', 'failed', 'delivered', 'bounced')),
  error_message text,
  sent_at timestamptz DEFAULT now(),
  smtp_response text,
  retry_count integer DEFAULT 0,
  next_retry_at timestamptz,
  delivery_attempts integer DEFAULT 0,
  last_error text,
  headers jsonb,
  delivered_at timestamptz,
  template_variables jsonb,
  error_details jsonb,
  metadata jsonb
);

-- Utwórz tabelę email_retry_settings
CREATE TABLE email_retry_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  max_retries integer NOT NULL DEFAULT 3,
  retry_delay_minutes integer NOT NULL DEFAULT 5,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Utwórz tabelę smtp_settings
CREATE TABLE smtp_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host text NOT NULL,
  port integer NOT NULL,
  username text NOT NULL,
  password text NOT NULL,
  from_email text NOT NULL,
  from_name text NOT NULL,
  encryption text NOT NULL DEFAULT 'tls',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_test_result jsonb,
  last_test_date timestamptz
);

-- Włącz RLS dla wszystkich tabel
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_template_variables ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_retry_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE smtp_settings ENABLE ROW LEVEL SECURITY;

-- Dodaj polityki dostępu
CREATE POLICY "Admins can manage email templates"
  ON email_templates FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage template variables"
  ON email_template_variables FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can view email logs"
  ON email_logs FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Public can insert email logs"
  ON email_logs FOR INSERT TO public
  WITH CHECK (true);

CREATE POLICY "System can update email logs"
  ON email_logs FOR UPDATE TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Admins can manage retry settings"
  ON email_retry_settings FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Admins can manage SMTP settings"
  ON smtp_settings FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Dodaj indeksy dla optymalizacji
CREATE INDEX idx_email_logs_recipient_status ON email_logs (recipient, status);
CREATE INDEX idx_email_logs_sent_at ON email_logs (sent_at);
CREATE INDEX idx_email_logs_status ON email_logs (status);

-- Dodaj funkcję do obsługi ponownych prób wysyłki
CREATE OR REPLACE FUNCTION handle_email_retry()
RETURNS trigger AS $$
BEGIN
  -- Pobierz ustawienia ponownych prób
  WITH settings AS (
    SELECT max_retries, retry_delay_minutes
    FROM email_retry_settings
    LIMIT 1
  )
  SELECT
    CASE
      WHEN NEW.retry_count >= (SELECT max_retries FROM settings)
        THEN NULL
      ELSE now() + ((SELECT retry_delay_minutes FROM settings) * interval '1 minute')
    END
  INTO NEW.next_retry_at;
  
  NEW.retry_count := NEW.retry_count + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger dla obsługi ponownych prób
CREATE TRIGGER handle_email_retry_trigger
  BEFORE UPDATE OF status ON email_logs
  FOR EACH ROW
  WHEN (NEW.status = 'failed')
  EXECUTE FUNCTION handle_email_retry();

-- Dodaj funkcję do monitorowania dostępu do SMTP
CREATE OR REPLACE FUNCTION log_smtp_access()
RETURNS trigger AS $$
BEGIN
  INSERT INTO email_logs (
    recipient,
    subject,
    content,
    status,
    metadata
  ) VALUES (
    'admin@solrent.pl',
    'SMTP Settings Modified',
    'SMTP settings were modified',
    'sent',
    jsonb_build_object(
      'operation', TG_OP,
      'timestamp', now()
    )
  );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger dla monitorowania SMTP
CREATE TRIGGER monitor_smtp_access
  AFTER INSERT OR UPDATE OR DELETE ON smtp_settings
  FOR EACH STATEMENT
  EXECUTE FUNCTION log_smtp_access();

-- Dodaj funkcję do sprawdzania liczby konfiguracji SMTP
CREATE OR REPLACE FUNCTION check_smtp_settings_count()
RETURNS trigger AS $$
BEGIN
  IF (SELECT COUNT(*) FROM smtp_settings) >= 1 THEN
    RAISE EXCEPTION 'Only one SMTP configuration is allowed';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger dla ograniczenia liczby konfiguracji SMTP
CREATE TRIGGER ensure_single_smtp_config
  BEFORE INSERT ON smtp_settings
  FOR EACH ROW
  EXECUTE FUNCTION check_smtp_settings_count();

-- Dodaj domyślny szablon emaila dla nowej rezerwacji
INSERT INTO email_templates (name, subject, content)
VALUES (
  'new_reservation',
  'Potwierdzenie rezerwacji sprzętu - SOLRENT',
  '<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            line-height: 1.6; 
            color: #333;
            margin: 0;
            padding: 0;
        }
        .container { 
            max-width: 600px; 
            margin: 0 auto; 
            padding: 20px;
        }
        .header { 
            text-align: center;
            margin-bottom: 30px;
            background-color: #FF6B00;
            padding: 20px;
            color: white;
        }
        .content {
            background: #f9f9f9;
            padding: 20px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            font-size: 12px;
            color: #666;
            padding: 20px;
            background: #f1f1f1;
        }
        .important {
            color: #FF6B00;
            font-weight: bold;
        }
        .details {
            background: white;
            padding: 15px;
            border-radius: 5px;
            margin: 15px 0;
        }
        @media only screen and (max-width: 600px) {
            .container {
                width: 100% !important;
                padding: 10px !important;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>SOLRENT</h1>
            <h2>Potwierdzenie rezerwacji</h2>
        </div>
        
        <div class="content">
            <p>Witaj {{first_name}} {{last_name}},</p>
            
            <p>Dziękujemy za dokonanie rezerwacji sprzętu w SOLRENT. Poniżej znajdziesz szczegóły swojej rezerwacji:</p>
            
            <div class="details">
                <h3>Szczegóły rezerwacji:</h3>
                <ul>
                    <li>Data rozpoczęcia: {{start_date}} {{start_time}}</li>
                    <li>Data zakończenia: {{end_date}} {{end_time}}</li>
                    <li>Zarezerwowany sprzęt: {{equipment_list}}</li>
                    <li>Całkowity koszt: {{total_price}} zł</li>
                    <li>Wymagana kaucja: {{deposit_amount}} zł</li>
                </ul>
            </div>

            <div class="important">
                <p>Ważne informacje:</p>
                <ul>
                    <li>Odbiór i zwrot sprzętu możliwy jest tylko w godzinach otwarcia wypożyczalni:
                        <ul>
                            <li>Poniedziałek - Piątek: 8:00 - 16:00</li>
                            <li>Sobota: 8:00 - 13:00</li>
                            <li>Niedziela: nieczynne</li>
                        </ul>
                    </li>
                    <li>Kaucja jest pobierana przed rozpoczęciem wypożyczenia</li>
                    <li>Prosimy o przygotowanie dokumentu tożsamości przy odbiorze sprzętu</li>
                </ul>
            </div>

            <p>W razie pytań lub potrzeby zmiany rezerwacji, prosimy o kontakt:</p>
            <ul>
                <li>Telefon: 694 171 171</li>
                <li>Email: biuro@solrent.pl</li>
            </ul>
        </div>
        
        <div class="footer">
            <p>SOLRENT - Wypożyczalnia sprzętu budowlanego i ogrodniczego</p>
            <p>ul. Jęczmienna 4, 44-190 Knurów</p>
            <p>Ta wiadomość została wygenerowana automatycznie, prosimy na nią nie odpowiadać.</p>
        </div>
    </div>
</body>
</html>'
);