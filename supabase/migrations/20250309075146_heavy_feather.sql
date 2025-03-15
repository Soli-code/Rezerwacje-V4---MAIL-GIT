/*
  # Update customer policies

  1. Changes
    - Enable RLS on customers table
    - Update policies for public access
    
  2. Security
    - Drop old policies
    - Create new policies with existence checks
    - Allow public access for basic CRUD operations
*/

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

-- Drop and recreate policies using IF NOT EXISTS
DO $$ 
BEGIN
  -- Drop existing policies
  DROP POLICY IF EXISTS "Anyone can create customer data" ON customers;
  DROP POLICY IF EXISTS "Anyone can view customer data" ON customers;
  DROP POLICY IF EXISTS "Anyone can update customer data" ON customers;
  DROP POLICY IF EXISTS "Public create access" ON customers;
  DROP POLICY IF EXISTS "Public view access" ON customers;
  DROP POLICY IF EXISTS "Public update access" ON customers;
  DROP POLICY IF EXISTS "Customer create policy" ON customers;
  DROP POLICY IF EXISTS "Customer view policy" ON customers;
  DROP POLICY IF EXISTS "Customer update policy" ON customers;
  DROP POLICY IF EXISTS "Public can create customers" ON customers;
  DROP POLICY IF EXISTS "Public can view customers" ON customers;
  DROP POLICY IF EXISTS "Public can update customers" ON customers;

  -- Create new policies with existence checks
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'customers' 
    AND policyname = 'Public can create and view customers'
  ) THEN
    CREATE POLICY "Public can create and view customers"
    ON customers
    FOR ALL
    TO public
    USING (true)
    WITH CHECK (true);
  END IF;
END $$;