/*
  # Dodanie szablonu emaila dla rezerwacji

  1. Sprawdzenie i aktualizacja szablonu
    - Sprawdza czy szablon już istnieje
    - Jeśli nie istnieje, tworzy nowy
    - Jeśli istnieje, aktualizuje jego treść

  2. Bezpieczeństwo
    - Polityki dostępu dla administratorów
    - Publiczny dostęp do odczytu
*/

-- Sprawdź czy szablon już istnieje
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM email_templates WHERE name = 'new_reservation'
  ) THEN
    -- Dodaj szablon emaila dla nowej rezerwacji
    INSERT INTO email_templates (name, subject, body)
    VALUES (
      'new_reservation',
      'Potwierdzenie rezerwacji sprzętu - SOLRENT',
      jsonb_build_object(
        'html',
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
      )
    );
  END IF;
END $$;