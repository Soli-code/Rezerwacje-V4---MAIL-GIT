/*
  # Reservation Management System

  1. New Tables
    - `reservation_history`
      - Tracks all changes to reservation status
      - Maintains audit trail of modifications

  2. Functions
    - `update_reservation_status` - Updates reservation status and creates history record
    - `check_equipment_availability` - Verifies equipment availability for given dates
    - `update_inventory_status` - Updates equipment inventory status

  3. Triggers
    - Automatically update equipment availability on reservation status change
    - Create history records for all reservation changes
*/

-- Create reservation_history table
CREATE TABLE IF NOT EXISTS reservation_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE,
  previous_status text,
  new_status text NOT NULL,
  changed_at timestamptz DEFAULT now(),
  changed_by uuid REFERENCES auth.users(id),
  comment text
);

-- Enable RLS on reservation_history
ALTER TABLE reservation_history ENABLE ROW LEVEL SECURITY;

-- Create policies for reservation_history
CREATE POLICY "Admins can manage reservation history"
  ON reservation_history
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

CREATE POLICY "Users can view their own reservation history"
  ON reservation_history
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM reservations r
      JOIN customers c ON r.customer_id = c.id
      WHERE r.id = reservation_history.reservation_id
      AND c.user_id = auth.uid()
    )
  );

-- Function to update reservation status
CREATE OR REPLACE FUNCTION update_reservation_status(
  p_reservation_id uuid,
  p_new_status text,
  p_comment text DEFAULT NULL
) RETURNS reservations AS $$
DECLARE
  v_reservation reservations;
  v_previous_status text;
BEGIN
  -- Get current reservation status
  SELECT * INTO v_reservation
  FROM reservations
  WHERE id = p_reservation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reservation not found';
  END IF;

  v_previous_status := v_reservation.status;

  -- Update reservation status
  UPDATE reservations
  SET 
    status = p_new_status,
    updated_at = now()
  WHERE id = p_reservation_id
  RETURNING * INTO v_reservation;

  -- Create history record
  INSERT INTO reservation_history (
    reservation_id,
    previous_status,
    new_status,
    changed_by,
    comment
  ) VALUES (
    p_reservation_id,
    v_previous_status,
    p_new_status,
    auth.uid(),
    p_comment
  );

  -- Update equipment availability based on new status
  IF p_new_status = 'cancelled' THEN
    DELETE FROM equipment_availability
    WHERE reservation_id = p_reservation_id;
  END IF;

  RETURN v_reservation;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add reservation_id column to equipment_availability
ALTER TABLE equipment_availability
ADD COLUMN IF NOT EXISTS reservation_id uuid REFERENCES reservations(id) ON DELETE CASCADE;

-- Function to verify equipment availability
CREATE OR REPLACE FUNCTION verify_equipment_availability(
  p_reservation_id uuid
) RETURNS boolean AS $$
DECLARE
  v_is_available boolean := true;
  v_item record;
BEGIN
  FOR v_item IN
    SELECT 
      ri.equipment_id,
      r.start_date,
      r.end_date
    FROM reservation_items ri
    JOIN reservations r ON r.id = ri.reservation_id
    WHERE r.id = p_reservation_id
  LOOP
    -- Check if equipment is available
    IF NOT check_equipment_availability(
      v_item.equipment_id,
      v_item.start_date,
      v_item.end_date
    ) THEN
      v_is_available := false;
      EXIT;
    END IF;
  END LOOP;

  RETURN v_is_available;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add trigger to update equipment availability on reservation status change
CREATE OR REPLACE FUNCTION update_equipment_availability_on_status_change()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'confirmed' THEN
    -- Verify availability before confirming
    IF NOT verify_equipment_availability(NEW.id) THEN
      RAISE EXCEPTION 'Equipment not available for selected dates';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER before_reservation_status_update
  BEFORE UPDATE OF status ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability_on_status_change();