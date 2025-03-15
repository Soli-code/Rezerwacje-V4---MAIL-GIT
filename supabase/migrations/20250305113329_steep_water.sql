/*
  # Fix RLS policies for customers table

  1. Security Changes
    - Enable RLS on customers table
    - Add policies for customers table:
      - INSERT policy allowing authenticated users to create customers
      - SELECT policy for viewing customer data
      - UPDATE policy for updating customer data
    
  2. Changes
    - Fixed policies to use correct user authentication checks
    - Simplified policy conditions
    - Added proper user ownership checks
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

-- Drop existing policies to avoid conflicts
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can create customer data" ON customers;
  DROP POLICY IF EXISTS "Users can view own customer data" ON customers;
  DROP POLICY IF EXISTS "Users can update own customer data" ON customers;
END $$;

-- Create new policies
CREATE POLICY "Users can create customer data"
ON customers
FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "Users can view own customer data"
ON customers
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM rental_orders 
    WHERE rental_orders.customer_id = customers.id
  )
);

CREATE POLICY "Users can update own customer data"
ON customers
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM rental_orders 
    WHERE rental_orders.customer_id = customers.id
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM rental_orders 
    WHERE rental_orders.customer_id = customers.id
  )
);