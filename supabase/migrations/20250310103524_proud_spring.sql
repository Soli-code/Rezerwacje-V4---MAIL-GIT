/*
  # Update Email Templates

  1. Updates
    - Safe update of existing email templates
    - Add template variables if missing
    
  2. Changes
    - Uses DO block to check existence before inserting/updating
    - Preserves existing templates while updating content
*/

DO $$ 
BEGIN
  -- Update or insert new_reservation template
  IF EXISTS (SELECT 1 FROM email_templates WHERE name = 'new_reservation') THEN
    UPDATE email_templates SET
      subject = 'Potwierdzenie rezerwacji - SOLRENT',
      body = jsonb_build_object(
        'text', 'Dziękujemy za dokonanie rezerwacji w SOLRENT!\n\nSzczegóły rezerwacji:\nImię i nazwisko: {{customer_name}}\nData rozpoczęcia: {{start_date}}\nData zakończenia: {{end_date}}\n\nWybrany sprzęt:\n{{equipment_list}}\n\nCałkowity koszt: {{total_price}} zł\nKaucja: {{deposit_amount}} zł\n\nProsimy o odbiór sprzętu w naszej siedzibie:\nKnurów 44-190\nul. Jęczmienna 4\n\nW razie pytań prosimy o kontakt:\nTel: 694 171 171\nEmail: biuro@solrent.pl\n\nPozdrawiamy,\nZespół SOLRENT',
        'html', '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #FF6B00;">Potwierdzenie rezerwacji - SOLRENT</h2>
          <p>Dziękujemy za dokonanie rezerwacji w SOLRENT!</p>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0;">Szczegóły rezerwacji:</h3>
            <p><strong>Imię i nazwisko:</strong> {{customer_name}}</p>
            <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
            <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Wybrany sprzęt:</h3>
            {{equipment_list}}
          </div>
          <div style="background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>Całkowity koszt:</strong> {{total_price}} zł</p>
            <p><strong>Kaucja:</strong> {{deposit_amount}} zł</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Odbiór sprzętu:</h3>
            <p>Knurów 44-190<br>ul. Jęczmienna 4</p>
          </div>
          <div style="border-top: 2px solid #FF6B00; padding-top: 20px; margin-top: 20px;">
            <p><strong>Kontakt:</strong></p>
            <p>Tel: 694 171 171<br>Email: biuro@solrent.pl</p>
          </div>
          <p style="color: #666; font-size: 12px; margin-top: 30px;">
            Pozdrawiamy,<br>Zespół SOLRENT
          </p>
        </div>'
      )
    WHERE name = 'new_reservation';
  ELSE
    INSERT INTO email_templates (name, subject, body)
    VALUES (
      'new_reservation',
      'Potwierdzenie rezerwacji - SOLRENT',
      jsonb_build_object(
        'text', 'Dziękujemy za dokonanie rezerwacji w SOLRENT!\n\nSzczegóły rezerwacji:\nImię i nazwisko: {{customer_name}}\nData rozpoczęcia: {{start_date}}\nData zakończenia: {{end_date}}\n\nWybrany sprzęt:\n{{equipment_list}}\n\nCałkowity koszt: {{total_price}} zł\nKaucja: {{deposit_amount}} zł\n\nProsimy o odbiór sprzętu w naszej siedzibie:\nKnurów 44-190\nul. Jęczmienna 4\n\nW razie pytań prosimy o kontakt:\nTel: 694 171 171\nEmail: biuro@solrent.pl\n\nPozdrawiamy,\nZespół SOLRENT',
        'html', '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #FF6B00;">Potwierdzenie rezerwacji - SOLRENT</h2>
          <p>Dziękujemy za dokonanie rezerwacji w SOLRENT!</p>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0;">Szczegóły rezerwacji:</h3>
            <p><strong>Imię i nazwisko:</strong> {{customer_name}}</p>
            <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
            <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Wybrany sprzęt:</h3>
            {{equipment_list}}
          </div>
          <div style="background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>Całkowity koszt:</strong> {{total_price}} zł</p>
            <p><strong>Kaucja:</strong> {{deposit_amount}} zł</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Odbiór sprzętu:</h3>
            <p>Knurów 44-190<br>ul. Jęczmienna 4</p>
          </div>
          <div style="border-top: 2px solid #FF6B00; padding-top: 20px; margin-top: 20px;">
            <p><strong>Kontakt:</strong></p>
            <p>Tel: 694 171 171<br>Email: biuro@solrent.pl</p>
          </div>
          <p style="color: #666; font-size: 12px; margin-top: 30px;">
            Pozdrawiamy,<br>Zespół SOLRENT
          </p>
        </div>'
      )
    );
  END IF;

  -- Update or insert reservation_status_update template
  IF EXISTS (SELECT 1 FROM email_templates WHERE name = 'reservation_status_update') THEN
    UPDATE email_templates SET
      subject = 'Aktualizacja statusu rezerwacji - SOLRENT',
      body = jsonb_build_object(
        'text', 'Status Twojej rezerwacji został zaktualizowany.\n\nNowy status: {{new_status}}\n\nSzczegóły rezerwacji:\nNumer rezerwacji: {{reservation_id}}\nData rozpoczęcia: {{start_date}}\nData zakończenia: {{end_date}}\n\nW razie pytań prosimy o kontakt:\nTel: 694 171 171\nEmail: biuro@solrent.pl\n\nPozdrawiamy,\nZespół SOLRENT',
        'html', '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #FF6B00;">Aktualizacja statusu rezerwacji</h2>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0;">Nowy status: {{new_status}}</h3>
            <p><strong>Numer rezerwacji:</strong> {{reservation_id}}</p>
            <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
            <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          </div>
          <div style="border-top: 2px solid #FF6B00; padding-top: 20px; margin-top: 20px;">
            <p><strong>Kontakt:</strong></p>
            <p>Tel: 694 171 171<br>Email: biuro@solrent.pl</p>
          </div>
          <p style="color: #666; font-size: 12px; margin-top: 30px;">
            Pozdrawiamy,<br>Zespół SOLRENT
          </p>
        </div>'
      )
    WHERE name = 'reservation_status_update';
  ELSE
    INSERT INTO email_templates (name, subject, body)
    VALUES (
      'reservation_status_update',
      'Aktualizacja statusu rezerwacji - SOLRENT',
      jsonb_build_object(
        'text', 'Status Twojej rezerwacji został zaktualizowany.\n\nNowy status: {{new_status}}\n\nSzczegóły rezerwacji:\nNumer rezerwacji: {{reservation_id}}\nData rozpoczęcia: {{start_date}}\nData zakończenia: {{end_date}}\n\nW razie pytań prosimy o kontakt:\nTel: 694 171 171\nEmail: biuro@solrent.pl\n\nPozdrawiamy,\nZespół SOLRENT',
        'html', '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #FF6B00;">Aktualizacja statusu rezerwacji</h2>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0;">Nowy status: {{new_status}}</h3>
            <p><strong>Numer rezerwacji:</strong> {{reservation_id}}</p>
            <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
            <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          </div>
          <div style="border-top: 2px solid #FF6B00; padding-top: 20px; margin-top: 20px;">
            <p><strong>Kontakt:</strong></p>
            <p>Tel: 694 171 171<br>Email: biuro@solrent.pl</p>
          </div>
          <p style="color: #666; font-size: 12px; margin-top: 30px;">
            Pozdrawiamy,<br>Zespół SOLRENT
          </p>
        </div>'
      )
    );
  END IF;

  -- Update or insert admin_notification template
  IF EXISTS (SELECT 1 FROM email_templates WHERE name = 'admin_notification') THEN
    UPDATE email_templates SET
      subject = 'Nowa rezerwacja - SOLRENT',
      body = jsonb_build_object(
        'text', 'Otrzymano nową rezerwację!\n\nDane klienta:\nImię i nazwisko: {{customer_name}}\nEmail: {{customer_email}}\nTelefon: {{customer_phone}}\n\nSzczegóły rezerwacji:\nData rozpoczęcia: {{start_date}}\nData zakończenia: {{end_date}}\n\nWybrany sprzęt:\n{{equipment_list}}\n\nCałkowity koszt: {{total_price}} zł\nKaucja: {{deposit_amount}} zł',
        'html', '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #FF6B00;">Nowa rezerwacja!</h2>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0;">Dane klienta:</h3>
            <p><strong>Imię i nazwisko:</strong> {{customer_name}}</p>
            <p><strong>Email:</strong> {{customer_email}}</p>
            <p><strong>Telefon:</strong> {{customer_phone}}</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Szczegóły rezerwacji:</h3>
            <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
            <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Wybrany sprzęt:</h3>
            {{equipment_list}}
          </div>
          <div style="background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>Całkowity koszt:</strong> {{total_price}} zł</p>
            <p><strong>Kaucja:</strong> {{deposit_amount}} zł</p>
          </div>
        </div>'
      )
    WHERE name = 'admin_notification';
  ELSE
    INSERT INTO email_templates (name, subject, body)
    VALUES (
      'admin_notification',
      'Nowa rezerwacja - SOLRENT',
      jsonb_build_object(
        'text', 'Otrzymano nową rezerwację!\n\nDane klienta:\nImię i nazwisko: {{customer_name}}\nEmail: {{customer_email}}\nTelefon: {{customer_phone}}\n\nSzczegóły rezerwacji:\nData rozpoczęcia: {{start_date}}\nData zakończenia: {{end_date}}\n\nWybrany sprzęt:\n{{equipment_list}}\n\nCałkowity koszt: {{total_price}} zł\nKaucja: {{deposit_amount}} zł',
        'html', '<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #FF6B00;">Nowa rezerwacja!</h2>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3 style="margin-top: 0;">Dane klienta:</h3>
            <p><strong>Imię i nazwisko:</strong> {{customer_name}}</p>
            <p><strong>Email:</strong> {{customer_email}}</p>
            <p><strong>Telefon:</strong> {{customer_phone}}</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Szczegóły rezerwacji:</h3>
            <p><strong>Data rozpoczęcia:</strong> {{start_date}}</p>
            <p><strong>Data zakończenia:</strong> {{end_date}}</p>
          </div>
          <div style="margin: 20px 0;">
            <h3>Wybrany sprzęt:</h3>
            {{equipment_list}}
          </div>
          <div style="background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>Całkowity koszt:</strong> {{total_price}} zł</p>
            <p><strong>Kaucja:</strong> {{deposit_amount}} zł</p>
          </div>
        </div>'
      )
    );
  END IF;
END $$;

-- Dodaj zmienne dla szablonów (jeśli nie istnieją)
DO $$
DECLARE
  template_record RECORD;
  variable_record RECORD;
BEGIN
  FOR template_record IN SELECT id, name FROM email_templates WHERE name IN ('new_reservation', 'reservation_status_update', 'admin_notification')
  LOOP
    FOR variable_record IN (
      SELECT name, description FROM (
        VALUES 
          ('customer_name', 'Imię i nazwisko klienta'),
          ('start_date', 'Data rozpoczęcia rezerwacji'),
          ('end_date', 'Data zakończenia rezerwacji'),
          ('equipment_list', 'Lista zarezerwowanego sprzętu'),
          ('total_price', 'Całkowity koszt rezerwacji'),
          ('deposit_amount', 'Kwota kaucji'),
          ('reservation_id', 'Numer rezerwacji'),
          ('new_status', 'Nowy status rezerwacji'),
          ('customer_email', 'Adres email klienta'),
          ('customer_phone', 'Numer telefonu klienta')
      ) AS v(name, description)
    )
    LOOP
      IF NOT EXISTS (
        SELECT 1 
        FROM email_template_variables 
        WHERE template_id = template_record.id 
        AND variable_name = variable_record.name
      ) THEN
        INSERT INTO email_template_variables (template_id, variable_name, description)
        VALUES (template_record.id, variable_record.name, variable_record.description);
      END IF;
    END LOOP;
  END LOOP;
END $$;