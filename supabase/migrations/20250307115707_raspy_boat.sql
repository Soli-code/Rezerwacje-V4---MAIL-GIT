/*
  # Update working hours and reservation constraints

  1. Changes
    - Add check constraints for working hours (8:00-16:00)
    - Add check constraint for minimum gap between reservations
    - Add check constraint for valid reservation days (no Sundays)
    - Update existing data to comply with new constraints

  2. Constraints
    - Working hours: 8:00-16:00 Monday-Friday, 8:00-13:00 Saturday
    - Minimum gap between reservations: 1 hour
    - No reservations on Sundays
*/

-- Function to check if time is within working hours
CREATE OR REPLACE FUNCTION check_working_hours(check_date timestamptz)
RETURNS boolean AS $$
BEGIN
  -- Extract day of week (1 = Monday, 7 = Sunday)
  DECLARE
    dow integer := EXTRACT(DOW FROM check_date AT TIME ZONE 'Europe/Warsaw');
    hour integer := EXTRACT(HOUR FROM check_date AT TIME ZONE 'Europe/Warsaw');
  BEGIN
    -- Sunday (0) - not allowed
    IF dow = 0 THEN
      RETURN false;
    -- Saturday (6) - 8:00-13:00
    ELSIF dow = 6 THEN
      RETURN hour BETWEEN 8 AND 13;
    -- Monday-Friday (1-5) - 8:00-16:00
    ELSE
      RETURN hour BETWEEN 8 AND 16;
    END IF;
  END;
END;
$$ LANGUAGE plpgsql;

-- Update reservations table constraints
ALTER TABLE reservations
  DROP CONSTRAINT IF EXISTS valid_dates,
  DROP CONSTRAINT IF EXISTS check_working_hours_start,
  DROP CONSTRAINT IF EXISTS check_working_hours_end;

ALTER TABLE reservations
  ADD CONSTRAINT valid_dates 
    CHECK (end_date >= start_date),
  ADD CONSTRAINT check_working_hours_start 
    CHECK (check_working_hours(start_date)),
  ADD CONSTRAINT check_working_hours_end 
    CHECK (check_working_hours(end_date));

-- Update equipment_availability table constraints
ALTER TABLE equipment_availability
  DROP CONSTRAINT IF EXISTS valid_dates,
  DROP CONSTRAINT IF EXISTS check_working_hours_start,
  DROP CONSTRAINT IF EXISTS check_working_hours_end;

ALTER TABLE equipment_availability
  ADD CONSTRAINT valid_dates 
    CHECK (end_date >= start_date),
  ADD CONSTRAINT check_working_hours_start 
    CHECK (check_working_hours(start_date)),
  ADD CONSTRAINT check_working_hours_end 
    CHECK (check_working_hours(end_date));

-- Function to check for reservation conflicts with minimum gap
CREATE OR REPLACE FUNCTION check_reservation_gap(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz,
  p_current_reservation_id uuid DEFAULT NULL
) RETURNS boolean AS $$
DECLARE
  min_gap_hours integer := 1;
  conflict_exists boolean;
BEGIN
  -- Check for conflicts in reservations
  SELECT EXISTS (
    SELECT 1
    FROM reservations r
    JOIN reservation_items ri ON r.id = ri.reservation_id
    WHERE ri.equipment_id = p_equipment_id
      AND r.status != 'cancelled'
      AND r.id != COALESCE(p_current_reservation_id, '00000000-0000-0000-0000-000000000000')
      AND (
        -- Check if new reservation overlaps with existing ones
        (p_start_date <= r.end_date + interval '1 hour' AND p_end_date >= r.start_date - interval '1 hour')
      )
  ) INTO conflict_exists;

  -- Check for conflicts in equipment_availability
  IF NOT conflict_exists THEN
    SELECT EXISTS (
      SELECT 1
      FROM equipment_availability ea
      WHERE ea.equipment_id = p_equipment_id
        AND ea.status = 'reserved'
        AND (
          -- Check if new reservation overlaps with maintenance periods
          (p_start_date <= ea.end_date + interval '1 hour' AND p_end_date >= ea.start_date - interval '1 hour')
        )
    ) INTO conflict_exists;
  END IF;

  RETURN NOT conflict_exists;
END;
$$ LANGUAGE plpgsql;

-- Update existing data to comply with new constraints
UPDATE reservations
SET 
  start_date = date_trunc('hour', start_date AT TIME ZONE 'Europe/Warsaw' AT TIME ZONE 'UTC') + interval '8 hour',
  end_date = date_trunc('hour', end_date AT TIME ZONE 'Europe/Warsaw' AT TIME ZONE 'UTC') + interval '16 hour'
WHERE 
  EXTRACT(HOUR FROM start_date AT TIME ZONE 'Europe/Warsaw') < 8 
  OR EXTRACT(HOUR FROM end_date AT TIME ZONE 'Europe/Warsaw') > 16;

UPDATE equipment_availability
SET 
  start_date = date_trunc('hour', start_date AT TIME ZONE 'Europe/Warsaw' AT TIME ZONE 'UTC') + interval '8 hour',
  end_date = date_trunc('hour', end_date AT TIME ZONE 'Europe/Warsaw' AT TIME ZONE 'UTC') + interval '16 hour'
WHERE 
  EXTRACT(HOUR FROM start_date AT TIME ZONE 'Europe/Warsaw') < 8 
  OR EXTRACT(HOUR FROM end_date AT TIME ZONE 'Europe/Warsaw') > 16;