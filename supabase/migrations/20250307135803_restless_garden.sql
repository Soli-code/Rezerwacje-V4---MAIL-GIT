/*
  # Fix same day reservations

  1. Changes
    - Add new function to properly handle time-based availability checks
    - Update triggers to use time-based validation
    - Fix time zone handling in availability checks
    
  2. Functions
    - is_time_available: New function to check time-based availability
    - validate_reservation: Updated to use time-based checks
    - validate_equipment_availability: Updated to use time-based checks
*/

-- Function to check if a specific time slot is available
CREATE OR REPLACE FUNCTION is_time_available(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
DECLARE
  v_min_gap interval := interval '1 hour';
  v_conflicts int;
BEGIN
  -- Check for conflicts with existing reservations
  SELECT COUNT(*)
  INTO v_conflicts
  FROM reservations r
  JOIN reservation_items ri ON r.id = ri.reservation_id
  WHERE ri.equipment_id = p_equipment_id
    AND r.status != 'cancelled'
    AND (
      -- Check if there's less than 1 hour gap between reservations
      (p_start_date >= r.start_date AND p_start_date < r.end_date + v_min_gap) OR
      (p_end_date > r.start_date - v_min_gap AND p_end_date <= r.end_date) OR
      (p_start_date <= r.start_date AND p_end_date >= r.end_date)
    );

  IF v_conflicts > 0 THEN
    RETURN false;
  END IF;

  -- Check for conflicts with equipment availability
  SELECT COUNT(*)
  INTO v_conflicts
  FROM equipment_availability ea
  WHERE ea.equipment_id = p_equipment_id
    AND ea.status = 'reserved'
    AND (
      (p_start_date >= ea.start_date AND p_start_date < ea.end_date + v_min_gap) OR
      (p_end_date > ea.start_date - v_min_gap AND p_end_date <= ea.end_date) OR
      (p_start_date <= ea.start_date AND p_end_date >= ea.end_date)
    );

  RETURN v_conflicts = 0;
END;
$$ LANGUAGE plpgsql;

-- Function to validate reservation
CREATE OR REPLACE FUNCTION validate_reservation()
RETURNS trigger AS $$
BEGIN
  -- Basic validation
  IF NEW.end_date <= NEW.start_date THEN
    RAISE EXCEPTION 'End date must be after start date';
  END IF;

  -- Check working hours (8:00-16:00 on weekdays, 8:00-13:00 on Saturday)
  IF NOT (
    EXTRACT(HOUR FROM NEW.start_date) >= 8 AND
    (
      (EXTRACT(DOW FROM NEW.start_date) BETWEEN 1 AND 5 AND EXTRACT(HOUR FROM NEW.end_date) <= 16) OR
      (EXTRACT(DOW FROM NEW.start_date) = 6 AND EXTRACT(HOUR FROM NEW.end_date) <= 13)
    )
  ) THEN
    RAISE EXCEPTION 'Reservation must be within working hours';
  END IF;

  -- Check availability for each equipment item
  IF EXISTS (
    SELECT 1
    FROM reservation_items ri
    WHERE ri.reservation_id = NEW.id
    AND NOT is_time_available(ri.equipment_id, NEW.start_date, NEW.end_date)
  ) THEN
    RAISE EXCEPTION 'One or more items are not available for the selected time period';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to validate equipment availability
CREATE OR REPLACE FUNCTION validate_equipment_availability()
RETURNS trigger AS $$
BEGIN
  IF NOT is_time_available(NEW.equipment_id, NEW.start_date, NEW.end_date) THEN
    RAISE EXCEPTION 'Equipment is not available for the selected time period';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers
DROP TRIGGER IF EXISTS validate_reservation_time_gap ON reservations;
DROP TRIGGER IF EXISTS validate_time_gap ON equipment_availability;

-- Create new triggers
CREATE TRIGGER validate_reservation_time_gap
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation();

CREATE TRIGGER validate_time_gap
  BEFORE INSERT OR UPDATE ON equipment_availability
  FOR EACH ROW
  EXECUTE FUNCTION validate_equipment_availability();