/*
  # Fix rental days calculation function

  1. Changes
    - Drop existing function
    - Create new function with proper timezone handling
    - Add validation for input parameters
    - Fix calculation logic for free Sunday
*/

-- Drop existing function if exists
DROP FUNCTION IF EXISTS calculate_rental_days(timestamp with time zone, timestamp with time zone, text, text);

-- Create new function with proper implementation
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
  v_start_local timestamptz;
  v_end_local timestamptz;
BEGIN
  -- Validate input parameters
  IF start_date IS NULL OR end_date IS NULL OR start_time IS NULL OR end_time IS NULL THEN
    RETURN 0;
  END IF;

  -- Convert dates to local timezone (Europe/Warsaw)
  v_start_local := start_date AT TIME ZONE 'Europe/Warsaw';
  v_end_local := end_date AT TIME ZONE 'Europe/Warsaw';

  -- Create full timestamps with times
  v_start := date_trunc('day', v_start_local) + start_time::time;
  v_end := date_trunc('day', v_end_local) + end_time::time;
  
  -- Calculate days difference
  v_days := CEIL(EXTRACT(EPOCH FROM (v_end - v_start))/86400.0);
  
  -- Handle free Sunday case
  IF EXTRACT(DOW FROM v_start_local) = 6 AND -- Saturday
     start_time::time >= '13:00'::time AND -- After 13:00
     EXTRACT(DOW FROM v_end_local) = 1 AND -- Monday
     end_time::time <= '08:00'::time -- Before 8:00
  THEN
    v_days := v_days - 1; -- Subtract Sunday
  END IF;
  
  RETURN GREATEST(v_days, 1); -- Ensure minimum 1 day
END;
$$;