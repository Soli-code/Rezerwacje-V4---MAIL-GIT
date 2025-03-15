/*
  # Equipment Availability Functions

  1. Functions
    - `check_equipment_availability` - Checks if equipment is available for given dates
    - `get_next_available_date` - Gets the next available date for equipment
    - `update_equipment_availability` - Updates equipment availability on reservation

  2. Security
    - Functions are security definer to allow public access
    - RLS policies ensure data integrity
*/

-- Function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
DECLARE
  v_is_available boolean;
BEGIN
  SELECT NOT EXISTS (
    SELECT 1
    FROM equipment_availability ea
    WHERE ea.equipment_id = p_equipment_id
    AND (
      (p_start_date, p_end_date) OVERLAPS (ea.start_date, ea.end_date)
      OR
      (p_start_date <= ea.end_date AND p_end_date >= ea.start_date)
    )
  ) INTO v_is_available;

  RETURN v_is_available;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get next available date
CREATE OR REPLACE FUNCTION get_next_available_date(
  p_equipment_id uuid,
  p_start_date timestamptz
) RETURNS timestamptz AS $$
DECLARE
  v_next_date timestamptz;
BEGIN
  SELECT MIN(end_date + interval '1 hour')
  INTO v_next_date
  FROM equipment_availability
  WHERE equipment_id = p_equipment_id
  AND end_date >= p_start_date;

  RETURN COALESCE(v_next_date, p_start_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update equipment availability
CREATE OR REPLACE FUNCTION update_equipment_availability()
RETURNS trigger AS $$
BEGIN
  -- Create availability record for new reservation
  INSERT INTO equipment_availability (
    equipment_id,
    start_date,
    end_date,
    status,
    reservation_id
  )
  SELECT
    ri.equipment_id,
    NEW.start_date,
    NEW.end_date,
    'reserved',
    NEW.id
  FROM reservation_items ri
  WHERE ri.reservation_id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new reservations
DROP TRIGGER IF EXISTS after_reservation_insert ON reservations;
CREATE TRIGGER after_reservation_insert
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability();