/*
  # Add Equipment Specifications Management

  1. New Tables
    - `specifications`
      - `id` (uuid, primary key)
      - `equipment_id` (uuid, foreign key)
      - `key` (text)
      - `value` (text)
      - `sort_order` (integer)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `specifications` table
    - Add policies for admin management and public viewing
    - Add foreign key constraint to equipment table

  3. Changes
    - Add trigger for maintaining sort order
*/

-- Create specifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS specifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id uuid NOT NULL REFERENCES equipment(id) ON DELETE CASCADE,
  key text NOT NULL,
  value text NOT NULL,
  sort_order integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Create index for faster lookups if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_specifications_equipment_id ON specifications(equipment_id);

-- Enable RLS
ALTER TABLE specifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can manage specifications" ON specifications;
DROP POLICY IF EXISTS "Public can view specifications" ON specifications;

-- Create policies
CREATE POLICY "Admins can manage specifications"
  ON specifications
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Public can view specifications"
  ON specifications
  FOR SELECT
  TO public
  USING (true);

-- Create function to maintain sort order if it doesn't exist
CREATE OR REPLACE FUNCTION maintain_specifications_sort_order()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Set the new sort_order to the maximum + 1 for this equipment
    SELECT COALESCE(MAX(sort_order), 0) + 1
    INTO NEW.sort_order
    FROM specifications
    WHERE equipment_id = NEW.equipment_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS specifications_sort_order_trigger ON specifications;

-- Create trigger for sort order maintenance
CREATE TRIGGER specifications_sort_order_trigger
  BEFORE INSERT ON specifications
  FOR EACH ROW
  EXECUTE FUNCTION maintain_specifications_sort_order();