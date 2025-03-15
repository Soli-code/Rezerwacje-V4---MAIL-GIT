/*
  # Fix customers table structure and policies

  1. Changes
    - Add user_id column to customers table
    - Add foreign key constraint to users table
    - Update RLS policies to use user_id for ownership checks

  2. Security
    - Enable RLS on customers table
    - Create policies for authenticated users
    - Allow users to manage their own customer records
    - Allow admins to manage all customer records
*/

-- Add user_id column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'customers' 
    AND column_name = 'user_id'
  ) THEN
    ALTER TABLE customers ADD COLUMN user_id uuid REFERENCES auth.users(id);
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

-- Drop existing policies to avoid conflicts
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can create customer data" ON customers;
  DROP POLICY IF EXISTS "Users can view own customer data" ON customers;
  DROP POLICY IF EXISTS "Users can update own customer data" ON customers;
END $$;

-- Create new policies for customers table
CREATE POLICY "Users can create customer data"
ON customers
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view own customer data"
ON customers
FOR SELECT
TO authenticated
USING (
  auth.uid() = user_id
  OR
  EXISTS (
    SELECT 1 
    FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.is_admin = true
  )
);

CREATE POLICY "Users can update own customer data"
ON customers
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id
  OR
  EXISTS (
    SELECT 1 
    FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.is_admin = true
  )
)
WITH CHECK (
  auth.uid() = user_id
  OR
  EXISTS (
    SELECT 1 
    FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.is_admin = true
  )
);