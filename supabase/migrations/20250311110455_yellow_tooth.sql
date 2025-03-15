/*
  # Sprawdzenie i aktualizacja portu SMTP

  1. Zmiany
    - Dodanie zapytania sprawdzającego aktualną konfigurację SMTP
    - Aktualizacja portu na 465 dla połączenia SSL
*/

-- Najpierw sprawdźmy aktualną konfigurację
SELECT host, port, encryption FROM smtp_settings;

-- Aktualizujemy port na 465 dla połączeń SSL
UPDATE smtp_settings 
SET port = 465 
WHERE encryption = 'ssl' AND port != 465;