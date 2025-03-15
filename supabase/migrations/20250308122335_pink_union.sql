/*
  # Equipment Inventory Management

  1. Changes
    - Add quantity field to equipment table
    - Add inventory tracking functions and triggers
    - Add constraints for quantity validation
    - Update RLS policies

  2. Security
    - Add policies for inventory management
    - Enable quantity validation
*/

-- Add quantity field to equipment table
ALTER TABLE equipment 
ADD COLUMN quantity integer NOT NULL DEFAULT 1 CHECK (quantity >= 0);

-- Create function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id uuid,
  p_quantity integer,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
DECLARE
  available_quantity integer;
  total_reserved integer;
BEGIN
  -- Get equipment's total quantity
  SELECT quantity INTO available_quantity
  FROM equipment
  WHERE id = p_equipment_id;

  -- Calculate total reserved quantity for the given period
  SELECT COALESCE(SUM(ri.quantity), 0) INTO total_reserved
  FROM reservation_items ri
  JOIN reservations r ON r.id = ri.reservation_id
  WHERE ri.equipment_id = p_equipment_id
  AND r.status != 'cancelled'
  AND (
    (r.start_date, r.end_date) OVERLAPS (p_start_date, p_end_date)
  );

  -- Check if requested quantity is available
  RETURN (available_quantity - total_reserved) >= p_quantity;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function to validate reservation quantities
CREATE OR REPLACE FUNCTION validate_reservation_quantities()
RETURNS trigger AS $$
BEGIN
  -- Check if equipment is available in requested quantity
  IF NOT check_equipment_availability(
    NEW.equipment_id,
    NEW.quantity,
    (SELECT start_date FROM reservations WHERE id = NEW.reservation_id),
    (SELECT end_date FROM reservations WHERE id = NEW.reservation_id)
  ) THEN
    RAISE EXCEPTION 'Insufficient quantity available for equipment %', NEW.equipment_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate quantities before insert/update
CREATE TRIGGER check_reservation_quantities
  BEFORE INSERT OR UPDATE ON reservation_items
  FOR EACH ROW
  EXECUTE FUNCTION validate_reservation_quantities();

-- Update RLS policies for equipment table
CREATE POLICY "Enable read access for all users"
  ON equipment FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Enable quantity updates for admins"
  ON equipment FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND is_admin = true
    )
  );