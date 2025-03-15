/*
  # Aktualizacja walidacji rezerwacji

  1. Zmiany
    - Usunięcie ograniczeń sprawdzających godziny pracy
    - Usunięcie funkcji check_working_hours
    - Aktualizacja funkcji validate_reservation

  2. Bezpieczeństwo
    - Zachowanie podstawowej walidacji dat
*/

-- Usuń ograniczenia godzin pracy
ALTER TABLE reservations 
DROP CONSTRAINT IF EXISTS check_working_hours_start,
DROP CONSTRAINT IF EXISTS check_working_hours_end;

ALTER TABLE equipment_availability 
DROP CONSTRAINT IF EXISTS check_working_hours_start,
DROP CONSTRAINT IF EXISTS check_working_hours_end;

-- Usuń funkcję check_working_hours jeśli istnieje
DROP FUNCTION IF EXISTS check_working_hours(timestamp with time zone);

-- Zaktualizuj funkcję validate_reservation aby usunąć sprawdzanie godzin pracy
CREATE OR REPLACE FUNCTION validate_reservation()
RETURNS trigger AS $$
BEGIN
  -- Sprawdź tylko czy data końcowa jest późniejsza niż początkowa
  IF NEW.end_date <= NEW.start_date THEN
    RAISE EXCEPTION 'Data końcowa musi być późniejsza niż początkowa';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;