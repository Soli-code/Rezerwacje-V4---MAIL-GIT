/*
  # Database Integration Updates

  1. Functions
    - Add availability checking functions
    - Add reservation status management functions
    - Add equipment availability triggers

  2. Performance
    - Add indexes for better query performance
*/

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Update equipment_availability table
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'valid_status' AND table_name = 'equipment_availability'
  ) THEN
    ALTER TABLE equipment_availability 
      ADD CONSTRAINT valid_status CHECK (status IN ('reserved', 'maintenance'));
  END IF;
END $$;

-- Update reservations table
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'valid_reservation_status' AND table_name = 'reservations'
  ) THEN
    ALTER TABLE reservations 
      ADD CONSTRAINT valid_reservation_status CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed'));
  END IF;
END $$;

-- Update reservation_items table
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'positive_quantity' AND table_name = 'reservation_items'
  ) THEN
    ALTER TABLE reservation_items 
      ADD CONSTRAINT positive_quantity CHECK (quantity > 0);
  END IF;
END $$;

-- Create functions for availability checking
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

-- Trigger function to update equipment availability
CREATE OR REPLACE FUNCTION update_equipment_availability()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
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
  ELSIF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
    IF NEW.status = 'cancelled' THEN
      DELETE FROM equipment_availability
      WHERE reservation_id = NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for equipment availability
DROP TRIGGER IF EXISTS after_reservation_insert ON reservations;
CREATE TRIGGER after_reservation_insert
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability();

DROP TRIGGER IF EXISTS before_reservation_status_update ON reservations;
CREATE TRIGGER before_reservation_status_update
  BEFORE UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability();

-- Drop and recreate the reservation status function
DROP FUNCTION IF EXISTS update_reservation_status(UUID, TEXT, TEXT);

CREATE FUNCTION update_reservation_status(
  p_reservation_id UUID,
  p_new_status TEXT,
  p_comment TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO reservation_history (
    reservation_id,
    previous_status,
    new_status,
    changed_by,
    comment
  )
  SELECT 
    id,
    status,
    p_new_status,
    auth.uid(),
    p_comment
  FROM reservations
  WHERE id = p_reservation_id;

  UPDATE reservations
  SET status = p_new_status
  WHERE id = p_reservation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_equipment_availability_dates 
  ON equipment_availability (equipment_id, start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_reservations_dates 
  ON reservations (start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_reservation_items_equipment 
  ON reservation_items (equipment_id);

CREATE INDEX IF NOT EXISTS idx_reservation_history_reservation 
  ON reservation_history (reservation_id);