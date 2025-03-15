/*
  # Fix rental days calculation function

  1. Changes
    - Drop existing function
    - Create new function with proper timezone handling
    - Fix calculation logic for rental days
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
  v_start_hour integer;
  v_end_hour integer;
  v_days integer;
  v_start_local timestamptz;
  v_end_local timestamptz;
BEGIN
  -- Validate input parameters
  IF start_date IS NULL OR end_date IS NULL OR start_time IS NULL OR end_time IS NULL THEN
    RETURN 0;
  END IF;

  -- Parse hours from time strings
  v_start_hour := (split_part(start_time, ':', 1))::integer;
  v_end_hour := (split_part(end_time, ':', 1))::integer;

  -- Convert dates to local timezone
  v_start_local := start_date AT TIME ZONE 'Europe/Warsaw';
  v_end_local := end_date AT TIME ZONE 'Europe/Warsaw';

  -- Set proper hours
  v_start_local := date_trunc('day', v_start_local) + (v_start_hour || ' hours')::interval;
  v_end_local := date_trunc('day', v_end_local) + (v_end_hour || ' hours')::interval;

  -- Calculate base number of days
  v_days := CASE
    -- If end time is 8:00, don't count the last day
    WHEN v_end_hour = 8 THEN
      CEIL(EXTRACT(EPOCH FROM (v_end_local - interval '1 day' - v_start_local))/86400.0)::integer
    ELSE
      CEIL(EXTRACT(EPOCH FROM (v_end_local - v_start_local))/86400.0)::integer
    END;

  -- Handle weekend special case (Saturday 13:00 - Monday 8:00)
  IF EXTRACT(DOW FROM v_start_local) = 6 AND -- Saturday
     v_start_hour >= 13 AND -- After 13:00
     EXTRACT(DOW FROM v_end_local) = 1 AND -- Monday
     v_end_hour <= 8 -- Before or at 8:00
  THEN
    v_days := v_days - 1; -- Don't count Sunday
  END IF;

  -- Always return at least 1 day
  RETURN GREATEST(v_days, 1);
END;
$$;