/*
  # Fix reservation time gap handling

  1. Changes
    - Update time gap validation functions to properly handle hourly gaps
    - Fix overlapping reservation checks
    - Add proper time zone handling
    
  2. Functions
    - check_time_overlap: New function to properly check time overlaps with gaps
    - validate_reservation: Updated to use new overlap checking
    - validate_equipment_availability: Updated to use new overlap checking
*/

-- Function to check if two time periods overlap, considering the minimum gap
CREATE OR REPLACE FUNCTION check_time_overlap(
  p_start_date1 timestamptz,
  p_end_date1 timestamptz,
  p_start_date2 timestamptz,
  p_end_date2 timestamptz,
  p_min_gap interval DEFAULT interval '1 hour'
) RETURNS boolean AS $$
BEGIN
  RETURN (
    p_start_date1 < (p_end_date2 + p_min_gap) AND
    (p_end_date1 + p_min_gap) > p_start_date2
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to check reservation availability
CREATE OR REPLACE FUNCTION check_reservation_availability(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
DECLARE
  v_min_gap interval := interval '1 hour';
  v_conflicts int;
BEGIN
  -- Check conflicts with existing reservations
  SELECT COUNT(*)
  INTO v_conflicts
  FROM reservations r
  JOIN reservation_items ri ON r.id = ri.reservation_id
  WHERE ri.equipment_id = p_equipment_id
    AND r.status != 'cancelled'
    AND check_time_overlap(
      p_start_date,
      p_end_date,
      r.start_date,
      r.end_date,
      v_min_gap
    );

  IF v_conflicts > 0 THEN
    RETURN false;
  END IF;

  -- Check conflicts with equipment availability
  SELECT COUNT(*)
  INTO v_conflicts
  FROM equipment_availability ea
  WHERE ea.equipment_id = p_equipment_id
    AND ea.status = 'reserved'
    AND check_time_overlap(
      p_start_date,
      p_end_date,
      ea.start_date,
      ea.end_date,
      v_min_gap
    );

  RETURN v_conflicts = 0;
END;
$$ LANGUAGE plpgsql;

-- Function to validate reservation
CREATE OR REPLACE FUNCTION validate_reservation()
RETURNS trigger AS $$
DECLARE
  v_equipment_id uuid;
  v_valid boolean := true;
BEGIN
  -- Ensure end date is after start date
  IF NEW.end_date <= NEW.start_date THEN
    RAISE EXCEPTION 'End date must be after start date';
  END IF;

  -- For each equipment in the reservation
  FOR v_equipment_id IN
    SELECT equipment_id 
    FROM reservation_items 
    WHERE reservation_id = NEW.id
  LOOP
    IF NOT check_reservation_availability(
      v_equipment_id,
      NEW.start_date,
      NEW.end_date
    ) THEN
      v_valid := false;
      EXIT;
    END IF;
  END LOOP;

  IF NOT v_valid THEN
    RAISE EXCEPTION 'Reservation conflicts with existing reservation or does not maintain minimum 1 hour gap';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to validate equipment availability
CREATE OR REPLACE FUNCTION validate_equipment_availability()
RETURNS trigger AS $$
BEGIN
  IF NOT check_reservation_availability(
    NEW.equipment_id,
    NEW.start_date,
    NEW.end_date
  ) THEN
    RAISE EXCEPTION 'Equipment availability conflicts with existing reservation or does not maintain minimum 1 hour gap';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers
DROP TRIGGER IF EXISTS validate_time_gap ON equipment_availability;
DROP TRIGGER IF EXISTS validate_reservation_time_gap ON reservations;

-- Recreate triggers with updated functions
CREATE TRIGGER validate_time_gap
  BEFORE INSERT OR UPDATE ON equipment_availability
  FOR EACH ROW
  EXECUTE FUNCTION validate_equipment_availability();

CREATE TRIGGER validate_reservation_time_gap
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation();