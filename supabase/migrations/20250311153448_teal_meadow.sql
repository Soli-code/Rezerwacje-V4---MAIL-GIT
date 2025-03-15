/*
  # System naliczania opłat za wynajem v2

  1. Nowe funkcje
    - calculate_rental_days_v2 - oblicza liczbę dni wynajmu z uwzględnieniem:
      - dokładnych 24h okresów
      - bezpłatnych niedziel dla wynajmów sob 13:00 - pon 8:00
      - zaokrąglania w górę przy przekroczeniu pełnej doby

  2. Zmiany w tabelach
    - Dodanie kolumny rental_days w tabeli reservations
    - Dodanie kolumny free_sunday w tabeli reservations

  3. Triggery
    - before_reservation_insert - automatycznie oblicza dni wynajmu
    - before_reservation_update - aktualizuje dni wynajmu przy zmianach dat
*/

-- Usuń starą funkcję jeśli istnieje
DROP FUNCTION IF EXISTS calculate_rental_days(timestamptz, timestamptz, text, text);

-- Funkcja obliczająca liczbę dni wynajmu
CREATE OR REPLACE FUNCTION calculate_rental_days_v2(
  p_start_date timestamptz,
  p_end_date timestamptz,
  p_start_time text,
  p_end_time text
) RETURNS integer AS $$
DECLARE
  v_start timestamptz;
  v_end timestamptz;
  v_days integer;
  v_hours integer;
  v_is_free_sunday boolean;
BEGIN
  -- Konwertuj daty z uwzględnieniem godzin
  v_start := p_start_date + p_start_time::time;
  v_end := p_end_date + p_end_time::time;
  
  -- Oblicz różnicę w godzinach
  v_hours := EXTRACT(EPOCH FROM (v_end - v_start))/3600;
  
  -- Oblicz podstawową liczbę dni (zaokrąglając w górę każdą rozpoczętą dobę)
  v_days := CEIL(v_hours::numeric / 24);
  
  -- Sprawdź czy niedziela jest bezpłatna
  v_is_free_sunday := (
    EXTRACT(DOW FROM v_start) = 6 AND -- sobota
    EXTRACT(HOUR FROM v_start) >= 13 AND -- od 13:00
    EXTRACT(DOW FROM v_end) = 1 AND -- poniedziałek
    EXTRACT(HOUR FROM v_end) <= 8 -- do 8:00
  );
  
  -- Jeśli niedziela jest bezpłatna, odejmij jeden dzień
  IF v_is_free_sunday THEN
    v_days := v_days - 1;
  END IF;
  
  RETURN v_days;
END;
$$ LANGUAGE plpgsql;

-- Dodaj kolumny do tabeli reservations
ALTER TABLE reservations 
ADD COLUMN IF NOT EXISTS rental_days integer,
ADD COLUMN IF NOT EXISTS free_sunday boolean DEFAULT false;

-- Trigger przed dodaniem rezerwacji
CREATE OR REPLACE FUNCTION before_reservation_insert() RETURNS trigger AS $$
BEGIN
  -- Oblicz dni wynajmu
  NEW.rental_days := calculate_rental_days_v2(
    NEW.start_date,
    NEW.end_date,
    NEW.start_time,
    NEW.end_time
  );
  
  -- Sprawdź czy niedziela jest bezpłatna
  NEW.free_sunday := (
    EXTRACT(DOW FROM NEW.start_date) = 6 AND
    NEW.start_time >= '13:00' AND
    EXTRACT(DOW FROM NEW.end_date) = 1 AND
    NEW.end_time <= '08:00'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS before_reservation_insert_trigger ON reservations;
CREATE TRIGGER before_reservation_insert_trigger
  BEFORE INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION before_reservation_insert();

-- Trigger przed aktualizacją rezerwacji
CREATE OR REPLACE FUNCTION before_reservation_update() RETURNS trigger AS $$
BEGIN
  -- Przelicz dni tylko jeśli zmieniły się daty lub godziny
  IF NEW.start_date != OLD.start_date OR 
     NEW.end_date != OLD.end_date OR
     NEW.start_time != OLD.start_time OR
     NEW.end_time != OLD.end_time THEN
    
    NEW.rental_days := calculate_rental_days_v2(
      NEW.start_date,
      NEW.end_date,
      NEW.start_time,
      NEW.end_time
    );
    
    NEW.free_sunday := (
      EXTRACT(DOW FROM NEW.start_date) = 6 AND
      NEW.start_time >= '13:00' AND
      EXTRACT(DOW FROM NEW.end_date) = 1 AND
      NEW.end_time <= '08:00'
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS before_reservation_update_trigger ON reservations;
CREATE TRIGGER before_reservation_update_trigger
  BEFORE UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION before_reservation_update();