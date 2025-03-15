/*
  # Update equipment table and policies

  1. Changes
    - Drop existing policies if they exist
    - Create equipment table if it doesn't exist
    - Add new policies for equipment table

  2. Security
    - Enable RLS
    - Add policies for:
      - Public can view equipment
      - Only admins can insert/update/delete equipment
*/

-- Drop existing policies if they exist
DO $$ 
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'equipment'
  ) THEN
    DROP POLICY IF EXISTS "Public can view equipment" ON equipment;
    DROP POLICY IF EXISTS "Only admins can insert equipment" ON equipment;
    DROP POLICY IF EXISTS "Only admins can update equipment" ON equipment;
    DROP POLICY IF EXISTS "Only admins can delete equipment" ON equipment;
  END IF;
END $$;

-- Create equipment table if it doesn't exist
CREATE TABLE IF NOT EXISTS equipment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric NOT NULL,
  deposit numeric DEFAULT 0,
  image text,
  categories text[] NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE equipment ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Public can view equipment"
  ON equipment
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Only admins can insert equipment"
  ON equipment
  FOR INSERT
  TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

CREATE POLICY "Only admins can update equipment"
  ON equipment
  FOR UPDATE
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

CREATE POLICY "Only admins can delete equipment"
  ON equipment
  FOR DELETE
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  ));

-- Create updated_at trigger
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_equipment_updated_at'
  ) THEN
    CREATE TRIGGER update_equipment_updated_at
      BEFORE UPDATE ON equipment
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;