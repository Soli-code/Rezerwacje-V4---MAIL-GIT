/*
  # Aktualizacja konfiguracji SMTP

  1. Zmiany
    - Usuwa istniejącą konfigurację SMTP
    - Dodaje nową konfigurację SMTP z poprawnymi danymi uwierzytelniającymi
  
  2. Bezpieczeństwo
    - Tylko administratorzy mogą zarządzać konfiguracją SMTP
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
  '188.210.221.82',
  465,
  'biuro@solrent.pl',
  'arELtGPxndj9KvpsjDtZ',
  'biuro@solrent.pl',
  'SOLRENT',
  'tls'
);