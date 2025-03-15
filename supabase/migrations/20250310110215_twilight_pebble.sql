/*
  # Update new reservation email template

  1. Changes
    - Updates existing new_reservation email template with improved layout
    - Updates template variables if needed
    - Uses safe update approach with existence check

  2. Template Content
    - Professional email layout
    - Includes all necessary reservation information
    - Supports both regular and company customer data
*/

DO $$ 
BEGIN
  -- Update existing template
  UPDATE email_templates
  SET 
    subject = 'Potwierdzenie rezerwacji - SOLRENT',
    body = jsonb_build_object(
      'html', '
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #FF6B00; margin-bottom: 30px;">Potwierdzenie rezerwacji</h1>
        
        <p>Dziękujemy za dokonanie rezerwacji w wypożyczalni SOLRENT!</p>
        
        <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h2 style="color: #333; font-size: 18px; margin-bottom: 15px;">Szczegóły rezerwacji:</h2>
          <p><strong>Data rozpoczęcia:</strong> {{start_date}} {{start_time}}</p>
          <p><strong>Data zakończenia:</strong> {{end_date}} {{end_time}}</p>
          <p><strong>Zarezerwowany sprzęt:</strong></p>
          <ul style="list-style-type: none; padding-left: 0;">
            {{#each equipment}}
            <li style="margin-bottom: 10px;">
              - {{name}} ({{quantity}} szt.) - {{price}} zł/dzień
              {{#if deposit}}
              <br>
              <span style="color: #FF6B00;">Kaucja: {{deposit}} zł</span>
              {{/if}}
            </li>
            {{/each}}
          </ul>
          <p><strong>Całkowity koszt wypożyczenia:</strong> {{total_price}} zł</p>
          <p><strong>Całkowita kaucja:</strong> {{total_deposit}} zł</p>
        </div>

        <div style="background-color: #fff3e0; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h2 style="color: #333; font-size: 18px; margin-bottom: 15px;">Dane kontaktowe:</h2>
          <p><strong>Imię i nazwisko:</strong> {{customer_name}}</p>
          <p><strong>Email:</strong> {{customer_email}}</p>
          <p><strong>Telefon:</strong> {{customer_phone}}</p>
          {{#if company_name}}
          <div style="margin-top: 15px;">
            <p><strong>Dane firmy:</strong></p>
            <p>{{company_name}}</p>
            <p>NIP: {{company_nip}}</p>
            <p>{{company_address}}</p>
          </div>
          {{/if}}
        </div>

        <div style="background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 20px 0;">
          <h2 style="color: #333; font-size: 18px; margin-bottom: 15px;">Ważne informacje:</h2>
          <ul style="padding-left: 20px;">
            <li>Prosimy o punktualne przybycie w celu odbioru sprzętu</li>
            <li>Wymagany dokument tożsamości przy odbiorze</li>
            <li>Kaucja jest pobierana przed rozpoczęciem wypożyczenia</li>
            <li>Płatność za wypożyczenie przy odbiorze sprzętu</li>
          </ul>
        </div>

        <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
          <p style="color: #666;">
            W razie pytań prosimy o kontakt:<br>
            Tel: 694 171 171<br>
            Email: kontakt@solrent.pl
          </p>
        </div>
      </div>
      '
    )
  WHERE name = 'new_reservation';

  -- Update or insert template variables
  WITH template_id AS (
    SELECT id FROM email_templates WHERE name = 'new_reservation'
  ),
  vars AS (
    SELECT * FROM (VALUES 
      ('start_date', 'Data rozpoczęcia rezerwacji'),
      ('end_date', 'Data zakończenia rezerwacji'),
      ('start_time', 'Godzina rozpoczęcia'),
      ('end_time', 'Godzina zakończenia'),
      ('equipment', 'Lista zarezerwowanego sprzętu'),
      ('total_price', 'Całkowity koszt wypożyczenia'),
      ('total_deposit', 'Całkowita kwota kaucji'),
      ('customer_name', 'Imię i nazwisko klienta'),
      ('customer_email', 'Adres email klienta'),
      ('customer_phone', 'Numer telefonu klienta'),
      ('company_name', 'Nazwa firmy (opcjonalne)'),
      ('company_nip', 'NIP firmy (opcjonalne)'),
      ('company_address', 'Adres firmy (opcjonalne)')
    ) AS t(variable_name, description)
  )
  INSERT INTO email_template_variables (template_id, variable_name, description)
  SELECT 
    template_id.id,
    vars.variable_name,
    vars.description
  FROM template_id, vars
  ON CONFLICT (template_id, variable_name) 
  DO UPDATE SET description = EXCLUDED.description;
END $$;