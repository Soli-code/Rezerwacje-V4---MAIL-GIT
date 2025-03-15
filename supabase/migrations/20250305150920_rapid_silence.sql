/*
  # Update customers table and policies

  1. Changes
    - Add anonymous_id column to customers table if not exists
    - Enable RLS on customers table
    - Update policies for public access

  2. Security
    - Enable RLS
    - Add policies for:
      - Public creation of customer records
      - Public viewing of customer data
      - Public updating of customer data
*/

-- Add anonymous_id column to customers if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customers' 
    AND column_name = 'anonymous_id'
  ) THEN
    ALTER TABLE customers ADD COLUMN anonymous_id uuid DEFAULT gen_random_uuid();
  END IF;
END $$;

-- Enable RLS if not already enabled
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'customers' 
    AND rowsecurity = true
  ) THEN
    ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
  END IF;
END $$;

-- Safely manage policies
DO $$ 
BEGIN
  -- Drop existing policies if they exist
  DROP POLICY IF EXISTS "Anyone can create customer data" ON customers;
  DROP POLICY IF EXISTS "Anyone can view customer data" ON customers;
  DROP POLICY IF EXISTS "Anyone can update customer data" ON customers;
  DROP POLICY IF EXISTS "Users can create customer data" ON customers;
  DROP POLICY IF EXISTS "Users can view own customer data" ON customers;
  DROP POLICY IF EXISTS "Users can update own customer data" ON customers;

  -- Create new policies only if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'customers' 
    AND policyname = 'Public create access'
  ) THEN
    CREATE POLICY "Public create access"
    ON customers FOR INSERT
    TO public
    WITH CHECK (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'customers' 
    AND policyname = 'Public view access'
  ) THEN
    CREATE POLICY "Public view access"
    ON customers FOR SELECT
    TO public
    USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'customers' 
    AND policyname = 'Public update access'
  ) THEN
    CREATE POLICY "Public update access"
    ON customers FOR UPDATE
    TO public
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;