/*
  # Reservation System Schema Update

  1. New Functions
    - check_equipment_availability: Checks if equipment is available for a given time period
    - get_next_available_date: Gets the next available date for equipment
    - enforce_time_gap: Ensures 1 hour gap between reservations
    
  2. Triggers
    - validate_time_gap: Enforces minimum gap between reservations

  3. Constraints
    - Added date validation and status constraints
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1 
    FROM equipment_availability ea
    WHERE ea.equipment_id = p_equipment_id
    AND ea.status = 'reserved'
    AND (
      (ea.start_date, ea.end_date) OVERLAPS (p_start_date, p_end_date)
      OR
      (p_start_date < ea.end_date + INTERVAL '1 hour')
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
  SELECT MIN(end_date + INTERVAL '1 hour')
  INTO next_date
  FROM equipment_availability
  WHERE equipment_id = p_equipment_id
  AND end_date >= p_start_date
  AND status = 'reserved';

  RETURN COALESCE(next_date, p_start_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to enforce time gap between reservations
CREATE OR REPLACE FUNCTION enforce_time_gap()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM reservations r
    JOIN reservation_items ri ON r.id = ri.reservation_id
    WHERE ri.equipment_id = NEW.equipment_id
    AND r.status != 'cancelled'
    AND tstzrange(r.start_date, r.end_date + INTERVAL '1 hour') &&
        tstzrange(NEW.start_date, NEW.end_date)
  ) THEN
    RAISE EXCEPTION 'Reservations must have at least 1 hour gap between them.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for time gap validation
DROP TRIGGER IF EXISTS validate_time_gap ON equipment_availability;
CREATE TRIGGER validate_time_gap
  BEFORE INSERT OR UPDATE ON equipment_availability
  FOR EACH ROW
  EXECUTE FUNCTION enforce_time_gap();

-- Add GiST index for efficient range queries
CREATE INDEX IF NOT EXISTS idx_equipment_availability_daterange 
  ON equipment_availability USING gist (
    equipment_id,
    tstzrange(start_date, end_date, '[]')
  );

-- Add policies for equipment_availability
ALTER TABLE equipment_availability ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Public can view equipment availability"
    ON equipment_availability
    FOR SELECT
    TO public
    USING (true);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "Admins can manage equipment availability"
    ON equipment_availability
    USING (EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    ));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Add constraints for valid dates and status
DO $$ BEGIN
  ALTER TABLE equipment_availability 
    ADD CONSTRAINT valid_dates_check CHECK (end_date > start_date),
    ADD CONSTRAINT valid_status_check CHECK (status IN ('reserved', 'maintenance'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;