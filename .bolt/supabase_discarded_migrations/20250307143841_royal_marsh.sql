/*
  # Update working hours validation

  1. Changes
    - Drop existing constraints that depend on check_working_hours function
    - Update check_working_hours function with improved validation
    - Re-add constraints and triggers
    
  2. Details
    - Working hours: Mon-Fri 8:00-16:00, Sat 8:00-13:00, Sun closed
    - Validates both start and end times
    - Prevents reservations outside working hours
*/

-- First drop the constraints that depend on the function
DO $$ 
BEGIN
  -- Drop constraints from reservations table
  ALTER TABLE reservations DROP CONSTRAINT IF EXISTS check_working_hours_start;
  ALTER TABLE reservations DROP CONSTRAINT IF EXISTS check_working_hours_end;
  ALTER TABLE reservations DROP CONSTRAINT IF EXISTS valid_dates;
  
  -- Drop constraints from equipment_availability table
  ALTER TABLE equipment_availability DROP CONSTRAINT IF EXISTS check_working_hours_start;
  ALTER TABLE equipment_availability DROP CONSTRAINT IF EXISTS check_working_hours_end;
END $$;

-- Now we can safely drop and recreate the functions
DROP FUNCTION IF EXISTS validate_reservation();
DROP FUNCTION IF EXISTS check_working_hours(timestamptz);

-- Recreate the check_working_hours function
CREATE OR REPLACE FUNCTION check_working_hours(check_time timestamptz)
RETURNS boolean AS $$
DECLARE
  local_time timestamptz;
  day_of_week integer;
  hour_of_day integer;
BEGIN
  -- Konwertuj czas na strefę czasową Warsaw
  local_time := check_time AT TIME ZONE 'Europe/Warsaw';
  
  -- Pobierz dzień tygodnia (1-7, gdzie 1 to poniedziałek)
  day_of_week := EXTRACT(DOW FROM local_time);
  IF day_of_week = 0 THEN day_of_week := 7; END IF;
  
  -- Pobierz godzinę
  hour_of_day := EXTRACT(HOUR FROM local_time);
  
  -- Sprawdź warunki
  RETURN CASE
    -- Poniedziałek-Piątek (1-5): 8:00-16:00
    WHEN day_of_week BETWEEN 1 AND 5 AND hour_of_day BETWEEN 8 AND 15 THEN true
    -- Sobota (6): 8:00-13:00
    WHEN day_of_week = 6 AND hour_of_day BETWEEN 8 AND 12 THEN true
    -- Niedziela (7): zamknięte
    ELSE false
  END;
END;
$$ LANGUAGE plpgsql;

-- Recreate the validate_reservation function
CREATE OR REPLACE FUNCTION validate_reservation()
RETURNS TRIGGER AS $$
BEGIN
  -- Sprawdź godziny pracy dla początku i końca rezerwacji
  IF NOT check_working_hours(NEW.start_date) OR NOT check_working_hours(NEW.end_date) THEN
    RAISE EXCEPTION 'Reservation must be within working hours';
  END IF;

  -- Sprawdź czy data końcowa jest późniejsza niż początkowa
  IF NEW.end_date <= NEW.start_date THEN
    RAISE EXCEPTION 'End date must be after start date';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS validate_reservation_time_gap ON reservations;
CREATE TRIGGER validate_reservation_time_gap
  BEFORE INSERT OR UPDATE
  ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation();

-- Re-add the constraints
DO $$ 
BEGIN
  -- Add constraints to reservations table
  ALTER TABLE reservations
    ADD CONSTRAINT check_working_hours_start 
    CHECK (check_working_hours(start_date));
    
  ALTER TABLE reservations
    ADD CONSTRAINT check_working_hours_end 
    CHECK (check_working_hours(end_date));
    
  ALTER TABLE reservations
    ADD CONSTRAINT valid_dates 
    CHECK (end_date >= start_date);
    
  -- Add constraints to equipment_availability table
  ALTER TABLE equipment_availability
    ADD CONSTRAINT check_working_hours_start 
    CHECK (check_working_hours(start_date));
    
  ALTER TABLE equipment_availability
    ADD CONSTRAINT check_working_hours_end 
    CHECK (check_working_hours(end_date));
END $$;