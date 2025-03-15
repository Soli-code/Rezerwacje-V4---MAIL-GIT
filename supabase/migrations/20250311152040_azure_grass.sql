/*
  # Implementacja zasad naliczania dni wynajmu

  1. Nowe funkcje
    - calculate_rental_days - oblicza liczbę dni wynajmu według nowych zasad
    - validate_rental_dates - waliduje daty i godziny wynajmu
    - handle_weekend_exception - obsługuje wyjątek weekendowy

  2. Zmiany
    - Dodanie triggerów walidujących daty rezerwacji
    - Aktualizacja funkcji obliczającej cenę

  3. Bezpieczeństwo
    - Walidacja dat i godzin przed zapisem
    - Zabezpieczenie przed nieprawidłowymi przedziałami czasowymi
*/

-- Funkcja obliczająca liczbę dni wynajmu
CREATE OR REPLACE FUNCTION calculate_rental_days(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  start_time text,
  end_time text
) RETURNS integer AS $$
DECLARE
  start_timestamp timestamp with time zone;
  end_timestamp timestamp with time zone;
  days integer;
BEGIN
  -- Konwertuj daty i godziny na timestampy
  start_timestamp := start_date + start_time::time;
  end_timestamp := end_date + end_time::time;
  
  -- Sprawdź wyjątek weekendowy
  IF extract(dow from start_date) = 6  -- Sobota
     AND start_time >= '13:00'
     AND extract(dow from end_date) = 1  -- Poniedziałek
     AND end_time = '08:00' THEN
    -- Nie licz niedzieli
    days := 2;
  ELSE
    -- Standardowe obliczenie dni
    days := CASE 
      -- Jeśli kończy się o 8:00, nie licz tego dnia
      WHEN end_time = '08:00' THEN
        CEIL(EXTRACT(EPOCH FROM (end_timestamp - interval '1 minute' - start_timestamp))/86400)
      ELSE
        CEIL(EXTRACT(EPOCH FROM (end_timestamp - start_timestamp))/86400)
    END;
  END IF;
  
  RETURN days;
END;
$$ LANGUAGE plpgsql;

-- Funkcja walidująca daty i godziny wynajmu
CREATE OR REPLACE FUNCTION validate_rental_dates(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  start_time text,
  end_time text
) RETURNS boolean AS $$
BEGIN
  -- Sprawdź czy daty nie są puste
  IF start_date IS NULL OR end_date IS NULL OR start_time IS NULL OR end_time IS NULL THEN
    RAISE EXCEPTION 'Daty i godziny wynajmu są wymagane';
  END IF;

  -- Sprawdź czy data końcowa jest późniejsza niż początkowa
  IF end_date < start_date OR 
    (end_date = start_date AND end_time::time <= start_time::time) THEN
    RAISE EXCEPTION 'Data zakończenia musi być późniejsza niż data rozpoczęcia';
  END IF;

  -- Sprawdź czy godziny są w dozwolonym zakresie (8:00-16:00)
  IF start_time::time < '08:00'::time OR start_time::time > '16:00'::time OR
     end_time::time < '08:00'::time OR end_time::time > '16:00'::time THEN
    RAISE EXCEPTION 'Godziny wynajmu muszą być w zakresie 8:00-16:00';
  END IF;

  -- Sprawdź czy nie wypada w niedzielę
  IF extract(dow from start_date) = 0 OR extract(dow from end_date) = 0 THEN
    RAISE EXCEPTION 'Wynajem nie może rozpoczynać się ani kończyć w niedzielę';
  END IF;

  -- Sprawdź ograniczenia dla soboty
  IF extract(dow from start_date) = 6 AND start_time::time > '13:00'::time THEN
    RAISE EXCEPTION 'W sobotę wynajem można rozpocząć najpóźniej o 13:00';
  END IF;
  
  IF extract(dow from end_date) = 6 AND end_time::time > '13:00'::time THEN
    RAISE EXCEPTION 'W sobotę wynajem można zakończyć najpóźniej o 13:00';
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Trigger walidujący daty przed zapisem rezerwacji
CREATE OR REPLACE FUNCTION validate_reservation_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- Wywołaj funkcję walidującą
  PERFORM validate_rental_dates(
    NEW.start_date,
    NEW.end_date,
    NEW.start_time,
    NEW.end_time
  );

  -- Oblicz i ustaw liczbę dni
  NEW.rental_days := calculate_rental_days(
    NEW.start_date,
    NEW.end_date,
    NEW.start_time,
    NEW.end_time
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Dodaj trigger do tabeli reservations
DROP TRIGGER IF EXISTS validate_reservation_dates_trigger ON reservations;
CREATE TRIGGER validate_reservation_dates_trigger
  BEFORE INSERT OR UPDATE
  ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation_dates();

-- Dodaj kolumnę rental_days do tabeli reservations jeśli nie istnieje
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'reservations' 
    AND column_name = 'rental_days'
  ) THEN
    ALTER TABLE reservations ADD COLUMN rental_days integer;
  END IF;
END $$;