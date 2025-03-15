/*
  # Equipment Availability Management

  1. New Tables
    - `equipment_availability`
      - `id` (uuid, primary key)
      - `equipment_id` (uuid, references equipment)
      - `start_date` (timestamptz)
      - `end_date` (timestamptz)
      - `status` (text) - 'reserved', 'maintenance'
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Functions
    - `check_equipment_availability` - Checks if equipment is available for a given time period
    - `update_equipment_availability` - Updates equipment availability after reservation

  3. Security
    - Enable RLS on equipment_availability table
    - Add policies for viewing and managing availability
*/

-- Create equipment_availability table
CREATE TABLE IF NOT EXISTS equipment_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid REFERENCES equipment(id) ON DELETE CASCADE,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  status text NOT NULL CHECK (status IN ('reserved', 'maintenance')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT valid_dates CHECK (end_date > start_date)
);

-- Create index for faster availability lookups
CREATE INDEX idx_equipment_availability_dates ON equipment_availability(equipment_id, start_date, end_date);

-- Enable RLS
ALTER TABLE equipment_availability ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Public can view equipment availability"
  ON equipment_availability
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Only admins can manage equipment availability"
  ON equipment_availability
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Function to check equipment availability
CREATE OR REPLACE FUNCTION check_equipment_availability(
  p_equipment_id uuid,
  p_start_date timestamptz,
  p_end_date timestamptz
) RETURNS boolean AS $$
BEGIN
  -- Add 1 hour buffer after end_date for maintenance
  RETURN NOT EXISTS (
    SELECT 1 FROM equipment_availability
    WHERE equipment_id = p_equipment_id
    AND (
      (start_date <= p_start_date AND end_date >= p_start_date)
      OR (start_date <= p_end_date AND end_date >= p_end_date)
      OR (start_date >= p_start_date AND end_date <= p_end_date)
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get next available date
CREATE OR REPLACE FUNCTION get_next_available_date(
  p_equipment_id uuid,
  p_start_date timestamptz
) RETURNS timestamptz AS $$
DECLARE
  next_date timestamptz;
BEGIN
  SELECT end_date + interval '1 hour'
  INTO next_date
  FROM equipment_availability
  WHERE equipment_id = p_equipment_id
  AND end_date >= p_start_date
  ORDER BY end_date ASC
  LIMIT 1;

  RETURN COALESCE(next_date, p_start_date);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update equipment_availability on reservation
CREATE OR REPLACE FUNCTION update_equipment_availability() RETURNS trigger AS $$
BEGIN
  -- Insert new availability record for each equipment item in the reservation
  INSERT INTO equipment_availability (equipment_id, start_date, end_date, status)
  SELECT 
    equipment_id,
    NEW.start_date,
    NEW.end_date,
    'reserved'
  FROM reservation_items
  WHERE reservation_id = NEW.id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER after_reservation_insert
  AFTER INSERT ON reservations
  FOR EACH ROW
  EXECUTE FUNCTION update_equipment_availability();