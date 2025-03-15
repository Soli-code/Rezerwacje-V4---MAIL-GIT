/*
  # Add time gap handling for reservations

  1. Changes
    - Add GiST index for efficient date range queries
    - Add function to check time gaps between reservations
    - Add trigger to enforce minimum time gap between reservations
    
  2. Indexes
    - GiST index on reservations for date range queries
    - GiST index on equipment_availability for date range queries
    
  3. Functions
    - check_reservation_time_gap: Validates minimum time gap between reservations
    - enforce_time_gap: Trigger function to enforce time gap rules
*/

-- Create extension if not exists
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Add GiST indexes for efficient date range queries
CREATE INDEX IF NOT EXISTS idx_reservations_daterange 
ON reservations USING gist (tstzrange(start_date, end_date, '[]'));

CREATE INDEX IF NOT EXISTS idx_equipment_availability_daterange 
ON equipment_availability USING gist (tstzrange(start_date, end_date, '[]'));

-- Function to check time gaps between reservations
CREATE OR REPLACE FUNCTION check_reservation_time_gap(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
DECLARE
  v_min_gap interval := interval '1 hour';
  v_conflicts int;
BEGIN
  -- Check for conflicts in reservations
  SELECT COUNT(*)
  INTO v_conflicts
  FROM reservations r
  JOIN reservation_items ri ON r.id = ri.reservation_id
  WHERE ri.equipment_id = p_equipment_id
    AND r.status != 'cancelled'
    AND (
      -- Check if new reservation starts less than 1 hour after existing reservation
      (p_start_date >= r.start_date AND p_start_date < r.end_date + v_min_gap)
      OR
      -- Check if new reservation ends less than 1 hour before existing reservation
      (p_end_date > r.start_date - v_min_gap AND p_end_date <= r.end_date)
      OR
      -- Check if new reservation completely overlaps existing reservation
      (p_start_date <= r.start_date AND p_end_date >= r.end_date)
    );

  -- Check for conflicts in equipment_availability
  SELECT COUNT(*) + v_conflicts
  INTO v_conflicts
  FROM equipment_availability ea
  WHERE ea.equipment_id = p_equipment_id
    AND ea.status = 'reserved'
    AND (
      (p_start_date >= ea.start_date AND p_start_date < ea.end_date + v_min_gap)
      OR
      (p_end_date > ea.start_date - v_min_gap AND p_end_date <= ea.end_date)
      OR
      (p_start_date <= ea.start_date AND p_end_date >= ea.end_date)
    );

  RETURN v_conflicts = 0;
END;
$$ LANGUAGE plpgsql;

-- Function to validate equipment availability before insert/update
CREATE OR REPLACE FUNCTION validate_equipment_availability()
RETURNS trigger AS $$
BEGIN
  IF NOT check_reservation_time_gap(
    NEW.equipment_id,
    NEW.start_date,
    NEW.end_date
  ) THEN
    RAISE EXCEPTION 'Equipment availability conflicts with existing reservation or does not maintain minimum 1 hour gap';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to validate reservation before insert/update
CREATE OR REPLACE FUNCTION validate_reservation()
RETURNS trigger AS $$
DECLARE
  v_equipment_id uuid;
  v_valid boolean := true;
BEGIN
  -- Check each equipment item in the reservation
  FOR v_equipment_id IN
    SELECT equipment_id 
    FROM reservation_items 
    WHERE reservation_id = NEW.id
  LOOP
    IF NOT check_reservation_time_gap(
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

-- Add trigger to equipment_availability
DROP TRIGGER IF EXISTS validate_time_gap ON equipment_availability;
CREATE TRIGGER validate_time_gap
  BEFORE INSERT OR UPDATE ON equipment_availability
  FOR EACH ROW
  EXECUTE FUNCTION validate_equipment_availability();

-- Add trigger to reservations
DROP TRIGGER IF EXISTS validate_reservation_time_gap ON reservations;
CREATE TRIGGER validate_reservation_time_gap
  BEFORE INSERT OR UPDATE ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation();

-- Update existing function to use new time gap check
CREATE OR REPLACE FUNCTION update_equipment_availability()
RETURNS trigger AS $$
BEGIN
  -- When a reservation is confirmed, create equipment availability records
  IF (TG_OP = 'INSERT' AND NEW.status = 'confirmed') OR
     (TG_OP = 'UPDATE' AND NEW.status = 'confirmed' AND OLD.status != 'confirmed') THEN
    
    -- Insert availability records for each equipment item
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
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;