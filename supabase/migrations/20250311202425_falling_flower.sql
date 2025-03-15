/*
  # Add rental days calculation function

  1. New Function
    - calculate_rental_days: Oblicza liczbę dni wynajmu z uwzględnieniem:
      - Dokładnych godzin rozpoczęcia i zakończenia
      - Zaokrąglania w górę do pełnych dni
      - Specjalnych zasad dla weekendów
*/

CREATE OR REPLACE FUNCTION calculate_rental_days(
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  start_time text,
  end_time text
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  v_start timestamptz;
  v_end timestamptz;
  v_days integer;
BEGIN
  -- Konwertuj daty z uwzględnieniem godzin
  v_start := start_date + start_time::time;
  v_end := end_date + end_time::time;
  
  -- Oblicz różnicę w godzinach i zaokrąglij w górę do pełnych dni
  v_days := CEIL(EXTRACT(EPOCH FROM (v_end - v_start))/86400);
  
  -- Sprawdź czy niedziela jest bezpłatna (sobota 13:00 - poniedziałek 8:00)
  IF EXTRACT(DOW FROM v_start) = 6 AND -- sobota
     EXTRACT(HOUR FROM v_start) >= 13 AND -- od 13:00
     EXTRACT(DOW FROM v_end) = 1 AND -- poniedziałek
     EXTRACT(HOUR FROM v_end) <= 8 -- do 8:00
  THEN
    v_days := v_days - 1; -- Odejmij jeden dzień za niedzielę
  END IF;
  
  RETURN v_days;
END;
$$;