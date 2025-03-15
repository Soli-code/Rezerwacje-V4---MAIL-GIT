/*
  # Dodanie szablonu emaila dla nowych rezerwacji

  1. Nowe dane
    - Dodaje szablon emaila 'new_reservation' do tabeli email_templates
    - Dodaje zmienne szablonu do tabeli email_template_variables
  
  2. Zawartość
    - Szablon zawiera responsywny design HTML
    - Pełna personalizacja z wykorzystaniem zmiennych
    - Szczegółowe informacje o rezerwacji
*/

-- Dodaj szablon potwierdzenia rezerwacji
INSERT INTO email_templates (name, subject, body)
VALUES (
  'new_reservation',
  'Potwierdzenie rezerwacji - SOLRENT',
  jsonb_build_object(
    'html', '
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #FF6B00; margin-bottom: 20px;">Dziękujemy za złożenie rezerwacji w SOLRENT!</h2>
      
      <p style="color: #333;">Szanowny/a {{first_name}} {{last_name}},</p>
      
      <p style="color: #333;">Potwierdzamy otrzymanie Twojej rezerwacji:</p>
      
      <div style="background-color: #f8f8f8; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <p style="margin: 5px 0;"><strong>Data rozpoczęcia:</strong> {{start_date}} {{start_time}}</p>
        <p style="margin: 5px 0;"><strong>Data zakończenia:</strong> {{end_date}} {{end_time}}</p>
        <p style="margin: 5px 0;"><strong>Zarezerwowany sprzęt:</strong> {{equipment_list}}</p>
        <p style="margin: 5px 0;"><strong>Całkowity koszt:</strong> {{total_price}} zł</p>
        <p style="margin: 5px 0;"><strong>Wymagana kaucja:</strong> {{deposit_amount}} zł</p>
      </div>

      <div style="background-color: #fff3e0; padding: 15px; border-radius: 5px; margin: 20px 0;">
        <h3 style="color: #FF6B00; margin-top: 0;">Ważne informacje:</h3>
        <ul style="padding-left: 20px; margin: 10px 0;">
          <li>Adres odbioru: ul. Jęczmienna 4, 44-190 Knurów</li>
          <li>Wymagane dokumenty: dowód osobisty</li>
          <li>Płatność: gotówka lub przelew przy odbiorze</li>
          <li>Kaucja jest zwracana po zwrocie sprzętu w nienaruszonym stanie</li>
        </ul>
      </div>

      <div style="margin-top: 30px;">
        <p style="color: #333;">W razie pytań prosimy o kontakt:</p>
        <p style="margin: 5px 0;"><strong>Telefon:</strong> 694 171 171</p>
        <p style="margin: 5px 0;"><strong>Email:</strong> biuro@solrent.pl</p>
      </div>

      <div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #666;">
        <p>Ta wiadomość została wygenerowana automatycznie. Prosimy nie odpowiadać na ten adres email.</p>
      </div>
    </div>
    '
  )
)
ON CONFLICT (name) 
DO UPDATE SET
  subject = EXCLUDED.subject,
  body = EXCLUDED.body;

-- Dodaj zmienne szablonu
INSERT INTO email_template_variables (template_id, variable_name, description)
SELECT 
  t.id,
  v.variable_name,
  v.description
FROM email_templates t
CROSS JOIN (
  VALUES 
    ('first_name', 'Imię klienta'),
    ('last_name', 'Nazwisko klienta'),
    ('email', 'Adres email klienta'),
    ('phone', 'Numer telefonu klienta'),
    ('start_date', 'Data rozpoczęcia'),
    ('end_date', 'Data zakończenia'),
    ('start_time', 'Godzina rozpoczęcia'),
    ('end_time', 'Godzina zakończenia'),
    ('equipment_list', 'Lista zarezerwowanego sprzętu'),
    ('total_price', 'Całkowity koszt'),
    ('deposit_amount', 'Kwota kaucji')
) AS v(variable_name, description)
WHERE t.name = 'new_reservation'
ON CONFLICT (template_id, variable_name) DO UPDATE SET
  description = EXCLUDED.description;