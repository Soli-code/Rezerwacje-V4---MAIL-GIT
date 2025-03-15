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
  v_start_hour integer;
  v_end_hour integer;
BEGIN
  -- Validate input parameters
  IF start_date IS NULL OR end_date IS NULL OR start_time IS NULL OR end_time IS NULL THEN
    RETURN 0;
  END IF;

  -- Extract hours from time strings
  v_start_hour := (regexp_replace(start_time, ':.*$', ''))::integer;
  v_end_hour := (regexp_replace(end_time, ':.*$', ''))::integer;

  -- Convert dates to local timezone (Europe/Warsaw)
  v_start_local := start_date AT TIME ZONE 'Europe/Warsaw';
  v_end_local := end_date AT TIME ZONE 'Europe/Warsaw';

  -- Create full timestamps with times
  v_start := date_trunc('day', v_start_local) + make_interval(hours => v_start_hour);
  v_end := date_trunc('day', v_end_local) + make_interval(hours => v_end_hour);
  
  -- Calculate days difference
  v_days := CASE
    -- If end time is 8:00, don't count the last day
    WHEN v_end_hour = 8 THEN
      CEIL(EXTRACT(EPOCH FROM (v_end - interval '1 day' - v_start))/86400.0)
    ELSE
      CEIL(EXTRACT(EPOCH FROM (v_end - v_start))/86400.0)
  END;
  
  -- Handle free Sunday case
  IF EXTRACT(DOW FROM v_start_local) = 6 AND -- Saturday
     v_start_hour >= 13 AND -- After 13:00
     EXTRACT(DOW FROM v_end_local) = 1 AND -- Monday
     v_end_hour <= 8 -- Before 8:00
  THEN
    v_days := v_days - 1; -- Subtract Sunday
  END IF;
  
  RETURN GREATEST(v_days, 1); -- Ensure minimum 1 day
END;
$$;