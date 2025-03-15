/*
  # Add availability checking functions
  
  1. New Functions
    - check_equipment_availability: Checks if equipment is available for a given time period
    - get_next_available_date: Gets the next available date for equipment
  
  2. Changes
    - Added proper error handling
    - Added date range overlap checking
    - Added equipment existence validation
*/

-- Function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if equipment exists
  IF NOT EXISTS (SELECT 1 FROM equipment WHERE id = p_equipment_id) THEN
    RETURN false;
  END IF;

  -- Check for overlapping reservations or maintenance periods
  RETURN NOT EXISTS (
    SELECT 1 
    FROM equipment_availability 
    WHERE equipment_id = p_equipment_id
    AND tstzrange(start_date, end_date, '[]') && tstzrange(p_start_date, p_end_date, '[]')
  );
END;
$$;

-- Function to get next available date
CREATE OR REPLACE FUNCTION get_next_available_date(
  p_equipment_id uuid,
  p_start_date timestamptz
) RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_next_date timestamptz;
BEGIN
  -- Check if equipment exists
  IF NOT EXISTS (SELECT 1 FROM equipment WHERE id = p_equipment_id) THEN
    RETURN p_start_date;
  END IF;

  -- Find the next available date after any overlapping unavailability periods
  SELECT MIN(end_date)
  INTO v_next_date
  FROM equipment_availability
  WHERE equipment_id = p_equipment_id
  AND end_date > p_start_date;

  -- If no unavailability periods found, return the requested start date
  RETURN COALESCE(v_next_date, p_start_date);
END;
$$;