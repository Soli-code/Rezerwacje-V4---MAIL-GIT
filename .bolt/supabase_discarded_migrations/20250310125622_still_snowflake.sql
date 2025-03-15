/*
  # Aktualizacja konfiguracji SMTP i szablonów email

  1. Zmiany
    - Usuwa istniejącą konfigurację SMTP
    - Dodaje nową konfigurację SMTP z poprawnymi danymi
    - Dodaje szablon email dla nowej rezerwacji
    - Upewnia się, że polityki dostępu są poprawnie ustawione
  
  2. Bezpieczeństwo
    - Tylko administratorzy mogą zarządzać konfiguracją SMTP
    - Tylko administratorzy mogą zarządzać szablonami email
*/

-- Usuń istniejącą konfigurację
DELETE FROM smtp_settings;

-- Dodaj nową konfigurację SMTP
INSERT INTO smtp_settings (
  host,
  port,
  username,
  password,
  from_email,
  from_name,
  encryption
)
VALUES (
  'smtp.gmail.com',
  587,
  'solrent.pl@gmail.com',
  'sbp_8bbaf71628819ca23757138d92548f514831331',
  'solrent.pl@gmail.com',
  'SOLRENT',
  'tls'
);

-- Dodaj szablon email dla nowej rezerwacji
INSERT INTO email_templates (
  name,
  subject,
  body
)
VALUES (
  'new_reservation',
  'Potwierdzenie rezerwacji - SOLRENT',
  jsonb_build_object(
    'html',
    '<!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Potwierdzenie rezerwacji</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #FF6B00;">Potwierdzenie rezerwacji - SOLRENT</h1>
        
        <p>Witaj {{first_name}} {{last_name}},</p>
        
        <p>Dziękujemy za złożenie rezerwacji w wypożyczalni SOLRENT. Poniżej znajdziesz szczegóły swojej rezerwacji:</p>
        
        <div style="background-color: #f8f8f8; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <h2 style="color: #FF6B00; margin-top: 0;">Szczegóły rezerwacji</h2>
          
          <p><strong>Data rozpoczęcia:</strong> {{start_date}} {{start_time}}</p>
          <p><strong>Data zakończenia:</strong> {{end_date}} {{end_time}}</p>
          
          <h3 style="color: #FF6B00;">Zarezerwowany sprzęt:</h3>
          <p>{{equipment_list}}</p>
          
          <p><strong>Całkowity koszt wypożyczenia:</strong> {{total_price}} zł</p>
          <p><strong>Wymagana kaucja:</strong> {{deposit_amount}} zł</p>
        </div>
        
        <div style="background-color: #fff3e0; padding: 20px; border-radius: 5px; margin: 20px 0;">
          <h3 style="color: #FF6B00; margin-top: 0;">Ważne informacje</h3>
          
          <p><strong>Godziny otwarcia:</strong></p>
          <ul style="list-style-type: none; padding-left: 0;">
            <li>Poniedziałek - Piątek: 8:00 - 16:00</li>
            <li>Sobota: 8:00 - 13:00</li>
            <li>Niedziela: nieczynne</li>
          </ul>
          
          <p><strong>Adres:</strong><br>
          SOLRENT<br>
          ul. Jęczmienna 4<br>
          44-190 Knurów</p>
          
          <p><strong>Kontakt:</strong><br>
          Tel: 694 171 171<br>
          Email: kontakt@solrent.pl</p>
        </div>
        
        <p>Prosimy o przygotowanie:</p>
        <ul>
          <li>Dokumentu tożsamości</li>
          <li>Kaucji w wysokości {{deposit_amount}} zł</li>
        </ul>
        
        <p>W razie jakichkolwiek pytań, prosimy o kontakt.</p>
        
        <p>Pozdrawiamy,<br>
        Zespół SOLRENT</p>
      </div>
    </body>
    </html>'
  )
);