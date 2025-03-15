/*
  # Add availability check functions

  1. New Functions
    - check_equipment_availability: Checks if equipment is available for a given time period
    - get_next_available_date: Gets the next available date for equipment rental
    
  2. Changes
    - Added functions to check equipment availability
    - Added function to find next available date
*/

-- Function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 
    FROM reservations r
    JOIN reservation_items ri ON r.id = ri.reservation_id
    WHERE ri.equipment_id = p_equipment_id
    AND r.status != 'cancelled'
    AND (
      (r.start_date, r.end_date) OVERLAPS (p_start_date, p_end_date)
      OR
      (p_start_date < r.end_date + INTERVAL '1 hour')
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get next available date
CREATE OR REPLACE FUNCTION get_next_available_date(
  p_equipment_id UUID,
  p_start_date TIMESTAMPTZ
) RETURNS TIMESTAMPTZ AS $$
DECLARE
  next_date TIMESTAMPTZ;
BEGIN
  SELECT MIN(r.end_date + INTERVAL '1 hour')
  INTO next_date
  FROM reservations r
  JOIN reservation_items ri ON r.id = ri.reservation_id
  WHERE ri.equipment_id = p_equipment_id
  AND r.status != 'cancelled'
  AND r.end_date >= p_start_date;

  RETURN COALESCE(next_date, p_start_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;