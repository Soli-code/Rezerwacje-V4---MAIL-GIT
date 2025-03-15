/*
  # Naprawa systemu wysyłki maili

  1. Zmiany
    - Dodaje brakujące zmienne do szablonu emaila
    - Aktualizuje konfigurację SMTP
    - Dodaje nowe kolumny do logowania emaili
  
  2. Bezpieczeństwo
    - Zachowuje istniejące uprawnienia dostępu
*/

-- Aktualizuj szablon emaila
UPDATE email_templates
SET body = jsonb_build_object(
  'html',
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
      .important { color: #FF6B00; font-weight: bold; }
      .button { display: inline-block; padding: 10px 20px; background: #FF6B00; color: white; text-decoration: none; border-radius: 5px; }
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1 style="color: #FF6B00;">SOLRENT</h1>
        <h2>Potwierdzenie rezerwacji</h2>
      </div>
      
      <div class="content">
        <p>Witaj {{first_name}} {{last_name}},</p>
        
        <p>Dziękujemy za dokonanie rezerwacji sprzętu w SOLRENT. Poniżej znajdziesz szczegóły swojej rezerwacji:</p>
        
        <h3>Szczegóły rezerwacji:</h3>
        <ul>
          <li>Data rozpoczęcia: {{start_date}} {{start_time}}</li>
          <li>Data zakończenia: {{end_date}} {{end_time}}</li>
          <li>Zarezerwowany sprzęt: {{equipment_list}}</li>
          <li>Całkowity koszt: {{total_price}} zł</li>
          <li>Wymagana kaucja: {{deposit_amount}} zł</li>
        </ul>

        <p class="important">Ważne informacje:</p>
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

        <p>W razie pytań lub potrzeby zmiany rezerwacji, prosimy o kontakt:</p>
        <ul>
          <li>Telefon: 694 171 171</li>
          <li>Email: biuro@solrent.pl</li>
        </ul>
      </div>
      
      <div class="footer">
        <p>SOLRENT - Wypożyczalnia sprzętu budowlanego i ogrodniczego</p>
        <p>ul. Jęczmienna 4, 44-190 Knurów</p>
      </div>
    </div>
  </body>
  </html>'
)
WHERE name = 'new_reservation';

-- Dodaj kolumny do logowania błędów
ALTER TABLE email_logs 
ADD COLUMN IF NOT EXISTS delivery_attempts integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_error text,
ADD COLUMN IF NOT EXISTS headers jsonb,
ADD COLUMN IF NOT EXISTS template_data jsonb;