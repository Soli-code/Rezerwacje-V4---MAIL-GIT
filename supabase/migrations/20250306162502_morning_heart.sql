/*
  # Update RLS policies
  
  1. Security Updates
    - Enable RLS for equipment_availability if not already enabled
    - Add or update policies for equipment_availability, customers, and reservations
    - Safely handle existing policies
*/

-- Enable RLS for equipment_availability if not already enabled
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'equipment_availability' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE equipment_availability ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Drop existing policies if they exist and create new ones
DO $$ 
BEGIN
  -- Equipment availability policies
  DROP POLICY IF EXISTS "Public can view equipment availability" ON equipment_availability;
  
  -- Customers policies
  DROP POLICY IF EXISTS "Public can create and view customers" ON customers;
  
  -- Reservations policies
  DROP POLICY IF EXISTS "Public can create and view reservations" ON reservations;
END $$;

-- Create new policies
CREATE POLICY "Public can view equipment availability"
  ON equipment_availability
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Public can create and view customers"
  ON customers
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public can create and view reservations"
  ON reservations
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);