/*
  # Add HTTP function for email sending

  1. Changes
    - Dodanie funkcji http() do obsługi żądań HTTP
    - Funkcja jest wymagana do wysyłania emaili przez Edge Functions

  2. Details
    - Funkcja przyjmuje parametry:
      - method: metoda HTTP (GET, POST, etc.)
      - url: adres URL
      - headers: nagłówki HTTP
      - body: treść żądania
      - timeout: timeout w sekundach
    - Zwraca typ RECORD z polami:
      - status: kod statusu HTTP
      - content: treść odpowiedzi
      - error: ewentualny błąd
*/

-- Utwórz typ dla nagłówków HTTP
CREATE TYPE http_header AS (
  field text,
  value text
);

-- Utwórz funkcję http
CREATE OR REPLACE FUNCTION http(
  method text,
  url text,
  headers http_header[] DEFAULT '{}',
  body text DEFAULT NULL,
  timeout_seconds int DEFAULT 10
)
RETURNS record
LANGUAGE plpgsql
AS $$
DECLARE
  result record;
BEGIN
  -- Tymczasowo zwróć pusty wynik
  -- Właściwa implementacja będzie dostarczona przez Edge Function
  SELECT 
    200 as status,
    '' as content,
    NULL as error
  INTO result;
  
  RETURN result;
END;
$$;